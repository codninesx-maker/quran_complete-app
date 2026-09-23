import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:quran_complete/quran_repository.dart';
import 'package:quran_complete/screen/bottombar/hadiths/quran/audio_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';



class DashboardController extends ChangeNotifier {
  final QuranRepository _repository = QuranRepository();
  final supabase = Supabase.instance.client;
  final AudioController _audioController;
  AudioController get audioController => _audioController;



  DashboardController(this._audioController) {
    fetchReciters();
    loadBookmarksFromDisk();
    _audioController.addListener(_handleAudioControllerUpdate);
  }

  void _handleAudioControllerUpdate() {
    // 🌟 1. Track Aya index changes
    if (_currentAyaIndex != _audioController.currentAyaIndex) {
      _currentAyaIndex = _audioController.currentAyaIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }

    // 🌟 2. Track Sura ID changes automatically when audio transitions to the next Sura
    final int? activeAudioSuraId = _audioController.currentPlayingSuraId;
    if (activeAudioSuraId != null && activeAudioSuraId != -1 && activeAudioSuraId != _currentSuraId) {
      _currentSuraId = activeAudioSuraId;

      // Automatically update the selected sura detail metadata if you have the suras list loaded
      if (_suras.isNotEmpty) {
        final matchingSura = _suras.firstWhere(
              (s) => (int.tryParse(s['id'].toString()) ?? -1) == activeAudioSuraId,
          orElse: () => {},
        );
        if (matchingSura.isNotEmpty) {
          _selectedSuraDetail = matchingSura;
          _syncCurrentSuraViewState();
        }
      }

      // Automatically fetch and load the new Sura's ayas for the active screen!
      fetchAyas(activeAudioSuraId);
    }
  }

  @override
  void dispose() {
    _audioController.removeListener(_handleAudioControllerUpdate);
    // Only dispose _audioController here if DashboardController owns it exclusively.
    // _audioController.dispose();
    super.dispose();
  }

  int _selectedIndex = 0;
  int _pageSize = 20;
  int _currentAyaIndex = -1;
  int? _currentSuraId;
  bool _isFetchingMore = false;
  bool _hasMoreData = true;
  bool isBookmarked = false;
  int? _currentlyFetchingSuraId;

  // --- Private Variables ---
  String? _selectedDuaCategory;
  String? _selectedHadithRangeTitle;
  String? _currentlyPlayingUrl;
  String? get selectedDuaCategory => _selectedDuaCategory;
  String? get selectedHadithRangeTitle => _selectedHadithRangeTitle;
  String? get currentlyPlayingUrl => _currentlyPlayingUrl;


  // --- Getters ---
  int get selectedIndex => _selectedIndex;
  int get currentAyaIndex => _currentAyaIndex;
  bool get isFetchingMore => _isFetchingMore;
  bool get hasMoreData => _hasMoreData;

  Map<String, dynamic>? _selectedDuaDetail;
  Map<String, dynamic>? _selectedHadithDetail;
  Map<String, dynamic>? _selectedSuraDetail;
  Map<String, dynamic>? _selectedNameDetail;

  Map<String, dynamic>? get selectedDuaDetail => _selectedDuaDetail;
  Map<String, dynamic>? get selectedHadithDetail => _selectedHadithDetail;
  Map<String, dynamic>? get selectedSuraDetail => _selectedSuraDetail;
  Map<String, dynamic>? get selectedNameDetail => _selectedNameDetail;

  // --- Data Lists ---
  List<Map<String, dynamic>> _suras = [];
  List<Map<String, dynamic>> _ayas = [];
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _hadiths = [];
  List<Map<String, dynamic>> _duas = [];
  List<Map<String, dynamic>> _names99 = [];

  List<Map<String, dynamic>> get suras => _suras;
  List<Map<String, dynamic>> get ayas => _ayas;
  List<Map<String, dynamic>> get hadiths => _hadiths;
  List<Map<String, dynamic>> get duas => _duas;
  List<Map<String, dynamic>> get names99 => _names99;
  List<Map<String, dynamic>> get searchResults => _searchResults;
  List<Map<String, dynamic>> _reciters = [];
  Map<String, dynamic>? _selectedReciter;
  List<Map<String, dynamic>> get reciters => _reciters;
  Map<String, dynamic>? get selectedReciter => _selectedReciter;

