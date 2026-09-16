import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:quran_complete/screen/bottombar/hadiths/quran/archive/archive_audio-helper.dart';
import 'package:quran_complete/screen/bottombar/hadiths/quran/audio_controller.dart';

class ArchiveAlafasiBanglaScreen extends StatelessWidget {
  const ArchiveAlafasiBanglaScreen({Key? key}) : super(key: key);

  static const List<String> _banglaSurahNames = [
    "আল ফাতিহা", "আল বাকারা", "আলি ইমরান", "আন নিসা", "আল মায়িদাহ", "আল আনআম",
    "আল আরাফ", "আল আনফাল", "আত তাওবাহ", "ইউনুস", "হূদ", "ইউসুফ",
    "আর রা'দ", "ইব্রাহীম", "আল হিজর", "আন নাহল", "আল ইসরা", "আল কাহফ",
    "মারিয়াম", "ত্বোয়া-হা", "আল আম্বিয়া", "আল হাজ্জ", "আল মু'মিনুন", "আন নূর",
    "আল ফুরকান", "আশ শুআরা", "আন নামল", "আল কাসাস", "আল আনকাবুত", "আর রূম",
    "লুকমান", "আস সাজদাহ", "আল আহজাব", "সাবা", "ফাতির", "ইয়াসীন",
    "আস ছাফফাত", "সোয়াদ", "আজ জুমার", "গাফির", "ফুসসিলাত", "আশ শূরা",
    "আজ জুখরুফ", "আদ দুখান", "আল جাসিয়াহ", "আল আহকাফ", "মুহাম্মদ", "আল ফাতহ",
    "আল হুজুরাত", "কাফ", "আয যারিয়াত", "আত তূর", "আন নাজম", "আল কামার",
    "আর রাহমান", "আল ওয়াকিয়াহ", "আল হাদীদ", "আল মুজাদালাহ", "আল হাশর", "আল মুমতাহানাহ",
    "আস ছফ", "আল জুমুআহ", "আল মুনাফিকুন", "আত তাগাবুন", "আত ত্বালাক", "আত তাহরীম",
    "আল মুলক", "আল কলাম", "আল হাক্কাহ", "আল মাআরিজ", "নূহ", "আল জীন",
    "আল মুযযাম্মিল", "আল মুদ্দাসসির", "আল কিয়ামাহ", "আল ইনসান", "আল মুরসালাত", "আন নাবা",
    "আন নাযিআত", "আবাসা", "আত তাকবীর", "আল ইনফিতার", "আল মুত্বাফফিফীন", "আল ইনশিকাক",
    "আল বুরুজ", "আত্ব ত্বারিক", "আল আ'লা", "আল গাশিয়াহ", "আল ফাজর", "আল বালাদ",
    "আশ শামস", "আল লাইল", "আদ দুহা", "আশ শারহ", "আত তীন", "আল আলাক",
    "আল কদর", "আল বাইয়্যিনাহ", "আয যিলযাল", "আল আদিয়াত", "আল কারিয়াহ", "আত তাকাসুর",
    "আল আছর", "আল হুমাযাহ", "আল ফীল", "কুরাইশ", "আল মাউন", "আল কাওসার",
    "আল কাফিরুন", "আন নাসর", "আল লাহাব", "আল ইখলাস", "আল ফালাক", "আন নাস"
  ];

  @override
  Widget build(BuildContext context) {
    final brandHeaderColor = const Color(0xFFD0E8D8);
    final brandIconColor = const Color(0xFF006B3C);
    final activeRowHighlight = const Color(0xFF006437);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: brandHeaderColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Alafasy (With Bangla Translation)',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share_outlined, color: brandIconColor),
            onPressed: () {},
          ),
        ],
      ),
      body: Consumer<AudioController>(
        builder: (context, audioController, child) {
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            itemCount: 114,
            itemBuilder: (context, index) {
              final int surahId = index + 1;
              final String rawFileName = ArchiveAudioHelper.getSynthesizedFileName(surahId);

              final String displayTitle = _banglaSurahNames[index];
              final String displaySubtitle = _extractCleanSubtitle(rawFileName);

              final String trackUrl = ArchiveAudioHelper.getStreamingUrl(surahId);
              final bool isCurrentTrack = audioController.currentManualUrl == trackUrl;
              final bool isActivePlaying = isCurrentTrack && audioController.isPlaying;

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: isCurrentTrack ? activeRowHighlight.withOpacity(0.08) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCurrentTrack ? activeRowHighlight.withOpacity(0.3) : Colors.grey.withOpacity(0.15),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: isCurrentTrack ? activeRowHighlight : activeRowHighlight.withOpacity(0.08),
                    child: Text(
                      surahId.toString(),
                      style: TextStyle(
                        color: isCurrentTrack ? Colors.white : activeRowHighlight,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  title: Text(
                    displayTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isCurrentTrack ? activeRowHighlight : Colors.black87,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      displaySubtitle,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ),
                  trailing: _buildInlineRowControls(
                    audioController: audioController,
                    trackUrl: trackUrl,
                    isCurrentTrack: isCurrentTrack,
                    isActivePlaying: isActivePlaying,
                    themeColor: activeRowHighlight,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _extractCleanSubtitle(String filename) {
    if (filename.isEmpty) return "Mishary Rashid Al-Afasy";
    try {
      if (filename.contains('(') && filename.contains(')')) {
        int start = filename.indexOf('(') + 1;
        int end = filename.indexOf(')');
        return "English: ${filename.substring(start, end).trim()}";
      }
    } catch (_) {}
    return "Mishary Rashid Al-Afasy";
  }

  Widget _buildInlineRowControls({
    required AudioController audioController,
    required String trackUrl,
    required bool isCurrentTrack,
    required bool isActivePlaying,
    required Color themeColor,
  }) {
    if (!isCurrentTrack) {
      return IconButton(
        icon: Icon(Icons.play_circle_filled, size: 36, color: Colors.grey[600]),
        onPressed: () {
          audioController.resetLoadingStates();
          audioController.playDirectUrl(trackUrl);
        },
      );
    }

    if (audioController.isBuffering) {
      return Container(
        margin: const EdgeInsets.only(right: 8),
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(themeColor),
        ),
      );
    }

    // Removed 'const' from BoxConstraints to fix the "Invalid constant value" compiler rule
    final currentPos = audioController.currentPosition;
    final totalDuration = audioController.totalDuration ?? Duration.zero;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          constraints: BoxConstraints(), // Fixed constant constraint error here
          padding: const EdgeInsets.symmetric(horizontal: 4),
          icon: const Icon(Icons.replay_10, size: 24, color: Colors.black54), // Fixed black70 error here
          onPressed: () {
            final target = currentPos - const Duration(seconds: 10);
            audioController.seek(target < Duration.zero ? Duration.zero : target);
          },
        ),
        IconButton(
          constraints: BoxConstraints(), // Fixed constant constraint error here
          padding: const EdgeInsets.symmetric(horizontal: 4),
          icon: Icon(
            isActivePlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
            size: 36,
            color: themeColor,
          ),
          onPressed: () => audioController.togglePlay(),
        ),
        IconButton(
          constraints: BoxConstraints(), // Fixed constant constraint error here
          padding: const EdgeInsets.symmetric(horizontal: 4),
          icon: const Icon(Icons.forward_10, size: 24, color: Colors.black54), // Fixed black70 error here
          onPressed: () {
            final target = currentPos + const Duration(seconds: 10);
            audioController.seek(target > totalDuration ? totalDuration : target);
          },
        ),
      ],
    );
  }
}