import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:quran_complete/screen/dashboard_logic.dart';

class DuaDetailScreen extends StatelessWidget {
  const DuaDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<DashboardController>(context);
    final dua = controller.selectedDuaDetail;

    const Color brandGreen = Color(0xFF006B3C);
    const Color headerColor = Color(0xFFD0E8D8);

    if (dua == null) {
      return const Center(child: CircularProgressIndicator(color: brandGreen));
    }

    return RawScrollbar(
      thumbColor: brandGreen.withOpacity(0.2),
      radius: const Radius.circular(20),
      thickness: 5,
      child: SingleChildScrollView(
        primary: false,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24), // Increased horizontal for gutter
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Category Tag
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: headerColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  dua['category_name'] ?? 'দোয়া',
                  style: const TextStyle(
                    color: brandGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- ARABIC TEXT (Tap this to copy) ---
            InkWell(
              onTap: () => _copyToClipboard(context, dua),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  dua['arabic_text'] ?? '',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 28, // Slightly larger for better Arabic reading
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    height: 1.8,
                  ),
                ),
              ),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Divider(color: Color(0xFFEEEEEE), thickness: 1),
            ),

            // Pronunciation Section
            _buildSectionTitle('উচ্চারণ:', brandGreen),
            const SizedBox(height: 8),
            SelectableText(
              dua['pronunciation_bn'] ?? '',
              style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
            ),

            const SizedBox(height: 24),

            // Meaning Section
            _buildSectionTitle('অর্থ:', brandGreen),
            const SizedBox(height: 8),
            SelectableText(
              dua['translation_bn'] ?? '',
              style: const TextStyle(fontSize: 17, height: 1.6, color: Colors.black87),
            ),

            const SizedBox(height: 32),

            // Minimalist Copy Indicator
            Center(
              child: InkWell(
                onTap: () => _copyToClipboard(context, dua),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.copy_rounded, size: 14, color: brandGreen),
                      const SizedBox(width: 8),
                      Text(
                        'সম্পূর্ণ দোয়াটি কপি করুন',
                        style: TextStyle(
                          color: brandGreen.withOpacity(0.8),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Text(
      title,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.bold,
        fontSize: 13,
      ),
    );
  }

  void _copyToClipboard(BuildContext context, Map<String, dynamic> dua) {
    // FIXED: Use the correct keys matching your Dua data
    final String copyText = "আরবি: ${dua['arabic_text']}\n"
        "উচ্চারণ: ${dua['pronunciation_bn']}\n"
        "অর্থ: ${dua['translation_bn']}";

    Clipboard.setData(ClipboardData(text: copyText)).then((_) {
      // Physical feedback (Premium feel)
      HapticFeedback.lightImpact();
    });
  }
}