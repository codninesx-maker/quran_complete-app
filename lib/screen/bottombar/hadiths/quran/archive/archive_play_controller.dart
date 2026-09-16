import 'package:flutter/material.dart';
import 'package:quran_complete/screen/bottombar/hadiths/quran/audio_controller.dart';

Widget _buildInlineRowControls({
  required AudioController audioController,
  required String trackUrl,
  required Color themeColor,
}) {
  return ListenableBuilder(
    listenable: audioController,
    builder: (context, child) {
      final bool isCurrentTrack = audioController.currentManualUrl == trackUrl;
      final bool isThisRowLoading = audioController.loadingUrl == trackUrl;
      final bool isEnginePlaying = audioController.isPlaying;

      // 1. Show progress indicator if the track is network caching or buffering
      if (isThisRowLoading || (isCurrentTrack && audioController.isBuffering)) {
        return Container(
          margin: const EdgeInsets.only(right: 8),
          width: 28,
          height: 28,
          alignment: Alignment.center,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(themeColor),
          ),
        );
      }

      // 2. UNSELECTED TRACK STATE: Render standard play button
      if (!isCurrentTrack) {
        return IconButton(
          icon: Icon(Icons.play_circle_filled, size: 36, color: Colors.grey[600]),
          onPressed: () {
            if (audioController.loadingUrl == null) {
              audioController.playDirectUrl(trackUrl);
            }
          },
        );
      }

      // 3. ESTABLISHED TRACK STATE: Read the latest ticks directly via ListenableBuilder
      final currentPos = audioController.currentPosition;
      final totalDuration = audioController.totalDuration ?? Duration.zero;

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 10s Rewind Button
          IconButton(
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            icon: const Icon(Icons.replay_10, size: 24, color: Colors.black54),
            onPressed: () {
              final target = currentPos - const Duration(seconds: 10);
              audioController.seek(target < Duration.zero ? Duration.zero : target);
            },
          ),

          // Inline Play / Pause Toggle
          IconButton(
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            icon: Icon(
              isEnginePlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
              size: 36,
              color: themeColor,
            ),
            onPressed: () => audioController.togglePlay(),
          ),

          // 10s Forward Button
          IconButton(
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            icon: const Icon(Icons.forward_10, size: 24, color: Colors.black54),
            onPressed: () {
              final target = currentPos + const Duration(seconds: 10);
              audioController.seek(target > totalDuration ? totalDuration : target);
            },
          ),
        ],
      );
    },
  );
}