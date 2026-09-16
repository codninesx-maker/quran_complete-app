import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quran_complete/screen/dashboard_logic.dart';

class MainHadithScreen extends StatefulWidget {
  const MainHadithScreen({super.key});

  @override
  State<MainHadithScreen> createState() => _HadithsScreenState();
}

class _HadithsScreenState extends State<MainHadithScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Logic for Infinite Scroll / Pagination
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        context.read<DashboardController>().fetchHadiths(isInitial: false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DashboardController>();
    const brandGreen = Color(0xFF006B3C);

    // Generate 16 groups
    final int totalGroups = 16;
    final int itemsPerGroup = 451;

    return GridView.builder(
      padding: const EdgeInsets.all(30),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.3,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: totalGroups,
      itemBuilder: (context, index) {
        final int groupNumber = index + 1;
        final int startRange = (index * itemsPerGroup) + 1;
        // Handle the last group slightly differently to catch the remaining 9 items
        final int endRange = (groupNumber == totalGroups) ? 7225 : (groupNumber * itemsPerGroup);

        return Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: InkWell(
            onTap: () {
              final String title = 'খণ্ড $groupNumber ($startRange - $endRange)';

              // This triggers the 'Dispatcher' above to rebuild and show CategoryGridView
              controller.selectHadithCategory(title, startRange, endRange);
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: brandGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$groupNumber',
                    style: const TextStyle(color: brandGreen, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('হাদিস খণ্ড', style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text(
                  '$startRange - $endRange',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

