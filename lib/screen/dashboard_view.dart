import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:quran_complete/externalads/ad_helper.dart';
import 'package:quran_complete/screen/bottombar/allah.dart';
import 'package:quran_complete/screen/bottombar/duas/dua-detail_screen.dart';
import 'package:quran_complete/screen/bottombar/duas/main_dua_screen.dart';
import 'package:quran_complete/screen/bottombar/hadiths/category_grid_view.dart';
import 'package:quran_complete/screen/bottombar/hadiths/hadith_detail_screen.dart';
import 'package:quran_complete/screen/bottombar/hadiths/main_hadith_screen.dart';
import 'package:quran_complete/screen/bottombar/hadiths/quran/audio_controller.dart';
import 'package:quran_complete/screen/bottombar/hadiths/quran/aya_screen.dart';
import 'package:quran_complete/screen/bottombar/hadiths/quran/archive/peace_screen.dart';
import 'package:quran_complete/screen/bottombar/hadiths/quran/sura_screen.dart';
import 'package:quran_complete/screen/dashboard_logic.dart';
import 'package:quran_complete/screen/topbar/%20search_screen.dart';
import 'package:quran_complete/screen/topbar/book_mark_screen.dart';
import 'package:quran_complete/screen/topbar/show_reciter_selection.dart';


