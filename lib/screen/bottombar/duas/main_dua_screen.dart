import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:quran_complete/screen/bottombar/duas/dua-detail_screen.dart';
import 'package:quran_complete/screen/dashboard_logic.dart';
import 'dua_card.dart';



class DuasScreen extends StatelessWidget {
  const DuasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DashboardController>();
    const Color brandGreen = Color(0xFF006B3C);
    const Color headerColor = Color(0xFFD0E8D8);

    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator(color: brandGreen));
    }

    // 1. Show Detail View
    if (controller.selectedDuaDetail != null) {
      // FIX: Remove (dua: controller.selectedDuaDetail!)
      return const DuaDetailScreen();
    }

    // 2. Show List View
    if (controller.selectedDuaCategory != null) {
      final categoryDuas = controller.getDuasByCategory(controller.selectedDuaCategory!);
      return ListView.builder(
        itemCount: categoryDuas.length,
        itemBuilder: (context, index) => DuaCard(
          dua: categoryDuas[index],
          serialNumber: index + 1,
          onTap: () => controller.selectDua(categoryDuas[index]),
        ),
      );
    }

    // 3. Show Grid View
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 20, mainAxisSpacing: 20, childAspectRatio: 1.1,
      ),
      itemCount: controller.duaCategories.length,
      itemBuilder: (context, index) {
        final category = controller.duaCategories[index];
        return InkWell(
          onTap: () => controller.selectCategory(category),
          child: _buildCategoryCard(category, index + 1, headerColor, brandGreen),
        );
      },
    );
  }

  Widget _buildCategoryCard(String title, int index, Color bg, Color text) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(backgroundColor: bg, radius: 25,
              child: Text('$index', style: TextStyle(color: text, fontWeight: FontWeight.bold))),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}