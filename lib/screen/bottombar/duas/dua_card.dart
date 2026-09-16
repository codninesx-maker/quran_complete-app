import 'package:flutter/material.dart';

class DuaCard extends StatelessWidget {
  final Map<String, dynamic> dua;
  final int serialNumber;
  final VoidCallback onTap; // Add this

  const DuaCard({
    super.key,
    required this.dua,
    required this.serialNumber,
    required this.onTap, // Add this
  });

  @override
  Widget build(BuildContext context) {
    const Color brandGreen = Color(0xFF006B3C);
    const Color headerColor = Color(0xFFD0E8D8);

    return InkWell(
      onTap: onTap, // Triggers the state change in DuasScreen
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: headerColor,
            child: Text(
              '$serialNumber',
              style: const TextStyle(
                color: brandGreen,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            dua['arabic_text'] ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          subtitle: Text(
            dua['translation_bn'] ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ),
      ),
    );
  }
}