class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  BannerAd? _bottomBannerAd;
  bool _isBannerLoaded = false;

  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdReady = false;
  bool _isAdLoading = false;

  @override
  void initState() {
    super.initState();
    _initBottomBanner();
    _loadInterstitialAd();
  }

  @override
  void dispose() {
    _bottomBannerAd?.dispose(); // Always clear out platform view memory allocations
    _interstitialAd?.dispose();
    super.dispose();
  }

  void _initBottomBanner() {
    _bottomBannerAd = BannerAd(
      adUnitId: AdHelper.bannerAdUnitId, // Automatically handles Test vs Prod IDs
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;
          setState(() {
            _isBannerLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('QURAN_BANNER_ERR: ${error.message}');
          ad.dispose();
        },
      ),
    )..load();
  }

  void _loadInterstitialAd() {
    // Guard clause: stop if already loading or already fetched and cached
    if (_isAdLoading || _isInterstitialAdReady) return;

    setState(() {
      _isAdLoading = true;
    });

    debugPrint('QURAN_ADS: Starting background network fetch for Interstitial...');

    InterstitialAd.load(
      adUnitId: AdHelper.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          setState(() {
            _interstitialAd = ad;
            _isInterstitialAdReady = true;
            _isAdLoading = false;
          });
          debugPrint('QURAN_ADS: SUCCESS! Interstitial fully ready in memory.');
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('QURAN_ADS_ERR: Network fetch failed: ${error.message}');
          setState(() {
            _isInterstitialAdReady = false;
            _isAdLoading = false;
            _interstitialAd = null;
          });
        },
      ),
    );
  }

  void _showInterstitialAd() {
    if (_isInterstitialAdReady && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          debugPrint('QURAN_ADS: Ad closed by user. Allocating next slot.');
          ad.dispose();
          setState(() {
            _isInterstitialAdReady = false;
            _interstitialAd = null;
          });
          _loadInterstitialAd(); // Quietly pre-fetch the next one ahead of time
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          debugPrint('QURAN_ADS_ERR: Display crash occurred: ${error.message}');
          ad.dispose();
          setState(() {
            _isInterstitialAdReady = false;
            _interstitialAd = null;
          });
          _loadInterstitialAd();
        },
      );

      _interstitialAd!.show();
    } else {
      // 🟩 FIXED: Instead of spamming the network layer, we give the user visual feedback
      debugPrint('QURAN_ADS: Click ignored. Ad stream still buffering on background isolate.');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emoji rewards are preparing, please tap again in a moment!'),
          duration: Duration(seconds: 2),
        ),
      );

      // Safely attempt to wake up the initialization engine if it failed earlier
      _loadInterstitialAd();
    }
  }


  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DashboardController>();

    final List<String> _titles = [
      'আল কুরআন',
      'হাদীস',
      'দোয়া',
      'আল্লাহর ৯৯ নাম',
      'মানসিক শান্তি',
    ];

    return Scaffold(
      // --- Top Bar ---
      appBar: AppBar(
        // 1. Brand Color & Style
        backgroundColor: const Color(0xFFD0E8D8), // Your brand header color
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark, // Keeps status bar icons visible
        centerTitle: false,

        // 2. Dynamic Back Button (Single Source of Truth)
        // This back button appears automatically when navigating into categories/details
        leading: controller.isSubViewOpen
            ? IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.black),
          onPressed: () => controller.handleGlobalBack(),
        )
            : null,

        // 3. Dynamic Title
        title: Text(
          // Priority 1: If a Sura is selected (Quran Tab)
          controller.selectedSuraDetail != null
              ? controller.selectedSuraDetail!['name_bn']

          // Priority 2: If a specific Dua is open
              : controller.selectedDuaDetail != null
              ? 'দোয়ার বিবরণ'

          // Priority 3: If a specific Hadith is open
              : controller.selectedHadithDetail != null
              ? 'হাদিস বিবরণ'

          // Priority 4: If a category/range is open (Dua or Hadith)
              : (controller.selectedDuaCategory ??
              controller.selectedHadithRangeTitle ??
              _titles[controller.selectedIndex]),

          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),

        // 4. Actions (Consistent icons)
        actions: [
          // Only show the Reciter button if a Sura is currently open (AyaScreen is visible)
          if (controller.selectedSuraDetail != null)
            IconButton(
              icon: const Icon(Icons.record_voice_over_outlined, color: Color(0xFF006B3C)),
              onPressed: () {
                // 1. Compute your current audio positional values synchronously
                int indexToPlay = controller.ayas.indexWhere((aya) {
                  final id = aya['aya_id'] ?? aya['verse_id'];
                  return int.tryParse(id.toString()) == controller.audioController.currentAyaIndex;
                });

                if (indexToPlay == -1) {
                  indexToPlay = 0; // Default fallback index
                }

                // 2. Safe Window: Schedule dialog rendering on the next frame pass
                // to bypass the Tecno graphics buffer allocation conflict.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    ReciterDialog.show(
                      context,
                      controller,
                      indexToPlay,
                    );
                  }
                });
              },
              tooltip: 'Select Reciter',
            ),

          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFF006B3C)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SearchScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_border, color: Color(0xFF006B3C)),
            onPressed: () {
              // Navigates directly to your BookmarkScreen implementation
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BookmarkScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.emoji_emotions_outlined, // Fun smiley style icon
              color: Color(0xFF006B3C),
              size: 26,
            ),
            onPressed: () {
              // Triggers the smart-guard display logic safely
              _showInterstitialAd();
            },
          ),
        ],
      ),

      // --- Body ---
      // Fixed: IndexedStack is clean and fills available frame directly
      body: IndexedStack(
        index: controller.selectedIndex,
        children: [
          _buildSuraTab(controller),
          _buildHadithTab(controller),
          _buildDuaTab(controller),
          const AllahScreen(),
          const PeaceScreen(),
        ],
      ),

      // --- Bottom System Bar Slot ---
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min, // Prevents Column from overflowing full screen height
        children: [
          // Fixed structural injection point above the navigation view items
          if (_bottomBannerAd != null && _isBannerLoaded)
            SafeArea(
              top: false,
              bottom: false, // Let navigation bar handle the system safe padding below
              child: Container(
                width: double.infinity, // Forces full horizontal frame registration
                height: _bottomBannerAd!.size.height.toDouble(),
                alignment: Alignment.center,
                child: SizedBox(
                  width: _bottomBannerAd!.size.width.toDouble(),
                  height: _bottomBannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _bottomBannerAd!),
                ),
              ),
            ),

          NavigationBar(
            elevation: 8,
            // Force visibility for Tecno devices
            backgroundColor: Theme.of(context).colorScheme.surface,
            selectedIndex: controller.selectedIndex,
            onDestinationSelected: (int index) {
              controller.setTabIndex(index); // Updates via logic file
            },
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.menu_book_outlined),
                selectedIcon: Icon(Icons.menu_book, color: Color(0xFF006B3C)),
                label: 'Quran',
              ),
              const NavigationDestination(
                icon: Icon(Icons.library_books_outlined),
                selectedIcon: Icon(Icons.library_books, color: Color(0xFF006B3C)),
                label: 'Hadiths',
              ),
              NavigationDestination(
                icon: const Text('🤲', style: TextStyle(fontSize: 22)),
                selectedIcon: ShaderMask(
                  shaderCallback: (Rect bounds) => const LinearGradient(
                    colors: [Color(0xFF006B3C), Color(0xFF006B3C)],
                  ).createShader(bounds),
                  child: const Text('🤲', style: TextStyle(fontSize: 22, color: Colors.white)),
                ),
                label: 'Duas',
              ),
              const NavigationDestination(
                icon: Icon(Icons.auto_awesome_outlined),
                selectedIcon: Icon(Icons.auto_awesome, color: Color(0xFF006B3C)),
                label: 'Allah',
              ),
              const NavigationDestination(
                icon: Icon(Icons.spa_outlined), // Peace icon
                selectedIcon: Icon(Icons.spa, color: Color(0xFF006B3C)),
                label: 'Peace',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuraTab(DashboardController controller) {
    return PopScope(
      canPop: !controller.isSubViewOpen,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        controller.handleGlobalBack();
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: controller.selectedSuraDetail != null
            ? AyaScreen(
          // Use a key so Flutter knows to animate the transition
          key: ValueKey('AyaScreen_${controller.selectedSuraDetail!['id']}'),
          sura: controller.selectedSuraDetail!,
        )
        // Use your refactored SuraScreen class here
            : SuraScreen(key: ValueKey('SuraListV2')),
      ),
    );
  }

  Widget _buildHadithTab(DashboardController controller) {
    if (controller.selectedHadithDetail != null) {
      return const HadithDetailScreen();
    }
    // FIX: Use selectedHadithRangeTitle, NOT selectedDuaCategory
    if (controller.selectedHadithRangeTitle != null) {
      return const CategoryGridView();
    }
    return const MainHadithScreen();
  }

  Widget _buildDuaTab(DashboardController controller) {
    // 1. Show specific Dua detail
    if (controller.selectedDuaDetail != null) {
      return const DuaDetailScreen();
    }

    // 2. Show the list of Duas inside a category
    if (controller.selectedDuaCategory != null) {
      // This should be your screen that lists the prayers,
      // e.g., CategoryDuaListScreen()
      return const DuasScreen();
    }

    // 3. Default: The main screen with Category Grid
    return const DuasScreen();
  }
}