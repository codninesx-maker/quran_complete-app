import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:quran_complete/screen/dashboard_logic.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounceTimer;

  BannerAd? _inlineBannerAd;
  bool _isInlineAdLoaded = false;

  // Cached collections to prevent repetitive CPU execution on build frames
  List<Map<String, dynamic>> _filteredSuras = [];
  List<Map<String, dynamic>> _filteredHadiths = [];
  List<Map<String, dynamic>> _filteredDuas = [];

  @override
  void initState() {
    super.initState();
    _loadInlineAd();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _inlineBannerAd?.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Normalizes Arabic text by removing diacritics (Harakat) for flexible searching
  String _removeArabicDiacritics(String input) {
    final exp = RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED]');
    return input.replaceAll(exp, '');
  }

  /// Converts Bengali numbers to standard English digits for uniform filtering
  String _normalizeNumbers(String input) {
    const banglaToEnglish = {
      '০': '0', '১': '1', '২': '2', '৩': '3', '৪': '4',
      '৫': '5', '৬': '6', '৭': '7', '৮': '8', '৯': '9',
    };
    return input.split('').map((char) => banglaToEnglish[char] ?? char).join();
  }

  /// Converts English numbers to Bengali numerals for user interface presentation
  String _toBanglaNumber(String englishNumber) {
    const englishToBangla = {
      '0': '০', '1': '১', '2': '২', '3': '৩', '4': '৪',
      '5': '৫', '6': '৬', '7': '৭', '8': '৮', '9': '৯',
    };
    return englishNumber.split('').map((char) => englishToBangla[char] ?? char).join();
  }

  void _loadInlineAd() {
    _inlineBannerAd = BannerAd(
      adUnitId: 'ca-app-pub-7494179033430216/3157113545',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isInlineAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Inline Ad failed to load: $error');
          ad.dispose();
        },
      ),
    );
    _inlineBannerAd?.load();
  }

  /// Core logic handling word, letter, number, and language processing
  void _onSearchChanged(String value, DashboardController controller) {
    setState(() {
      _searchQuery = value;
    });

    // Cancel active timers to prevent excessive background processing overhead
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    final String cleanQuery = value.trim().toLowerCase();

    if (cleanQuery.isEmpty) {
      setState(() {
        _filteredSuras = [];
        _filteredHadiths = [];
        _filteredDuas = [];
      });
      try {
        controller.performSearch('');
      } catch (_) {}
      return;
    }

    final String normalizedQuery = _normalizeNumbers(cleanQuery);
    final String cleanArabicQuery = _removeArabicDiacritics(normalizedQuery);

    // Create robust token blocks split by spaces, hyphens, colons, or commas
    final List<String> queryTokens = cleanArabicQuery
        .split(RegExp(r'[\s\-\:\,]+'))
        .where((t) => t.isNotEmpty)
        .toList();

    if (queryTokens.isEmpty) return;

    // Safely extract existing state references from the logic controller using alternative string maps
    List<Map<String, dynamic>> allSuras = [];
    List<Map<String, dynamic>> allHadiths = [];
    List<Map<String, dynamic>> allDuas = [];

    try {
      final dynamic dynController = controller;
      if (dynController.suras != null) allSuras = List<Map<String, dynamic>>.from(dynController.suras);
    } catch (_) {}
    try {
      final dynamic dynController = controller;
      if (dynController.hadiths != null) allHadiths = List<Map<String, dynamic>>.from(dynController.hadiths);
    } catch (_) {}
    try {
      final dynamic dynController = controller;
      if (dynController.duas != null) allDuas = List<Map<String, dynamic>>.from(dynController.duas);
    } catch (_) {}

    setState(() {
      // 1. Comprehensive Sura Matching
      _filteredSuras = allSuras.where((sura) {
        final String suraId = (sura['id'] ?? '').toString();
        final String nameEn = (sura['name_en'] ?? '').toLowerCase();
        final String nameBn = (sura['name_bn'] ?? '').toLowerCase();
        final String nameArClean = _removeArabicDiacritics((sura['name_ar'] ?? '').toLowerCase());
        final String totalAya = (sura['total_aya'] ?? '').toString();

        return queryTokens.every((token) {
          return suraId == token ||
              nameEn.contains(token) ||
              nameBn.contains(token) ||
              nameArClean.contains(token) ||
              totalAya == token;
        });
      }).toList();

      // 2. Comprehensive Hadith Matching
      _filteredHadiths = allHadiths.where((hadith) {
        final String hadithId = (hadith['id'] ?? '').toString();
        final String title = (hadith['title'] ?? '').toLowerCase();
        final String text = (hadith['text'] ?? hadith['hadith_text'] ?? '').toLowerCase();
        final String chapter = (hadith['chapter'] ?? '').toLowerCase();
        final String source = (hadith['source'] ?? '').toLowerCase();

        return queryTokens.every((token) {
          return hadithId == token ||
              title.contains(token) ||
              text.contains(token) ||
              chapter.contains(token) ||
              source.contains(token);
        });
      }).toList();

      // 3. Comprehensive Dua Matching
      _filteredDuas = allDuas.where((dua) {
        final String duaId = (dua['id'] ?? '').toString();
        final String title = (dua['title'] ?? dua['name'] ?? '').toLowerCase();
        final String textArabicClean = _removeArabicDiacritics((dua['text_arabic'] ?? '').toLowerCase());
        final String textBangla = (dua['text_bangla'] ?? dua['translation'] ?? '').toLowerCase();

        return queryTokens.every((token) {
          return duaId == token ||
              title.contains(token) ||
              textArabicClean.contains(token) ||
              textBangla.contains(token);
        });
      }).toList();
    });

    // 4. Debounced Local Database Deep Fetch (Prevents keystroke performance lag)
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted && _searchQuery.trim().isNotEmpty) {
        try {
          controller.performSearch(value);
        } catch (e) {
          debugPrint("Backend search execution caught safely: $e");
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DashboardController>();
    const brandGreen = Color(0xFF006B3C);
    const headerColor = Color(0xFFD0E8D8);

    List<Map<String, dynamic>> allSuras = [];
    try {
      final dynamic dynController = controller;
      if (dynController.suras != null) allSuras = List<Map<String, dynamic>>.from(dynController.suras);
    } catch (_) {}

    List<Map<String, dynamic>> globalSearchAyas = [];
    try {
      final dynamic dynController = controller;
      if (dynController.searchResults != null) {
        globalSearchAyas = List<Map<String, dynamic>>.from(dynController.searchResults);
      }
    } catch (_) {}

    final bool hasResults = _filteredSuras.isNotEmpty ||
        globalSearchAyas.isNotEmpty ||
        _filteredHadiths.isNotEmpty ||
        _filteredDuas.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FBF9),
      appBar: AppBar(
        backgroundColor: headerColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'সর্বজনীন অনুসন্ধান',
          style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // --- SEARCH INPUT BOX PANEL ---
          Container(
            color: headerColor,
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 16, top: 4),
            child: TextField(
              controller: _searchController,
              cursorColor: brandGreen,
              textInputAction: TextInputAction.search,
              onChanged: (value) => _onSearchChanged(value, controller),
              onSubmitted: (value) {
                if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
                if (value.trim().isNotEmpty) {
                  try {
                    controller.performSearch(value);
                  } catch (_) {}
                }
              },
              decoration: InputDecoration(
                hintText: 'সূরা, আয়াত, শব্দ, দুআ বা হাদীস খুঁজুন...',
                hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: brandGreen, size: 22),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('', controller);
                  },
                )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // --- AD DESIGN CONTAINER ---
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: InlineBannerAdWidget(),
          ),

          // --- SEARCH INTERACTION RESULTS RENDERER ---
          Expanded(
            child: controller.isLoading
                ? const Center(child: CircularProgressIndicator(color: brandGreen))
                : _searchQuery.isEmpty
                ? _buildInitialState()
                : !hasResults
                ? _buildEmptyState()
                : CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                // Section A: Matching Suras Found
                if (_filteredSuras.isNotEmpty) ...[
                  _buildSectionHeader('সূরাসমূহ (${_toBanglaNumber(_filteredSuras.length.toString())}টি)'),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildSuraSearchCard(context, _filteredSuras[index], controller),
                        childCount: _filteredSuras.length,
                      ),
                    ),
                  ),
                ],

                // Section B: Live Global Ayas Found
                if (globalSearchAyas.isNotEmpty) ...[
                  _buildSectionHeader('আয়াতসমূহ (${_toBanglaNumber(globalSearchAyas.length.toString())}টি)'),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildAyaSearchCard(context, globalSearchAyas[index], controller, allSuras),
                        childCount: globalSearchAyas.length,
                      ),
                    ),
                  ),
                ],

                // Section C: Matching Hadiths Found
                if (_filteredHadiths.isNotEmpty) ...[
                  _buildSectionHeader('হাদীসসমূহ (${_toBanglaNumber(_filteredHadiths.length.toString())}টি)'),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildHadithSearchCard(context, _filteredHadiths[index], controller),
                        childCount: _filteredHadiths.length,
                      ),
                    ),
                  ),
                ],

                // Section D: Matching Duas Found
                if (_filteredDuas.isNotEmpty) ...[
                  _buildSectionHeader('দুআসমূহ (${_toBanglaNumber(_filteredDuas.length.toString())}টি)'),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildDuaSearchCard(context, _filteredDuas[index], controller),
                        childCount: _filteredDuas.length,
                      ),
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(left: 22, right: 22, top: 22, bottom: 10),
        child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 0.2)),
      ),
    );
  }

  Widget _buildSuraSearchCard(BuildContext context, Map<String, dynamic> sura, DashboardController controller) {
    const brandGreen = Color(0xFF006B3C);
    final isMeccan = sura['revelation_type'] == 'Meccan';
    final String totalAyaStr = sura['total_aya'] != null ? _toBanglaNumber(sura['total_aya'].toString()) : '০';

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: brandGreen.withOpacity(0.08))),
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          FocusScope.of(context).unfocus();
          Navigator.of(context).pop();
          Future.microtask(() => controller.selectSura(sura));
        },
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sura['name_en'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                    const SizedBox(height: 2),
                    Text(sura['name_bn'] ?? '', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    const SizedBox(height: 8),
                    Text("${isMeccan ? 'মক্কী' : 'মাদানী'} • $totalAyaStr আয়াত", style: const TextStyle(fontSize: 11, color: brandGreen, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(sura['name_ar'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: brandGreen)),
                  const SizedBox(height: 6),
                  Text('সূরা #${_toBanglaNumber(sura['id'].toString())}', style: const TextStyle(color: brandGreen, fontWeight: FontWeight.bold, fontSize: 10)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAyaSearchCard(BuildContext context, Map<String, dynamic> aya, DashboardController controller, List<Map<String, dynamic>> suras) {
    const brandGreen = Color(0xFF006B3C);
    final String arabicContent = (aya['arabic_text'] ?? aya['text_arabic'] ?? '').toString();
    final String banglaContent = (aya['bangla_translation'] ?? aya['text_bangla'] ?? '').toString();
    final String displaySuraId = (aya['sura_id'] ?? '').toString();
    final String displayAyaId = _toBanglaNumber((aya['aya_id'] ?? aya['verse_id'] ?? '').toString());

    String suraNameBn = '';
    try {
      final parent = suras.firstWhere((s) => s['id'].toString() == displaySuraId);
      suraNameBn = " (${parent['name_bn'] ?? ''})";
    } catch (_) {}

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: brandGreen.withOpacity(0.08))),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          FocusScope.of(context).unfocus();
          final int suraIdInt = int.tryParse(displaySuraId) ?? 1;
          final int ayaIndexInt = int.tryParse((aya['aya_id'] ?? aya['verse_id'] ?? '1').toString()) ?? 1;

          try {
            await controller.fetchAyas(suraIdInt);
            final fetchedAyas = controller.ayas;
            final targetSuraMap = suras.firstWhere((s) => s['id'].toString() == displaySuraId);

            controller.selectSura(targetSuraMap, preLoadedAyas: fetchedAyas);

            if (context.mounted) {
              Navigator.of(context).pop();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                try {
                  (controller as dynamic).jumpToAya(ayaIndexInt);
                } catch (_) {
                  controller.playAyaAudio(ayaIndexInt - 1);
                }
              });
            }
          } catch (e) {
            debugPrint("Navigation pipeline exception: $e");
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFD0E8D8), borderRadius: BorderRadius.circular(6)),
                child: Text('সূরা ${_toBanglaNumber(displaySuraId)}$suraNameBn : আয়াত #$displayAyaId', style: const TextStyle(color: brandGreen, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              if (arabicContent.isNotEmpty) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(arabicContent, textAlign: TextAlign.right, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: brandGreen, height: 1.5)),
                ),
              ],
              if (banglaContent.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(banglaContent, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: Colors.grey[800], height: 1.4)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHadithSearchCard(BuildContext context, Map<String, dynamic> hadith, DashboardController controller) {
    final displaySource = hadith['source'] ?? 'হাদীস';
    final displayId = hadith['id'] != null ? _toBanglaNumber(hadith['id'].toString()) : '';

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.amber.withOpacity(0.2))),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFFFF3CD), borderRadius: BorderRadius.circular(6)),
                  child: Text('$displaySource $displayId', style: const TextStyle(color: Colors.brown, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                Text(hadith['chapter'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 10),
            if (hadith['title'] != null) ...[
              Text(hadith['title'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 6),
            ],
            Text(hadith['text'] ?? hadith['hadith_text'] ?? '', maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: Colors.grey[800], height: 1.4)),
          ],
        ),
      ),
    );
  }

  Widget _buildDuaSearchCard(BuildContext context, Map<String, dynamic> dua, DashboardController controller) {
    const brandGreen = Color(0xFF006B3C);
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.blue.withOpacity(0.15))),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFE1F5FE), borderRadius: BorderRadius.circular(6)),
              child: const Text('দুআ ও যিকর', style: TextStyle(color: Color(0xFF0288D1), fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 10),
            Text(dua['title'] ?? dua['name'] ?? 'দুআ', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
            if (dua['text_arabic'] != null) ...[
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight, child: Text(dua['text_arabic'], textAlign: TextAlign.right, style: const TextStyle(fontSize: 18, color: brandGreen, fontWeight: FontWeight.bold))),
            ],
            if (dua['text_bangla'] != null || dua['translation'] != null) ...[
              const SizedBox(height: 6),
              Text(dua['text_bangla'] ?? dua['translation'], maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.4)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInitialState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          const Text('সূরা, আয়াত, হাদীস বা দুআ খুঁজুন', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sentiment_dissatisfied_rounded, size: 56, color: Colors.grey[300]),
          const SizedBox(height: 12),
          const Text('কোন তথ্য খুঁজে পাওয়া যায়নি', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey)),
        ],
      ),
    );
  }
}

class InlineBannerAdWidget extends StatefulWidget {
  const InlineBannerAdWidget({super.key});

  @override
  State<InlineBannerAdWidget> createState() => _InlineBannerAdWidgetState();
}

class _InlineBannerAdWidgetState extends State<InlineBannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _initAd();
  }

  void _initAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-7494179033430216/3157113545',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;
          setState(() {
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Inline Ad failed to load safely: $error');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdLoaded || _bannerAd == null) {
      return const SizedBox(height: 60);
    }

    const brandGreen = Color(0xFF006B3C);

    return Container(
      alignment: Alignment.center,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: brandGreen.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'স্পন্সরড',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: brandGreen.withOpacity(0.6),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          SizedBox(
            width: _bannerAd!.size.width.toDouble(),
            height: _bannerAd!.size.height.toDouble(),
            child: AdWidget(ad: _bannerAd!),
          ),
        ],
      ),
    );
  }
}