  List<Map<String, dynamic>> _bookmarkedAyas = [];
  List<Map<String, dynamic>> get bookmarkedAyas => _bookmarkedAyas;
  List<Map<String, dynamic>> _bookmarkedSuras = [];
  List<Map<String, dynamic>> get bookmarkedSuras => _bookmarkedSuras;

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Set<int> _bookmarkedSuraIds = {};
  Set<int> get bookmarkedSuraIds => _bookmarkedSuraIds;

  bool get isSubViewOpen {
    if (_selectedIndex == 0) return _selectedSuraDetail != null;
    if (_selectedIndex == 1) return _selectedHadithRangeTitle != null || _selectedHadithDetail != null;
    if (_selectedIndex == 2) return _selectedDuaCategory != null || _selectedDuaDetail != null;
    if (_selectedIndex == 3) return _selectedNameDetail != null;
    return false;
  }
  String get dynamicTitle {
    if (_selectedIndex == 0) {
      if (_selectedSuraDetail != null) {
        // Logic: Use Bangla name if it exists, otherwise fall back to English
        return _selectedSuraDetail!['name_bn'] ?? _selectedSuraDetail!['name_en'] ?? 'সূরা';
      }
      return 'আল কুরআন';
    } else if (_selectedIndex == 1) {
      if (_selectedHadithDetail != null) return 'হাদিস বিবরণ';
      return _selectedHadithRangeTitle ?? 'আল হাদিস';
    } else if (_selectedIndex == 2) {
      if (_selectedDuaDetail != null) return 'দোয়ার বিবরণ';
      return _selectedDuaCategory ?? 'দুয়া ও যিকর';
    } else if (_selectedIndex == 3) {
      return 'আল্লাহর ৯৯ নাম';
    }
    return 'ইসলামিক অ্যাপ';
  }
  String get currentSuraName {
    if (_selectedSuraDetail != null) {
      return _selectedSuraDetail!['name_bn'] ?? _selectedSuraDetail!['name_en'] ?? 'Quran';
    }
    return 'Quran Majeed';
  }

  void selectSura(Map<String, dynamic> sura, {List<Map<String, dynamic>>? preLoadedAyas}) {
    _selectedSuraDetail = sura;

    if (preLoadedAyas != null && preLoadedAyas.isNotEmpty) {
      // ✅ Instant payload transition: use the already fetched ayas directly!
      _ayas = preLoadedAyas;
      _isLoading = false;
    } else {
      // Fallback: only clear and show spinner if we haven't fetched anything yet
      _ayas = [];
      _isLoading = true;
    }

    notifyListeners();
  }

  void pauseAudio() {
    _audioController.pause();
    notifyListeners();
  }

  void updateReciter(Map<String, dynamic> reciter) {
    _selectedReciter = reciter;
    notifyListeners();
  }

  void selectCategory(String category) {
    _selectedDuaCategory = category;
    notifyListeners();
  }

  void selectDua(Map<String, dynamic> dua) {
    _selectedDuaDetail = dua;
    notifyListeners();
  }

  void playSpecial(String url) {
    // Give the UI a moment to breathe before hitting the network
    Future.delayed(const Duration(milliseconds: 300), () {
      _audioController.playDirectUrl(url);
    });
  }

  void selectHadith(Map<String, dynamic> hadith) {
    _selectedHadithDetail = hadith;
    notifyListeners();
  }
  void selectHadithCategory(String title, int start, int end) {
    _selectedHadithRangeTitle = title; // Use the Hadith variable
    _selectedDuaCategory = null;      // Ensure Dua state is cleared
    fetchHadithsByRange(start, end);
    notifyListeners();
  }

  void updateSelectedHadithByIndex(int index) {
    if (index >= 0 && index < _hadiths.length) {
      _selectedHadithDetail = _hadiths[index];
      notifyListeners();
    }
  }

