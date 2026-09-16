import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:quran_complete/screen/bottombar/hadiths/quran/audio_controller.dart';
import 'package:quran_complete/screen/dashboard_logic.dart';

// Ensure this path matches where your actual widget is stored:
// import 'package:quran_complete/widgets/inline_banner_ad_widget.dart';
import ' search_screen.dart';

class BookmarkScreen extends StatelessWidget {
  const BookmarkScreen({super.key});

  static const Color brandGreen = Color(0xFF006B3C);
  static const Color headerColor = Color(0xFFD0E8D8);
  static const Color softBg = Color(0xFFF8FBF9);

  /// Helper launcher to open the Bookmarks view from external dashboard views safely.
  static void openBookmarks(BuildContext context) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (context) => const BookmarkScreen()),
    );

    if (result != null && context.mounted) {
      final controller = Provider.of<DashboardController>(context, listen: false);

      if (result['type'] == 'sura') {
        await controller.fetchAyas(result['sura_id']);
        controller.selectSura(result['sura']);
      }
      else if (result['type'] == 'aya') {
        if (result['sura'] != null && result['sura'].isNotEmpty) {
          controller.selectSura(result['sura']);
        }
        await controller.fetchAyas(result['sura_id']);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          controller.playAyaAudio(result['aya_index']);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DashboardController>();

    List<Map<String, dynamic>> bookmarkedAyas = controller.bookmarkedAyas;
    List<Map<String, dynamic>> bookmarkedSuras = [];

    try {
      bookmarkedSuras = controller.bookmarkedSuras;
    } catch (_) {}

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: softBg,
        appBar: AppBar(
          backgroundColor: headerColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'বুকমার্ক সমূহ',
            style: TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          bottom: const TabBar(
            labelColor: brandGreen,
            unselectedLabelColor: Colors.black54,
            indicatorColor: brandGreen,
            indicatorWeight: 3,
            tabs: [
              Tab(text: 'বুকমার্ক আয়াত'),
              Tab(text: 'বুকমার্ক সূরা'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // --- TAB 1: BOOKMARKED AYAS ---
            Column(
              children: [
                Expanded(
                  child: bookmarkedAyas.isEmpty
                      ? _buildEmptyState('কোন বুকমার্ক আয়াত পাওয়া যায়নি')
                      : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    itemCount: bookmarkedAyas.length,
                    itemBuilder: (context, index) {
                      return _buildAyaBookmarkCard(context, bookmarkedAyas[index], controller);
                    },
                  ),
                ),
                _buildInlineAdRow(),
              ],
            ),

            // --- TAB 2: BOOKMARKED SURAS ---
            Column(
              children: [
                Expanded(
                  child: bookmarkedSuras.isEmpty
                      ? _buildEmptyState('কোন বুকমার্ক সূরা পাওয়া যায়নি')
                      : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    itemCount: bookmarkedSuras.length,
                    itemBuilder: (context, index) {
                      final sura = bookmarkedSuras[index];
                      final int suraId = int.tryParse(sura['id'].toString()) ?? 0;

                      // Using Builder here allows us to accurately isolate context selections
                      // without causing layout frame teardown crashes on pop.
                      return Builder(
                        builder: (cardContext) {
                          final bool isThisSurahPlaying = cardContext.select<AudioController, bool>((audio) {
                            return audio.isPlaying && audio.currentPlayingSuraId == suraId;
                          });

                          return _buildSuraBookmarkCard(cardContext, sura, controller, isThisSurahPlaying);
                        },
                      );
                    },
                  ),
                ),
                _buildInlineAdRow(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineAdRow() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 320,
              minHeight: 50,
            ),
            // Fallback placeholder container if implementation is missing, otherwise clean compile
            child: const InlineBannerAdWidget(),
          ),
        ),
      ),
    );
  }

  Widget _buildAyaBookmarkCard(BuildContext context, Map<String, dynamic> aya, DashboardController controller) {
    final hasArabic = aya['text_arabic'] != null && aya['text_arabic'].toString().isNotEmpty;
    final hasBangla = aya['text_bangla'] != null && aya['text_bangla'].toString().isNotEmpty;

    final int targetSuraId = int.tryParse(aya['sura_id'].toString()) ?? 1;
    final int rawAyaNumber = int.tryParse((aya['aya_id'] ?? aya['verse_id'] ?? '1').toString()) ?? 1;
    final int targetAyaIndex = rawAyaNumber - 1;

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: brandGreen.withOpacity(0.1)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          HapticFeedback.lightImpact();

          try {
            final targetSuraMap = controller.suras.firstWhere(
                  (sura) => (int.tryParse(sura['id'].toString()) ?? -1) == targetSuraId,
              orElse: () => <String, dynamic>{},
            );

            if (targetSuraMap.isNotEmpty) {
              controller.selectSura(targetSuraMap);
            }

            await controller.fetchAyas(targetSuraId);

            if (context.mounted) {
              Navigator.of(context).pop();

              if (controller.ayas.isNotEmpty) {
                final verifiedPlayIndex = targetAyaIndex < controller.ayas.length ? targetAyaIndex : 0;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  controller.playAyaAudio(verifiedPlayIndex);
                });
              }
            }
          } catch (e) {
            debugPrint("Bookmark routing thread optimization failed: $e");
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: headerColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'সূরা #$targetSuraId : আয়াত #$rawAyaNumber',
                      style: const TextStyle(color: brandGreen, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.star, color: Color(0xFFFFB300), size: 22),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      controller.toggleAyaBookmark(aya);
                    },
                  )
                ],
              ),
              if (hasArabic) ...[
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    aya['text_arabic']!,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: brandGreen, height: 1.6),
                  ),
                ),
              ],
              if (hasBangla) ...[
                const SizedBox(height: 10),
                Text(
                  aya['text_bangla']!,
                  style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.4),
                ),
              ] else if (!hasArabic && !hasBangla) ...[
                const SizedBox(height: 12),
                Text(
                  'বিস্তারিত দেখতে এখানে ট্যাপ করুন',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500], fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuraBookmarkCard(BuildContext context, Map<String, dynamic> sura, DashboardController controller, bool isThisSurahPlaying) {
    final isMeccan = sura['revelation_type'] == 'Meccan';
    final int suraId = int.tryParse(sura['id'].toString()) ?? 0;
    final String totalAyaStr = sura['total_aya'] != null ? sura['total_aya'].toString() : '০';

    return Card(
      elevation: 0,
      color: isThisSurahPlaying ? brandGreen.withOpacity(0.04) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isThisSurahPlaying ? brandGreen : brandGreen.withOpacity(0.1),
          width: isThisSurahPlaying ? 1.5 : 1,
        ),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          HapticFeedback.lightImpact();

          if (context.mounted) {
            Navigator.of(context).pop();
          }

          await controller.fetchAyas(suraId);
          controller.selectSura(sura);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          sura['name_en'] ?? 'N/A',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.black87),
                        ),
                        if (isThisSurahPlaying) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.volume_up, color: brandGreen, size: 18),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sura['name_bn'] ?? '',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: brandGreen),
                        const SizedBox(width: 4),
                        Text(
                          "${isMeccan ? 'মক্কী' : 'মাদানী'} • $totalAyaStr আয়াত",
                          style: const TextStyle(fontSize: 12, color: brandGreen, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFFFB300),
                          size: 24,
                        ),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          controller.toggleSuraBookmark(sura);
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        sura['name_ar'] ?? '',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: brandGreen),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isThisSurahPlaying ? brandGreen : headerColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Sura #$suraId',
                      style: TextStyle(
                          color: isThisSurahPlaying ? Colors.white : brandGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 10
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String feedbackMessage) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.star_border_rounded, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            feedbackMessage,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey),
          ),
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

  // WARNING: Replace this test ID with your real AdMob Unit ID in production!
  final String _adUnitId = 'ca-app-pub-7494179033430216/3157113545';

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: _adUnitId,
      size: AdSize.banner, // Standard 320x50 banner matching your log profiles
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('✅ Ad layout loaded successfully.');
          setState(() {
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('❌ Ad layout failed to load: $error');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    // Crucial to prevent memory leaks when navigating away from Bookmarks
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isAdLoaded && _bannerAd != null) {
      return SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }

    // Returns an empty spacer until the ad arrives, preventing UI layout stuttering
    return const SizedBox(height: 50, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF006B3C))));
  }
}