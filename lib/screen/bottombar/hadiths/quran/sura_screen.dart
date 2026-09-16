import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ Added for tactile haptic feedback
import 'package:provider/provider.dart';
import 'package:quran_complete/screen/bottombar/hadiths/quran/audio_controller.dart';
import 'package:quran_complete/screen/dashboard_logic.dart';

class SuraScreen extends StatelessWidget {
  const SuraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DashboardController>();
    final suras = controller.suras;

    const brandGreen = Color(0xFF006B3C);
    if (suras.isEmpty && !controller.isLoading) {
      return _buildEmptyState(controller);
    }

    if (controller.isLoading && suras.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: brandGreen));
    }

    return RefreshIndicator(
      onRefresh: () => controller.fetchSura(),
      color: brandGreen,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        itemCount: suras.length,
        itemBuilder: (context, index) {
          return Builder(
            builder: (cardContext) {
              return _buildSuraCard(cardContext, suras[index], controller);
            },
          );
        },
      ),
    );
  }

  Widget _buildSuraCard(BuildContext context, Map<String, dynamic> sura, DashboardController controller) {
    const brandGreen = Color(0xFF006B3C);
    const headerColor = Color(0xFFD0E8D8);
    final isMeccan = sura['revelation_type'] == 'Meccan';

    final int suraId = int.tryParse(sura['id'].toString()) ?? 0;
    final String totalAyaStr = sura['total_aya'] != null ? sura['total_aya'].toString() : '0';

    // 1. Reactive audio state check (Good!)
    final bool isThisSurahPlaying = context.select<AudioController, bool>((audio) {
      return audio.isPlaying && audio.currentPlayingSuraId == suraId;
    });

    final bool isBookmarked = controller.bookmarkedSuraIds.contains(suraId);

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
        onTap: () {
          // Debounce selection processing away from graphics sync pass
          Future.microtask(() => controller.selectSura(sura));
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
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: Colors.black87,
                          ),
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
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: brandGreen,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "${isMeccan ? 'মক্কী' : 'মাদানী'} • ${toBanglaNumber(totalAyaStr)} আয়াত",
                          style: const TextStyle(
                            fontSize: 12,
                            color: brandGreen,
                            fontWeight: FontWeight.w600,
                          ),
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
                        icon: Icon(
                          isBookmarked ? Icons.star_rounded : Icons.star_border_rounded,
                          color: isBookmarked ? const Color(0xFFFFB300) : Colors.grey[400],
                          size: 24,
                        ),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          try {
                            controller.toggleSuraBookmark(sura);
                          } catch (_) {
                            try {
                              (controller as dynamic).toggleBookmark(sura);
                            } catch (_) {}
                          }
                        },
                      ),
                      const SizedBox(width: 12),
                      Text(
                        sura['name_ar'] ?? '',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: brandGreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isThisSurahPlaying ? brandGreen : headerColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: brandGreen.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'Sura #${sura['id']}',
                      style: TextStyle(
                        color: isThisSurahPlaying ? Colors.white : brandGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
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

  String toBanglaNumber(String englishNumber) {
    const englishToBangla = {
      '0': '০', '1': '১', '2': '২', '3': '৩', '4': '৪',
      '5': '৫', '6': '৬', '7': '৭', '8': '৮', '9': '৯',
    };
    return englishNumber.split('').map((char) => englishToBangla[char] ?? char).join();
  }

  Widget _buildEmptyState(DashboardController controller) {
    const brandGreen = Color(0xFF006B3C);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
          const SizedBox(height: 10),
          const Text('তথ্য পাওয়া যায়নি', style: TextStyle(color: Colors.grey)),
          TextButton(
            onPressed: () => controller.fetchSura(),
            child: const Text('পুনরায় চেষ্টা করুন', style: TextStyle(color: brandGreen)),
          ),
        ],
      ),
    );
  }
}