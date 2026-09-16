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
    _audioPlayer.currentIndexStream.listen((index) {
      if (_isSwappingSource) return;

      // Ensure we are in playlist mode before handling automatic pre-fetching steps
      if (index != null && _concatenatingSource != null && index < _concatenatingSource!.length) {
        final activeSource = _concatenatingSource!.children[index];

        if (activeSource is IndexedAudioSource && activeSource.tag is MediaItem) {
          final MediaItem mediaItem = activeSource.tag as MediaItem;

          if (mediaItem.extras != null) {
            int actualAyaNumber = mediaItem.extras!['aya_id'] ?? -1;
            int actualSuraNumber = mediaItem.extras!['sura_id'] ?? -1;

            debugPrint("🎯 Sync Verified -> Native Index: $index | Playing Aya: $actualAyaNumber");

            _currentAyaIndex = actualAyaNumber;
            _currentSuraId = actualSuraNumber;
            notifyListeners();

            _preFetchNext(index + 1);
          }
        }
      }
      // 🌟 FIXED: Keep manual single-track playback properties safely synchronized in UI state
      else if (index != null && _audioPlayer.audioSource != null && _concatenatingSource == null) {
        _currentAyaIndex = 0; // Explicitly set to 0 for full Surah play mode
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
    notifyListeners(); // Notify UI to redraw progress changes if needed
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

  // 1. Add 'String surahName' as an explicit structural argument here 💎
  // Ensure your method signature looks EXACTLY like this (2 arguments):
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

      // Core 114 Surah Names localized lookup mapping list
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

        // Safely access Surah translation index
        final String surahName = (sNum > 0 && sNum <= surahNames.length)
            ? surahNames[sNum - 1]
            : "Surah $sNum";

        final String paddedS = sNum.toString().padLeft(3, '0');
        final String paddedA = aNum.toString().padLeft(3, '0');
        final String fileName = '$paddedS$paddedA.mp3';

        final mediaTag = MediaItem(
          id: fileName,
          album: surahName,    // 🎯 Displays Surah name dynamically in the system notification drawer
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

    try {
      final networkCheck = await InternetAddress.lookup('google.com');
      if (networkCheck.isEmpty || networkCheck[0].rawAddress.isEmpty) return;
    } catch (_) {
      debugPrint("📡 Offline Mode Active: Skipping pre-fetch down-streams.");
      _isSwappingSource = false;
      notifyListeners();
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

        if (downloadedSuccess && _concatenatingSource != null) {
          if (targetIndex < _concatenatingSource!.length) {
            try {
              _isSwappingSource = true;
              notifyListeners();

              final oldSource = _concatenatingSource!.children[targetIndex];
              dynamic dynamicTagReference;

              if (oldSource is IndexedAudioSource) {
                dynamicTagReference = oldSource.tag;
              }

              final newFileSource = AudioSource.file(localPath, tag: dynamicTagReference);

              await _concatenatingSource!.insert(targetIndex, newFileSource);
              await _concatenatingSource!.removeAt(targetIndex + 1);

              debugPrint("🔄 Live-Swapped index $targetIndex to local file.");
            } catch (e) {
              debugPrint("❌ Failed background live-swap transaction: $e");
            } finally {
              _isSwappingSource = false;
              notifyListeners();
            }
          }
        }
      }).catchError((error) {
        debugPrint("❌ Prefetch Worker async task caught unhandled failure: $error");
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

      // 1. Instantly trigger loading indicators to prevent double taps
      _isSettingSource = true;
      _isBuffering = true;
      _currentManualUrl = secureUrl;
      _loadingUrl = secureUrl;
      notifyListeners();

      // 2. Shut down existing playlists to isolate proxy tasks cleanly
      await _audioPlayer.stop();
      _concatenatingSource = null;

      // 📜 Step A: Extract Surah ID from URL if calling ArchiveAudioHelper format
      // Looks for filenames matching patterns like "001 - Al-Fatihah..."
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
      } catch (_) {
        // Fallback gracefully if url parsing fails on non-standard formats
      }

      // 📜 Step B: Construct a complete validation Tag to satisfy background assertion check
      final manualMediaTag = MediaItem(
        id: secureUrl,
        album: "Surah Full Audio",
        title: printableTitle,
        extras: {
          'sura_id': suspectedSuraId,
          'aya_id': 0, // 0 indicates full surah streaming mode
          'is_manual': true,
        },
      );

      // 3. Set the audio source WITH the validation background tag assigned!
      await _audioPlayer.setAudioSource(
        AudioSource.uri(
          Uri.parse(secureUrl),
          headers: {
            'User-Agent': 'Mozilla/5.0',
            'Accept': '*/*',
          },
          tag: manualMediaTag, // 👈 FIXED: This satisfies the validation loop constraint!
        ),
        preload: true,
      ).timeout(const Duration(seconds: 20));

      // 4. Clear the loading indicator right before firing playback command
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
    _audioPlayer.playing ? _audioPlayer.pause() : _audioPlayer.play();
    notifyListeners();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}