  int get currentHadithIndex {
    return _hadiths.indexWhere((h) => h['id'] == _selectedHadithDetail?['id']);
  }


  void handleGlobalBack() {
    if (_selectedIndex == 0) { // Quran Tab
      if (_selectedSuraDetail != null) {
        _selectedSuraDetail = null;
      }
    } else if (_selectedIndex == 1) {
      if (_selectedHadithDetail != null) {
        _selectedHadithDetail = null;
      } else {
        _selectedHadithRangeTitle = null;
      }
    } else if (_selectedIndex == 2) { // Dua Tab
      if (_selectedDuaDetail != null) {
        _selectedDuaDetail = null;
      } else {
        _selectedDuaCategory = null;
      }
    } else if (_selectedIndex == 3) { // Allah's Names Tab
      if (_selectedNameDetail != null) {
        _selectedNameDetail = null;
      }
    }
    _syncCurrentSuraViewState();
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

// 🚀 Call this method inside your existing function whenever bookmarks are loaded or toggled
  void updateBookmarkedIds() {
    _bookmarkedSuraIds = (bookmarkedSuras ?? []).map((element) {
      return int.tryParse(element['id'].toString()) ?? -1;
    }).toSet();
    notifyListeners();
  }

  void refreshBookmarkedIds() {
    _bookmarkedSuraIds = (_bookmarkedSuras ?? []).map((element) {
      return int.tryParse(element['id'].toString()) ?? -1;
    }).toSet();
    notifyListeners(); // Tells the UI to update with lightning speed
  }

  void toggleBookmark() {
    isBookmarked = !isBookmarked;
    // TODO: Add your Supabase sync or local database saving routines here!
    notifyListeners(); // This forces dependent widgets to re-render immediately
  }

  void setTabIndex(int index) {
    // Case 1: Tapping the active tab icon (Self-Reset / "Pop to Root")
    if (_selectedIndex == index) {
      bool changed = false;

      if (index == 0 && _selectedSuraDetail != null) {
        _selectedSuraDetail = null;
        changed = true;
      }
      else if (index == 1) {
        // If reading a specific Hadith, go back to the Hadith list for that range
        if (_selectedHadithDetail != null) {
          _selectedHadithDetail = null;
          changed = true;
        }
        // If already at the list, go back to Category/Range selection
        else if (_selectedHadithRangeTitle != null) {
          _selectedHadithRangeTitle = null;
          changed = true;
        }
      }
      else if (index == 2) {
        // If reading a specific Dua, go back to the category list
        if (_selectedDuaDetail != null) {
          _selectedDuaDetail = null;
          changed = true;
        }
        // If looking at a category, go back to the main Dua categories
        else if (_selectedDuaCategory != null) {
          _selectedDuaCategory = null;
          changed = true;
        }
      }
      else if (index == 3 && _selectedNameDetail != null) {
        _selectedNameDetail = null;
        changed = true;
      }

      if (changed) {
        _syncCurrentSuraViewState();
      }
      return;
    }

    // Case 2: Switching to a brand new tab
    _selectedIndex = index;

    // Clean slate: reset ALL sub-views so the user starts at the top of the new tab
    _selectedSuraDetail = null;
    _selectedHadithDetail = null;
    _selectedHadithRangeTitle = null;
    _selectedDuaCategory = null;
    _selectedDuaDetail = null;
    _selectedNameDetail = null;

    notifyListeners();

    // Case 3: Fetch data only if the list is empty
    if (index == 0 && _suras.isEmpty) fetchSura();
    if (index == 1 && _hadiths.isEmpty) fetchHadiths();
    if (index == 2 && _duas.isEmpty) fetchDuas();
    if (index == 3 && _names99.isEmpty) fetch99Names();
  }


  final List<String> _priorityCategories = [
    'কুরআনিক দোয়া',
    'দৈনন্দিন ও যিকর',
    'সালাত ও ইবাদত',
    'খাবার ও পানীয়',
    'ভ্রমণ ও সওয়ারী',
    'বিপদ ও সুরক্ষা',
    'পরিবার ও সামাজিক',
    'অন্যান্য',
  ];

  List<String> get duaCategories {
    if (_duas.isEmpty) return [];
    return _priorityCategories;
  }


  List<Map<String, dynamic>> getDuasByCategory(String category) {
    return _duas.where((d) {
      String title = (d['category_name'] as String? ?? '').trim();
      String reference = (d['reference'] as String? ?? '').trim();
      String arabic = (d['arabic_text'] as String? ?? '').trim();

      // ক্যাটাগরি চেনার জন্য কিছু মাস্টার কি-ওয়ার্ড
      bool isQuranic = reference.contains('সূরা') || arabic.contains('رَبَّনَا');

      bool isDaily = title.contains('ঘুম') || title.contains('পোশাক') ||
          title.contains('বাড়ি') || title.contains('সকাল') ||
          title.contains('আয়না');

      bool isSalat = title.contains('সালাত') || title.contains('মসজিদ') ||
          title.contains('ওযু') || title.contains('আযান') ||
          title.contains('তওবা');

      bool isFood = title.contains('খাওয়ার') || title.contains('পানি') ||
          title.contains('দুধ') || title.contains('ইফতার');

      bool isTravel = title.contains('বাহন') || title.contains('সফর') ||
          title.contains('বাজার') || title.contains('শহর');

      bool isDanger = title.contains('বিপদ') || title.contains('ঋণ') ||
          title.contains('শয়তান') || title.contains('রোগ') ||
          title.contains('ব্যথা') || title.contains('ধৈর্য');

      bool isSocial = title.contains('সালাম') || title.contains('উপহার') ||
          title.contains('পিতা') || title.contains('সন্তান') ||
          title.contains('কবর');

      switch (category) {
        case 'কুরআনিক দোয়া':
          return isQuranic;

        case 'দৈনন্দিন ও যিকর':
          return isDaily && !isQuranic; // কুরআন হলে এখানে দেখাবে না

        case 'সালাত ও ইবাদত':
          return isSalat && !isQuranic;

        case 'খাবার ও পানীয়':
          return isFood && !isQuranic;

        case 'ভ্রমণ ও সওয়ারী':
          return isTravel && !isQuranic;

        case 'বিপদ ও সুরক্ষা':
          return isDanger && !isQuranic;

        case 'পরিবার ও সামাজিক':
          return isSocial && !isQuranic;

        case 'অন্যান্য':
        // উপরের ৭টির কোনোটিতেই না মিললে এখানে দেখাবে
          return !isQuranic && !isDaily && !isSalat && !isFood &&
              !isTravel && !isDanger && !isSocial;

        default:
          return false;
      }
    }).toList();
  }

  Future<void> playAyaAudio(int index) async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _currentAyaIndex = index;
      _errorMessage = null;
      notifyListeners();

      try {
        // ✅ Explicitly passes exactly 2 arguments down to your AudioController parameters
        await _audioController.playAyaAudio(index, _ayas);
      } catch (e) {
        debugPrint("❌ Playback Error caught in DashboardController: $e");

        _currentAyaIndex = -1;

        if (e.toString().contains('UnknownHostException') || e.toString().contains('No address associated with hostname')) {
          _errorMessage = "অডিও প্লে করতে ইন্টারনেট সংযোগ প্রয়োজন";
        } else {
          _errorMessage = "অডিও লোড করা সম্ভব হয়নি";
        }

        notifyListeners();
      }
    });
  }

  Future<void> setReciter(Map<String, dynamic> reciter) async {
    _audioController.pause();
    _selectedReciter = reciter;
    _audioController.updateReciter(reciter);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });

    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> fetchReciters() async {
    try {
      if (_reciters.isNotEmpty) return;

      final data = await supabase.from('reciter').select();
      _reciters = List<Map<String, dynamic>>.from(data);

      if (_reciters.isNotEmpty && _selectedReciter == null) {
        // 🌟 Search for Al Matroud first (case-insensitive search on english name)
        final alMatroud = _reciters.firstWhere(
              (r) => (r['name_en'] ?? '').toLowerCase().contains('matroud'),
          orElse: () => _reciters[0], // Fallback to index 0 if not found
        );

        _selectedReciter = alMatroud;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _audioController.updateReciter(_selectedReciter!);
          notifyListeners();
        });
      }
    } catch (e) {
      debugPrint("❌ Reciter Fetch Error: $e");
    }
  }

  final Map<int, Future<void>> _activeFetchFutures = {};

  // 2. Replace your fetchAyas method with this robust version
  Future<void> fetchAyas(dynamic suraId) async {
    final int targetId = int.parse(suraId.toString());

    // Guard Clause: If this exact Sura is already fetching, return its active execution future
    if (_activeFetchFutures.containsKey(targetId)) {
      debugPrint("⚠️ Guard active: Duplicate fetch blocked for Sura ID: $targetId");
      return _activeFetchFutures[targetId];
    }

    // Define the core data operations
    final Future<void> fetchJob = () async {
      try {
        _isLoading = true;
        _ayas = [];
        // Postpone notification to the next frame to prevent immediate layout-trigger loops
        WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());

        debugPrint("I/flutter: 🔄 Querying Supabase for Sura ID: $targetId");

        final response = await supabase
            .from('aya')
            .select('*')
            .eq('sura_id', targetId)
            .order('aya_id', ascending: true);

        _ayas = List<Map<String, dynamic>>.from(response);
        debugPrint("I/flutter: ✅ Successfully loaded ${_ayas.length} Aya.");
      } catch (e) {
        debugPrint("❌ CRITICAL ERROR INSIDE FETCHAYAS: $e");
      } finally {
        // Clean up the lock exactly when this query finishes
        _activeFetchFutures.remove(targetId);
        _isLoading = false;
        notifyListeners();
      }
    }(); // Execute immediately

    // Cache the job pointer instantly before yielding control to the network
    _activeFetchFutures[targetId] = fetchJob;

    return fetchJob;
  }

  Future<void> fetchHadiths({bool isInitial = true}) async {
    // Prevent multiple simultaneous fetches
    if (_isFetchingMore || (!_hasMoreData && !isInitial)) return;

    if (isInitial) {
      _hadiths = [];
      _hasMoreData = true;
      _isLoading = true;
    } else {
      _isFetchingMore = true;
    }
    notifyListeners();

    try {
      final int from = _hadiths.length;
      final int to = from + _pageSize - 1;

      // Use the repository to get a specific range
      final List<Map<String, dynamic>> newHadiths = await _repository.getHadithsPaged(from, to);

      if (newHadiths.length < _pageSize) {
        _hasMoreData = false; // We've reached the end of the 7,600+ rows
      }

      _hadiths.addAll(newHadiths);

      print("DEBUG: Total Hadiths in memory: ${_hadiths.length}");
    } catch (e) {
      print("DEBUG: Pagination Error: $e");
    } finally {
      _isLoading = false;
      _isFetchingMore = false;
      notifyListeners();
    }
  }

  Future<void> fetchSura() async {
    final prefs = await SharedPreferences.getInstance();
    _setLoading(true);
    _errorMessage = null;

    try {
      // --- STEP 1: LOAD FROM OFFLINE CACHE FIRST ---
      final String? cachedData = prefs.getString('cached_suras');
      if (cachedData != null) {

        // 🚀 OPTIMIZATION: Heavy decoding moved to a background Isolate thread
        final List<dynamic> decodedData = await compute(
              (String data) => jsonDecode(data) as List<dynamic>,
          cachedData,
        );

        _suras = List<Map<String, dynamic>>.from(decodedData);

        // Update UI immediately with cached data
        _setLoading(false);
        notifyListeners();
        debugPrint("Loaded ${_suras.length} Suras from Cache safely on background isolate");
      }

      // --- STEP 2: FETCH FROM REPO (NETWORK/SUPABASE) ---
      debugPrint("Attempting to fetch fresh Suras...");
      final fetchedSuras = await _repository.getAllSuras();

      if (fetchedSuras.isNotEmpty) {
        _suras = fetchedSuras;
        // --- STEP 3: UPDATE CACHE WITH FRESH DATA ---
        await prefs.setString('cached_suras', jsonEncode(fetchedSuras));
        debugPrint("Suras updated and cached: ${fetchedSuras.length}");
      }

    } catch (e) {
      debugPrint("Sura Fetch Error: $e");
      // If cache was empty and fetch failed, set error
      if (_suras.isEmpty) {
        _errorMessage = "ইন্টারনেট সংযোগ চেক করুন";
      }
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> fetchHadithsByRange(int start, int end) async {
    final prefs = await SharedPreferences.getInstance();
    final String cacheKey = 'hadith_range_${start}_$end';

    _isLoading = true;
    _errorMessage = null; // Clear old errors
    _hadiths = [];        // Clear current list to show loader
    notifyListeners();

    try {
      // 1. Attempt Network Fetch
      final response = await supabase
          .from('hadiths')
          .select('*')
          .gte('hadith_number', start)
          .lte('hadith_number', end)
          .order('hadith_number', ascending: true);

      _hadiths = List<Map<String, dynamic>>.from(response);

      // 2. Save to Cache for next time
      await prefs.setString(cacheKey, jsonEncode(response));
      debugPrint("Network fetch successful for range $start-$end");

    } catch (e) {
      debugPrint('Network failed, checking cache... Error: $e');

      // 3. OFFLINE FALLBACK
      final String? cachedData = prefs.getString(cacheKey);
      if (cachedData != null) {
        _hadiths = List<Map<String, dynamic>>.from(jsonDecode(cachedData));
        _errorMessage = "ইন্টারনেট নেই, সংরক্ষিত তথ্য দেখানো হচ্ছে।";
      } else {
        _errorMessage = "ইন্টারনেট নেই এবং এই খণ্ডটি আগে লোড করা হয়নি।";
      }
    } finally {
      _isLoading = false;
      notifyListeners(); // This triggers the UI to build CategoryGridView
    }
  }


  Future<void> fetchDuas() async {
    final prefs = await SharedPreferences.getInstance();
    _isLoading = true;
    _errorMessage = null; // Clear previous errors
    notifyListeners();

    try {
      // 1. Try fetching from Supabase
      // Make sure your table name is exactly 'duas' (or whatever it is in Supabase)
      final response = await supabase
          .from('duas')
          .select()
          .order('id'); // Or your preferred order

      _duas = List<Map<String, dynamic>>.from(response);

      // 2. Cache it for offline use
      await prefs.setString('cached_duas', jsonEncode(response));

      debugPrint("Duas fetched and cached: ${_duas.length}");
    } catch (e) {
      debugPrint("Dua Fetch Error: $e");

      // 3. Fallback to cache if internet fails
      String? cachedData = prefs.getString('cached_duas');
      if (cachedData != null) {
        _duas = List<Map<String, dynamic>>.from(jsonDecode(cachedData));
        debugPrint("Loaded Duas from cache: ${_duas.length}");
      } else {
        _errorMessage = "ইন্টারনেট নেই এবং কোনো ডাটা সেভ করা নেই।";
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetch99Names() async {
    final prefs = await SharedPreferences.getInstance();

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Fetch from Supabase
      final List<dynamic> response = await supabase
          .from('allah')
          .select()
          .order('name_number', ascending: true);

      // 2. Assign and Cache
      _names99 = List<Map<String, dynamic>>.from(response);
      await prefs.setString('cached_names_99', jsonEncode(response));

      debugPrint("99 Names fetched successfully: ${_names99.length}");

    } catch (e) {
      debugPrint("99 Names Error: $e");

      // 3. Offline Fallback
      final String? cachedData = prefs.getString('cached_names_99');
      if (cachedData != null) {
        final List<dynamic> decoded = jsonDecode(cachedData);
        _names99 = List<Map<String, dynamic>>.from(decoded);
        debugPrint("Loaded 99 Names from cache");
      } else {
        _errorMessage = "No internet and no cached data found.";
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> performSearch(String query) async {
    if (query.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _setLoading(true);
    final prefs = await SharedPreferences.getInstance();

    try {
      // Attempt search
      _searchResults = await _repository.searchInBangla(query);

      // Cache the result of this specific query
      await prefs.setString('last_search_result', jsonEncode(_searchResults));
      _errorMessage = null;
    } catch (e) {
      // Fallback to the last successful search result if offline
      String? cachedSearch = prefs.getString('last_search_result');
      if (cachedSearch != null) {
        _searchResults = List<Map<String, dynamic>>.from(jsonDecode(cachedSearch));
      }
      _errorMessage = 'Offline: showing last successful search results.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadBookmarksFromDisk() async {
    debugPrint("🔄 [Bookmarks] Starting to load bookmarks from disk...");
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load Surah Bookmarks
      final String? surasJson = prefs.getString('saved_bookmarked_suras');
      if (surasJson != null) {
        final List<dynamic> decoded = jsonDecode(surasJson);
        _bookmarkedSuras = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        debugPrint("✅ [Bookmarks] Loaded ${_bookmarkedSuras.length} bookmarked Suras");
      }

      // Load Aya Bookmarks
      final String? ayasJson = prefs.getString('saved_bookmarked_ayas');
      if (ayasJson != null) {
        final List<dynamic> decoded = jsonDecode(ayasJson);
        _bookmarkedAyas = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        debugPrint("✅ [Bookmarks] Loaded ${_bookmarkedAyas.length} bookmarked Ayas");
      }

      // 🟩 FIX: Instantly sync your optimized lookup Sets after loading disk values
      _syncBookmarkedSuraIds();
      _syncCurrentSuraViewState();

    } catch (e) {
      debugPrint("❌ [Bookmarks] Error loading bookmarks: $e");
    }
  }

  void _syncBookmarkedSuraIds() {
    _bookmarkedSuraIds = _bookmarkedSuras.map((element) {
      return int.tryParse(element['id'].toString()) ?? -1;
    }).toSet();
  }

  void _syncCurrentSuraViewState() {
    if (_selectedSuraDetail != null) {
      final int currentId = int.tryParse(_selectedSuraDetail!['id'].toString()) ?? -1;
      isBookmarked = _bookmarkedSuraIds.contains(currentId);
    } else {
      isBookmarked = false;
    }
    notifyListeners();
  }

  void toggleSuraBookmark(Map<String, dynamic> sura) async {
    final int suraId = int.tryParse(sura['id'].toString()) ?? 0;

    final int existingIndex = _bookmarkedSuras.indexWhere(
            (element) => (int.tryParse(element['id'].toString()) ?? -1) == suraId
    );

    if (existingIndex >= 0) {
      _bookmarkedSuras.removeAt(existingIndex);
      debugPrint("📌 [Bookmarks] Removed Surah ID: $suraId");
    } else {
      _bookmarkedSuras.add(sura);
      debugPrint("📌 [Bookmarks] Added Surah ID: $suraId");
    }

    // 🟩 FIX: Re-calculate lookup caches immediately before writing data changes
    _syncBookmarkedSuraIds();
    _syncCurrentSuraViewState();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_bookmarked_suras', jsonEncode(_bookmarkedSuras));
  }

  void toggleAyaBookmark(Map<String, dynamic> aya) async {
    final String targetSuraId = (aya['sura_id'] ?? '').toString();
    final String targetAyaId = (aya['aya_id'] ?? aya['verse_id'] ?? aya['id'] ?? '').toString();

    final int existingIndex = _bookmarkedAyas.indexWhere((element) {
      final String currentSuraId = (element['sura_id'] ?? '').toString();
      final String currentAyaId = (element['aya_id'] ?? element['verse_id'] ?? element['id'] ?? '').toString();
      return currentSuraId == targetSuraId && currentAyaId == targetAyaId;
    });

    if (existingIndex >= 0) {
      _bookmarkedAyas.removeAt(existingIndex);
      debugPrint("📌 [Bookmarks] Removed Aya: Sura $targetSuraId, Aya $targetAyaId");
    } else {
      _bookmarkedAyas.add(aya);
      debugPrint("📌 [Bookmarks] Added Aya: Sura $targetSuraId, Aya $targetAyaId");
    }

    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    // 🟩 FIXED: Repaired the broken variable name typo string here
    await prefs.setString('saved_bookmarked_ayas', jsonEncode(_bookmarkedAyas));
  }
}