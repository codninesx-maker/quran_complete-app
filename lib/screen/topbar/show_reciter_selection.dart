import 'package:flutter/material.dart';
import 'package:quran_complete/screen/dashboard_logic.dart';

class ReciterDialog {
  /// Displays the Reciter Selection Dialog.
  /// Needs [context], the [controller] for state, and the current [index] to restart playback.
  static void show(
      BuildContext context,
      DashboardController controller,
      int index,
      ) {
    if (controller.reciters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("লোড হচ্ছে... একটু অপেক্ষা করুন"),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text(
            "কারী নির্বাচন করুন",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: controller.reciters.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final reciter = controller.reciters[i];
                final isSelected = controller.selectedReciter?['id'] == reciter['id'];

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0x1A006B3C),
                    child: Icon(Icons.person, color: Color(0xFF006B3C)),
                  ),
                  title: Text(
                    reciter['name_bn'],
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    reciter['name_en'],
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Color(0xFF006B3C))
                      : const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  onTap: () async {
                    // If the user selects the same reciter, just close the dialog
                    if (isSelected) {
                      Navigator.pop(dialogContext);
                      return;
                    }

                    // 1. Close the dialog immediately
                    Navigator.pop(dialogContext);

                    // 2. Update state and start audio
                    // By not awaiting these before Navigator.pop, the UI remains responsive
                    try {
                      await controller.setReciter(reciter);

                      // We call this without awaiting if we want the UI to be free,
                      // but since we are already outside the dialog, it's safe now.
                      await controller.playAyaAudio(index);
                    } catch (e) {
                      debugPrint("Selection Error: $e");
                    }
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}