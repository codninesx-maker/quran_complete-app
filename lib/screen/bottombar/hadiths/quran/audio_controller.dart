import 'dart:async';
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AudioController extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(minutes: 1),
    ),
  );

  final StreamController<int> _suraChangeStreamController = StreamController<int>.broadcast();
  Stream<int> get onSuraChanged => _suraChangeStreamController.stream;

  int _currentAyaIndex = -1;
  int get currentAyaIndex => _currentAyaIndex;
  int _currentSuraId = -1;
  int get currentSuraId => _currentSuraId;
  bool get isPlaying => _audioPlayer.playing;
  bool _isBuffering = false;
  bool get isBuffering => _isBuffering;
  bool _isSettingSource = false;
  bool _isSwappingSource = false;

  List<dynamic> _playlist = [];
  String? _loadingUrl;
  String? _currentManualUrl;
  String? get currentManualUrl => _currentManualUrl;
  String? get loadingUrl => _loadingUrl;
  final Set<String> _downloadQueue = {};

  ConcatenatingAudioSource? _concatenatingSource;
  Duration get currentPosition => _audioPlayer.position;
  Duration? get totalDuration => _audioPlayer.duration;

  Map<String, dynamic> _selectedReciter = {
    'folder_name': 'Alafasy_192kbps', // Bumps sample rates from 22050Hz to 44100Hz
  };

  AudioController() {
    _initListeners();
    _initAudioSession();
  }

  int? get currentPlayingSuraId {
    if (_concatenatingSource == null) return null;

    final index = _audioPlayer.currentIndex;
    if (index != null && index < _concatenatingSource!.length) {
      final activeSource = _concatenatingSource!.children[index];

      if (activeSource is IndexedAudioSource && activeSource.tag is MediaItem) {
        final MediaItem mediaItem = activeSource.tag as MediaItem;
        if (mediaItem.extras != null) {
          return mediaItem.extras!['sura_id'] as int?;
        }
      }
    }
    return null;
  }

  int findIndexByAyaId(int targetAyaId) {
    for (int i = 0; i < _playlist.length; i++) {
      final item = _playlist[i];
      if (item != null) {
        try {
          final keys = _getCleanKeys(item);
          if (keys['aya'] == targetAyaId) {
            return i;
          }
        } catch (_) {
          continue;
        }
      }
    }
    return -1;
  }

  Map<String, int> _getCleanKeys(dynamic ayaData) {
    if (ayaData is! Map) {
      throw ArgumentError("Expected a Map data structure for Aya entry parsing.");
    }
    final rawSura = ayaData['sura_id'] ?? ayaData['sura_id'];
    final rawAya = ayaData['aya_id'] ?? ayaData['verse_id'];

    if (rawSura == null || rawAya == null) {
      throw StateError("Malformed database map key parameters: $ayaData");
    }

    return {
      'sura': int.parse(rawSura.toString()),
      'aya': int.parse(rawAya.toString()),
    };
  }

  void _initListeners() {
    // 🌟 1. Listen to play/pause state changes instantly
    _audioPlayer.playingStream.listen((isPlaying) {
      notifyListeners();
    });

    _audioPlayer.playbackEventStream.listen((event) {
      // General event handling stream
    }, onError: (Object e, StackTrace stackTrace) {
      debugPrint("❌ Audio playback stream error: $e");

      if (e.toString().contains('404') || e.toString().contains('InvalidResponseCodeException')) {
        debugPrint("⚠️ Skipping missing or broken audio file (404)...");
        if (_audioPlayer.hasNext) {
          _audioPlayer.seekToNext();
          _audioPlayer.play();
        }
      }
    });

    _audioPlayer.currentIndexStream.listen((index) {
      if (_isSwappingSource) return;

      if (index != null && _concatenatingSource != null && index < _concatenatingSource!.length) {
        final activeSource = _concatenatingSource!.children[index];

        if (activeSource is IndexedAudioSource && activeSource.tag is MediaItem) {
          final MediaItem mediaItem = activeSource.tag as MediaItem;

          if (mediaItem.extras != null) {
            int actualAyaNumber = mediaItem.extras!['aya_id'] ?? -1;
            int actualSuraNumber = mediaItem.extras!['sura_id'] ?? -1;

            if (actualSuraNumber != _currentSuraId && actualSuraNumber != -1) {
              _suraChangeStreamController.add(actualSuraNumber);
            }

            debugPrint("🎯 Sync Verified -> Native Index: $index | Playing Surah: $actualSuraNumber, Aya: $actualAyaNumber");

            _currentAyaIndex = actualAyaNumber;
            _currentSuraId = actualSuraNumber;
            notifyListeners();

            // Only pre-fetch if it's ayah-by-ayah mode (not full surah mode)
            if (mediaItem.extras!['is_full_surah'] != true) {
              _preFetchNext(index + 1);
            }
          }
        }
      }
      else if (index != null && _audioPlayer.audioSource != null && _concatenatingSource == null) {
        _currentAyaIndex = 0;
        notifyListeners();
      }
    });

    _audioPlayer.playerStateStream.listen((state) {
      _isBuffering = state.processingState == ProcessingState.buffering ||
          state.processingState == ProcessingState.loading;
      notifyListeners();
    });

    _audioPlayer.positionStream.listen((position) {
      if (_currentManualUrl != null) {
        notifyListeners();
      }
    });
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
    notifyListeners();
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionMode: AVAudioSessionMode.spokenAudio,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
    ));
    await session.setActive(true);
  }

  void updateReciter(Map<String, dynamic> reciter) {
    _selectedReciter = reciter;
    notifyListeners();
  }

  Future<void> playAyaAudio(int index, List<dynamic> allAyas) async {
    if (allAyas.isEmpty || index < 0 || index >= allAyas.length) {
      throw ArgumentError("Invalid playlist structure index limits.");
    }

    try {
      _isSettingSource = true;
      _playlist = allAyas;
      _isBuffering = true;
      notifyListeners();

      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.stop();

      final directory = await getApplicationDocumentsDirectory();
      final String folderName = _selectedReciter['folder_name'] ?? 'Alafasy_128kbps';
      final List<AudioSource> dynamicSources = [];

      const List<String> surahNames = [
        "Al-Fatiha", "Al-Baqarah", "Al-Imran", "An-Nisa", "Al-Ma'idah", "Al-An'am",
        "Al-A'raf", "Al-Anfal", "At-Tawbah", "Yunus", "Hud", "Yusuf", "Ar-Ra'd",
        "Ibrahim", "Al-Hijr", "An-Nahl", "Al-Isra", "Al-Kahf", "Maryam", "Ta-Ha",
        "Al-Anbiya", "Al-Hajj", "Al-Mu'minun", "An-Nur", "Al-Furqan", "Ash-Shu'ara",
        "An-Naml", "Al-Qasas", "Al-Ankabut", "Ar-Rum", "Luqman", "As-Sajdah",
        "Al-Ahzab", "Saba", "Fatir", "Ya-Sin", "As-Saffat", "Sad", "Az-Zumar",
        "Ghafir", "Fussilat", "Ash-Shura", "Az-Zukhruf", "Ad-Dukhan", "Al-Jathiyah",
        "Al-Ahqaf", "Muhammad", "Al-Fath", "Al-Hujurat", "Qaf", "Adh-Dhariyat",
        "At-Tur", "An-Najm", "Al-Qamar", "Ar-Rahman", "Al-Waqi'ah", "Al-Hadid",
        "Al-Mujadilah", "Al-Hashr", "Al-Mumtahanah", "As-Saff", "Al-Jumu'ah",
        "Al-Munafiqun", "At-Taghabun", "At-Talaq", "At-Tahrim", "Al-Mulk", "Al-Qalam",
        "Al-Haqqah", "Al-Ma'arij", "Nuh", "Al-Jinn", "Al-Muzzammil", "Al-Muddaththir",
        "Al-Qiyamah", "Al-Insan", "Al-Mursalat", "An-Naba", "An-Nazi'at", "Abasa",
        "At-Takwir", "Al-Infitar", "Al-Mutaffifin", "Al-Inshiqaq", "Al-Buruj",
        "At-Tariq", "Al-A'la", "Al-Ghashiyah", "Al-Fajr", "Al-Balad", "Ash-Shams",
        "Al-Layl", "Ad-Duha", "Ash-Sharh", "At-Tin", "Al-Alaq", "Al-Qadr",
        "Al-Bayyinah", "Az-Zalzalah", "Al-Adiyat", "Al-Qari'ah", "At-Takathur",
        "Al-Asr", "Al-Humazah", "Al-Fil", "Quraysh", "Al-Ma'un", "Al-Kawthar",
        "Al-Kafirun", "An-Nasr", "Al-Masad", "Al-Ikhlas", "Al-Falaq", "An-Nas"
      ];

      for (int i = 0; i < allAyas.length; i++) {
        final aya = allAyas[i];
        if (aya == null) continue;

        final keys = _getCleanKeys(aya);
        final int sNum = keys['sura']!;
        final int aNum = keys['aya']!;

        final String surahName = (sNum > 0 && sNum <= surahNames.length)
            ? surahNames[sNum - 1]
            : "Surah $sNum";

        final String paddedS = sNum.toString().padLeft(3, '0');
        final String paddedA = aNum.toString().padLeft(3, '0');
        final String fileName = '$paddedS$paddedA.mp3';

        final mediaTag = MediaItem(
          id: fileName,
          album: surahName,
          title: "Ayah $aNum",
          extras: {
            'sura_id': sNum,
            'aya_id': aNum,
            'global_index': i,
          },
        );

        final String localPath = p.join(directory.path, 'audio', folderName, fileName);
        final File localAudioFile = File(localPath);

        if (localAudioFile.existsSync()) {
          dynamicSources.add(AudioSource.file(localPath, tag: mediaTag));
        } else {
          final String remoteUrl = "https://everyayah.com/data/$folderName/$fileName";
          dynamicSources.add(AudioSource.uri(Uri.parse(remoteUrl), tag: mediaTag));
        }
      }

      _concatenatingSource = ConcatenatingAudioSource(
        useLazyPreparation: true,
        children: dynamicSources,
      );

      await _audioPlayer.setAudioSource(
        _concatenatingSource!,
        initialIndex: index,
        preload: false,
      );

      _isBuffering = false;
      notifyListeners();

      await _audioPlayer.play();

    } catch (e) {
      debugPrint("❌ 🎵 Playback Pipeline Error: $e");
      _currentAyaIndex = -1;
      _isBuffering = false;
      _isSettingSource = false;
      notifyListeners();
      rethrow;
    } finally {
      _isSettingSource = false;
      notifyListeners();
    }
  }

  /// 🌟 FIXED: Ensures Full Surahs play consecutively one after another from the beginning!
  Future<void> playSurahAudio(int initialIndex, List<dynamic> surahList) async {
    if (surahList.isEmpty || initialIndex < 0 || initialIndex >= surahList.length) {
      throw ArgumentError("Invalid surah playlist index limits.");
    }

    try {
      _isSettingSource = true;
      _playlist = surahList;
      _isBuffering = true;
      _currentManualUrl = null;
      notifyListeners();

      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.stop();

      final List<AudioSource> dynamicSources = [];
      final String folderName = _selectedReciter['folder_name'] ?? 'Alafasy_192kbps';

      for (int i = 0; i < surahList.length; i++) {
        final surahData = surahList[i];
        if (surahData == null) continue;

        final int suraId = int.tryParse(surahData['id'].toString()) ?? (i + 1);
        final String suraName = surahData['name_en'] ?? "Surah $suraId";

        // Standard 3-digit padded Surah filename format (e.g., 001.mp3) inside reciter's folder
        final String paddedSuraId = suraId.toString().padLeft(3, '0');
        final String remoteUrl = "https://everyayah.com/data/$folderName/surahs/$paddedSuraId.mp3";

        final mediaTag = MediaItem(
          id: paddedSuraId,
          album: "Holy Quran",
          title: suraName,
          extras: {
            'sura_id': suraId,
            'aya_id': 0, // 0 signifies full surah file start
            'is_full_surah': true,
            'global_index': i,
          },
        );

        dynamicSources.add(AudioSource.uri(
          Uri.parse(surahData['url'] ?? remoteUrl),
          tag: mediaTag,
        ));
      }

      _concatenatingSource = ConcatenatingAudioSource(
        useLazyPreparation: true,
        children: dynamicSources,
      );

      await _audioPlayer.setAudioSource(
        _concatenatingSource!,
        initialIndex: initialIndex,
        preload: false,
      );

      _isBuffering = false;
      notifyListeners();

      await _audioPlayer.play();

    } catch (e) {
      debugPrint("❌ 🎵 Surah Pipeline Error: $e");
      _isBuffering = false;
      _isSettingSource = false;
      notifyListeners();
      rethrow;
    } finally {
      _isSettingSource = false;
      notifyListeners();
    }
  }

  Future<void> playContinuousFromSurahFast(
      int targetSuraId,
      int targetAyaId,
      List<dynamic> currentSurahAyas,
      List<dynamic> allSurasMasterList,
      ) async {
    try {
      _isSettingSource = true;
      _isBuffering = true;
      notifyListeners();

      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.stop();

      final List<AudioSource> masterDynamicSources = [];
      final List<dynamic> masterFlatPlaylist = [];
      int targetInitialIndex = 0;
      bool foundTarget = false;

      final directory = await getApplicationDocumentsDirectory();
      final String folderName = _selectedReciter['folder_name'] ?? 'Alafasy_128kbps';

      for (int aIndex = 0; aIndex < currentSurahAyas.length; aIndex++) {
        final aya = currentSurahAyas[aIndex];
        if (aya == null) continue;

        final rawAyaId = aya['aya_id'] ?? aya['verse_id'] ?? aya['id'];
        final int aNum = int.tryParse(rawAyaId.toString()) ?? (aIndex + 1);

        if (!foundTarget && aNum == targetAyaId) {
          targetInitialIndex = masterFlatPlaylist.length;
          foundTarget = true;
        }

        masterFlatPlaylist.add(aya);

        final String paddedS = targetSuraId.toString().padLeft(3, '0');
        final String paddedA = aNum.toString().padLeft(3, '0');
        final String fileName = '$paddedS$paddedA.mp3';

        final mediaTag = MediaItem(
          id: fileName,
          album: "Surah $targetSuraId",
          title: "Ayah $aNum",
          extras: {'sura_id': targetSuraId, 'aya_id': aNum},
        );

        final String localPath = p.join(directory.path, 'audio', folderName, fileName);
        if (File(localPath).existsSync()) {
          masterDynamicSources.add(AudioSource.file(localPath, tag: mediaTag));
        } else {
          final String remoteUrl = "https://everyayah.com/data/$folderName/$fileName";
          masterDynamicSources.add(AudioSource.uri(Uri.parse(remoteUrl), tag: mediaTag));
        }
      }

      _playlist = masterFlatPlaylist;
      _concatenatingSource = ConcatenatingAudioSource(
        useLazyPreparation: true,
        children: masterDynamicSources,
      );

      await _audioPlayer.setAudioSource(
        _concatenatingSource!,
        initialIndex: targetInitialIndex,
        preload: false,
      );

      _isBuffering = false;
      notifyListeners();
      await _audioPlayer.play();

      _appendRemainingSurahsInBackground(targetSuraId, allSurasMasterList);

    } catch (e) {
      debugPrint("❌ Instant Continuous Playback Error: $e");
      _isBuffering = false;
      _isSettingSource = false;
      notifyListeners();
    } finally {
      _isSettingSource = false;
      notifyListeners();
    }
  }

  Future<void> _appendRemainingSurahsInBackground(int currentSuraId, List<dynamic> allSurasMasterList) async {
    try {
      // 1. Ensure the master list is strictly sorted by Surah ID ascending (1 to 114)
      final sortedMasterList = List<dynamic>.from(allSurasMasterList)..sort((a, b) {
        int idA = int.tryParse(a['id']?.toString() ?? a['chapter_number']?.toString() ?? a['index']?.toString() ?? '0') ?? 0;
        int idB = int.tryParse(b['id']?.toString() ?? b['chapter_number']?.toString() ?? b['index']?.toString() ?? '0') ?? 0;
        return idA.compareTo(idB);
      });

      // 2. Find the exact start index using the sorted list
      int suraStartIndex = sortedMasterList.indexWhere((s) {
        int id = int.tryParse(s['id']?.toString() ?? s['chapter_number']?.toString() ?? s['index']?.toString() ?? '0') ?? 0;
        return id == currentSuraId;
      });

      if (suraStartIndex == -1 || suraStartIndex >= sortedMasterList.length - 1) {
        debugPrint("⚠️ Current Surah ID $currentSuraId not found or is the last surah.");
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      final String folderName = _selectedReciter['folder_name'] ?? 'Alafasy_128kbps';

      // 3. Loop sequentially through all subsequent surahs
      for (int sIndex = suraStartIndex + 1; sIndex < sortedMasterList.length; sIndex++) {
        final suraItem = sortedMasterList[sIndex];
        if (suraItem == null) continue;

        final int? sNum = int.tryParse(suraItem['id']?.toString() ?? '') ??
            int.tryParse(suraItem['chapter_number']?.toString() ?? '') ??
            int.tryParse(suraItem['index']?.toString() ?? '');

        if (sNum == null) continue;

        List<dynamic> suraAyas = [];
        try {
          final response = await _dio.get("https://api.quran.com/api/v4/verses/by_chapter/$sNum?language=bn&words=false");
          if (response.statusCode == 200 && response.data != null) {
            suraAyas = response.data['verses'] ?? [];
          }
        } catch (e) {
          debugPrint("⚠️ Failed to fetch verses for background Surah $sNum: $e");
          continue;
        }

        if (suraAyas.isEmpty || _concatenatingSource == null) continue;

        List<AudioSource> newSources = [];
        List<dynamic> tempPlaylistBatch = [];

        for (int aIndex = 0; aIndex < suraAyas.length; aIndex++) {
          final aya = suraAyas[aIndex];
          if (aya == null) continue;

          // 🌟 CORRECTED: Parse verse number properly from Quran.com API structure (verse_number or verse_key like "2:1")
          int aNum = aIndex + 1;
          if (aya['verse_number'] != null) {
            aNum = int.tryParse(aya['verse_number'].toString()) ?? (aIndex + 1);
          } else if (aya['verse_key'] != null) {
            final parts = aya['verse_key'].toString().split(':');
            if (parts.length > 1) {
              aNum = int.tryParse(parts[1]) ?? (aIndex + 1);
            }
          }

          // Inject computed keys back into the map so local playlist state matches sync listeners
          final enrichedAya = Map<String, dynamic>.from(aya);
          enrichedAya['sura_id'] = sNum;
          enrichedAya['aya_id'] = aNum;

          tempPlaylistBatch.add(enrichedAya);

          final String paddedS = sNum.toString().padLeft(3, '0');
          final String paddedA = aNum.toString().padLeft(3, '0');
          final String fileName = '$paddedS$paddedA.mp3';

          final mediaTag = MediaItem(
            id: fileName,
            album: "Surah $sNum",
            title: "Ayah $aNum",
            extras: {
              'sura_id': sNum,
              'aya_id': aNum,
              'is_full_surah': false,
            },
          );

          final String localPath = p.join(directory.path, 'audio', folderName, fileName);
          if (File(localPath).existsSync()) {
            newSources.add(AudioSource.file(localPath, tag: mediaTag));
          } else {
            final String remoteUrl = "https://everyayah.com/data/$folderName/$fileName";
            newSources.add(AudioSource.uri(Uri.parse(remoteUrl), tag: mediaTag));
          }
        }

        // 4. Atomic Push: Update UI playlist and Audio Player source together
        _playlist.addAll(tempPlaylistBatch);
        await _concatenatingSource!.addAll(newSources);

        debugPrint("➕ Successfully chained Surah $sNum with ${newSources.length} ayahs starting from Ayah 1.");
      }
    } catch (e) {
      debugPrint("⚠️ Background surah chaining exception: $e");
    }
  }

  Future<void> cacheAndPrepareTrack(int targetIndex, List<dynamic> ayahDataList) async {
    if (targetIndex < 0 || targetIndex >= ayahDataList.length) return;

    final keys = _getCleanKeys(ayahDataList[targetIndex]);
    final String suraString = keys['sura']!.toString().padLeft(3, '0');
    final String ayaString = keys['aya']!.toString().padLeft(3, '0');

    final String correctFileName = "$suraString$ayaString.mp3";
    debugPrint("🔄 Processing index $targetIndex mapped securely to physical file: $correctFileName");
  }

  List<MediaItem> buildStrictAudioQueue(List<dynamic> activeAyahList) {
    return activeAyahList.map((verseData) {
      final keys = _getCleanKeys(verseData);
      final String sKey = keys['sura']!.toString().padLeft(3, '0');
      final String aKey = keys['aya']!.toString().padLeft(3, '0');

      return MediaItem(
        id: "$sKey$aKey.mp3",
        album: "Sura ${keys['sura']}",
        title: "Aya ${keys['aya']}",
        extras: {
          'uiIndex': activeAyahList.indexOf(verseData),
        },
      );
    }).toList();
  }

  Future<void> downloadAndAssignAudioTrack({
    required int itemIndex,
    required List<dynamic> fetchedAyahPayload,
  }) async {
    if (itemIndex < 0 || itemIndex >= fetchedAyahPayload.length) return;

    final keys = _getCleanKeys(fetchedAyahPayload[itemIndex]);
    final String paddedSura = keys['sura']!.toString().padLeft(3, '0');
    final String paddedAya = keys['aya']!.toString().padLeft(3, '0');

    final String strictFileName = "$paddedSura$paddedAya.mp3";
    debugPrint("🎯 Swapping Asset Engine: Index $itemIndex securely locked to true file -> $strictFileName");
  }

  Future<void> _preFetchNext(int targetIndex) async {
    if (targetIndex < 0 || targetIndex >= _playlist.length) return;
    if (_isSwappingSource) return; // Prevent concurrent swapping conflicts

    try {
      final networkCheck = await InternetAddress.lookup('google.com');
      if (networkCheck.isEmpty || networkCheck[0].rawAddress.isEmpty) return;
    } catch (_) {
      return;
    }

    final targetAya = _playlist[targetIndex];
    final keys = _getCleanKeys(targetAya);
    final int sNum = keys['sura']!;
    final int aNum = keys['aya']!;

    String url = _getRemoteUrl(sNum, aNum);
    String localPath = await _getLocalPath(sNum, aNum);

    if (File(localPath).existsSync()) return;

    if (!_downloadQueue.contains(url)) {
      _downloadQueue.add(url);

      _ensureFileExists(url, localPath).then((downloadedSuccess) async {
        _downloadQueue.remove(url);

        // Verify concatenating source and player state before mutating
        if (downloadedSuccess && _concatenatingSource != null && !_isSettingSource) {
          if (targetIndex < _concatenatingSource!.length) {
            // Skip live-swapping if this is the currently active track to prevent stutter/loops
            if (_audioPlayer.currentIndex == targetIndex) return;

            try {
              _isSwappingSource = true;
              notifyListeners();

              final oldSource = _concatenatingSource!.children[targetIndex];
              dynamic dynamicTagReference;

              if (oldSource is IndexedAudioSource) {
                dynamicTagReference = oldSource.tag;
              }

              final newFileSource = AudioSource.file(localPath, tag: dynamicTagReference);

              // Safely insert then remove to avoid index out-of-bounds shifts
              await _concatenatingSource!.insert(targetIndex, newFileSource);
              if (targetIndex + 1 < _concatenatingSource!.length) {
                await _concatenatingSource!.removeAt(targetIndex + 1);
              }

              debugPrint("🔄 Live-Swapped index $targetIndex to local file safely.");
            } catch (e) {
              debugPrint("❌ Failed background live-swap transaction: $e");
            } finally {
              _isSwappingSource = false;
              notifyListeners();
            }
          }
        }
      }).catchError((error) {
        _downloadQueue.remove(url);
        _isSwappingSource = false;
        notifyListeners();
      });
    }
  }

  Future<bool> _ensureFileExists(String url, String localPath) async {
    final file = File(localPath);
    if (await file.exists()) {
      final size = await file.length();
      if (size > 1024) return true;
      await file.delete();
    }
    return await _downloadFile(url, localPath);
  }

  String _getRemoteUrl(int suraId, int ayahId) {
    String s = suraId.toString().padLeft(3, '0');
    String a = ayahId.toString().padLeft(3, '0');
    String folder = _selectedReciter['folder_name'] ?? 'Alafasy_128kbps';
    return "https://everyayah.com/data/$folder/$s$a.mp3";
  }

  Future<String> _getLocalPath(int suraId, int ayahId) async {
    final directory = await getApplicationDocumentsDirectory();
    String folderName = _selectedReciter['folder_name'] ?? "Alafasy_128kbps";
    final dirPath = p.join(directory.path, 'audio', folderName);

    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    String s = suraId.toString().padLeft(3, '0');
    String a = ayahId.toString().padLeft(3, '0');
    return p.join(dirPath, '$s$a.mp3');
  }

  Future<bool> _downloadFile(String url, String savePath) async {
    String tempPath = "$savePath.temp";
    try {
      final dir = Directory(p.dirname(savePath));
      if (!await dir.exists()) await dir.create(recursive: true);

      await _dio.download(url, tempPath);

      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        final size = await tempFile.length();
        if (size > 1024) {
          final targetFile = File(savePath);
          if (await targetFile.exists()) await targetFile.delete();
          await tempFile.rename(savePath);
          debugPrint("✅ Downloaded: ${p.basename(savePath)}");
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint("❌ Download failed: $e");
      final tempFile = File(tempPath);
      if (await tempFile.exists()) await tempFile.delete();
      return false;
    }
  }

  Future<void> playDirectUrl(String url) async {
    if (url.isEmpty) return;

    try {
      String secureUrl = url.trim().replaceFirst("http://", "https://");

      _isSettingSource = true;
      _isBuffering = true;
      _currentManualUrl = secureUrl;
      _loadingUrl = secureUrl;
      notifyListeners();

      await _audioPlayer.stop();
      _concatenatingSource = null;

      int suspectedSuraId = 1;
      String printableTitle = "Special Recitation";

      try {
        final String decodedPath = Uri.decodeComponent(secureUrl);
        final String fileNameOnly = p.basename(decodedPath);
        final String numbersPrefix = fileNameOnly.split(' ')[0];
        int? parsedId = int.tryParse(numbersPrefix);
        if (parsedId != null && parsedId > 0 && parsedId <= 114) {
          suspectedSuraId = parsedId;
          printableTitle = fileNameOnly.replaceAll('.ogg', '').replaceAll('.mp3', '');
        }
      } catch (_) {}

      final manualMediaTag = MediaItem(
        id: secureUrl,
        album: "Surah Full Audio",
        title: printableTitle,
        extras: {
          'sura_id': suspectedSuraId,
          'aya_id': 0,
          'is_manual': true,
        },
      );

      await _audioPlayer.setAudioSource(
        AudioSource.uri(
          Uri.parse(secureUrl),
          headers: {
            'User-Agent': 'Mozilla/5.0',
            'Accept': '*/*',
          },
          tag: manualMediaTag,
        ),
        preload: true,
      ).timeout(const Duration(seconds: 20));

      _loadingUrl = null;
      notifyListeners();

      await _audioPlayer.play();

    } on TimeoutException catch (e) {
      debugPrint("❌ Network request timed out: $e");
      _currentManualUrl = null;
      _loadingUrl = null;
      resetLoadingStates();
    } on PlayerException catch (e) {
      debugPrint("❌ just_audio Engine Native Error: ${e.message}");
      _currentManualUrl = null;
      _loadingUrl = null;
      resetLoadingStates();
    } on PlayerInterruptedException catch (e) {
      debugPrint("❌ just_audio Interaction Interrupted: ${e.message}");
      _currentManualUrl = null;
      _loadingUrl = null;
      resetLoadingStates();
    } catch (e) {
      debugPrint("🛡️ Prevented just_audio local proxy runtime crash safely: $e");
      _currentManualUrl = null;
      _loadingUrl = null;
      resetLoadingStates();
    } finally {
      _isSettingSource = false;
      _loadingUrl = null;
      notifyListeners();
    }
  }

  void resetLoadingStates() {
    _isSettingSource = false;
    _isSwappingSource = false;
    _isBuffering = false;
    notifyListeners();
    debugPrint("🧹 Manual Emergency State Clear Executed.");
  }

  void pause() {
    _audioPlayer.pause();
    notifyListeners();
  }

  void togglePlay() {
    if (_audioPlayer.playing) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.play();
    }
    notifyListeners(); // Force immediate update
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _suraChangeStreamController.close();
    super.dispose();
  }
}