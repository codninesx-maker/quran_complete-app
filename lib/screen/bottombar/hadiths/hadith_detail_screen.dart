import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:quran_complete/screen/dashboard_logic.dart';

class HadithDetailScreen extends StatefulWidget {
  const HadithDetailScreen({super.key});

  @override
  State<HadithDetailScreen> createState() => _HadithDetailScreenState();
}

class _HadithDetailScreenState extends State<HadithDetailScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    // Using read here as it's a one-time setup
    final controller = context.read<DashboardController>();
    _pageController = PageController(initialPage: controller.currentHadithIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handleCopy(Map<String, dynamic> hadith) {
    // Ensure we handle potential nulls safely
    final String content =
        "${hadith['book_name'] ?? 'হাদিস'}\n"
        "হাদিস নম্বর: ${hadith['hadith_number'] ?? ''}\n\n"
        "${hadith['text'] ?? ''}";

    Clipboard.setData(ClipboardData(text: content)).then((_) {
      // 1. Physical confirmation (Premium Feel)
      HapticFeedback.lightImpact();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DashboardController>();
    const brandGreen = Color(0xFF006B3C);
    const headerColor = Color(0xFFD0E8D8);

    return PageView.builder(
      controller: _pageController,
      itemCount: controller.hadiths.length,
      onPageChanged: (index) {
        controller.updateSelectedHadithByIndex(index);
      },
      itemBuilder: (context, index) {
        final hadith = controller.hadiths[index];

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Meta Data Tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: headerColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  hadith['book_name'] ?? 'Hadith',
                  style: const TextStyle(
                    color: brandGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 25),

              // --- FIXED GESTURE DETECTOR ---
              GestureDetector(
                // behavior: opaque ensures the whole area captures the tap
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  debugPrint("Tapped to copy!"); // For your console
                  _handleCopy(hadith);
                },
                child: Text(
                  hadith['text'] ?? '',
                  style: const TextStyle(
                    fontSize: 19,
                    height: 1.6,
                    color: Colors.black87,
                    letterSpacing: 0.2,
                  ),
                ),
              ),

              const SizedBox(height: 50),

              // Simple Instruction with InkWell for a second copy option
              Center(
                child: InkWell(
                  onTap: () => _handleCopy(hadith),
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Tap text to copy',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 120),
            ],
          ),
        );
      },
    );
  }
}