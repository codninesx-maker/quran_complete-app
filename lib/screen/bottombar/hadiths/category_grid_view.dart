import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quran_complete/screen/dashboard_logic.dart';

class CategoryGridView extends StatelessWidget {
  const CategoryGridView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DashboardController>();
    const brandGreen = Color(0xFF006B3C);
    const headerColor = Color(0xFFD0E8D8);

    // No Scaffold or AppBar here.
    return controller.isLoading
        ? const Center(child: CircularProgressIndicator(color: brandGreen))
        : Column(
      children: [
        if (controller.errorMessage != null)
          Container(
            width: double.infinity,
            color: Colors.orange.shade50,
            padding: const EdgeInsets.all(10),
            child: Text(
              controller.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ),
        Expanded(
          child: controller.hadiths.isEmpty
              ? _buildEmptyState(brandGreen, controller)
              : RawScrollbar(
            thumbColor: brandGreen.withOpacity(0.3),
            radius: const Radius.circular(20),
            thickness: 6,
            thumbVisibility: true,
            interactive: true,
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: controller.hadiths.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = controller.hadiths[index];
                return ListTile(
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: headerColor,
                    child: Text(
                      '${item['hadith_number']}',
                      style: const TextStyle(
                          color: brandGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    item['text'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                  subtitle: Text(item['book_name'] ?? 'হাদিস গ্রন্থ'),
                  onTap: () {
                    // SINGLE SOURCE OF TRUTH: Update state instead of Navigator.push
                    controller.selectHadith(item);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(Color brandGreen, DashboardController controller) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('কোন তথ্য পাওয়া যায়নি'),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: brandGreen),
            onPressed: () {
              // Refresh logic using controller
              controller.fetchHadiths();
            },
            child: const Text('আবার চেষ্টা করুন', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }
}