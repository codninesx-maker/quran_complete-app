import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:quran_complete/screen/dashboard_logic.dart';

class AllahScreen extends StatelessWidget {
  const AllahScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DashboardController>();
    final names = controller.names99;
    const brandGreen = Color(0xFF006B3C);

    if (controller.isLoading && names.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: brandGreen),
      );
    }

    if (names.isEmpty && !controller.isLoading) {
      return _buildEmptyState(controller);
    }

    return RefreshIndicator(
      onRefresh: () => controller.fetch99Names(),
      color: brandGreen,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 30),
        itemCount: names.length,
        itemBuilder: (context, index) {
          final name = names[index];

          return Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade100, width: 1),
            ),
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              // This handles the copy logic for the WHOLE card
              onTap: () => _copyToClipboard(context, name),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name['name_english'] ?? 'N/A',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            name['name_bangla'] ?? '',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                          ),
                          Text(
                            name['meaning_bangla'] ?? '',
                            style: const TextStyle(
                              fontSize: 12,
                              color: brandGreen,
                              fontStyle: FontStyle.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          name['name_arabic'] ?? '',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: brandGreen,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '#${name['name_number']}',
                          style: const TextStyle(
                            color: brandGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Improved Clipboard Helper
  void _copyToClipboard(BuildContext context, Map<String, dynamic> name) {
    // Formats the entire card content into one string
    final String copyText = "Name: ${name['name_english']}\n"
        "Arabic: ${name['name_arabic']}\n"
        "Bangla: ${name['name_bangla']}\n"
        "Meaning: ${name['meaning_bangla']}";

    Clipboard.setData(ClipboardData(text: copyText));
  }

  Widget _buildEmptyState(DashboardController controller) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No internet and no data found'),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => controller.fetch99Names(),
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF006B3C)),
          ),
        ],
      ),
    );
  }
}