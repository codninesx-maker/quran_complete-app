import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class QuranVideoPlayerScreen extends StatefulWidget {
  const QuranVideoPlayerScreen({Key? key}) : super(key: key);

  @override
  State<QuranVideoPlayerScreen> createState() => _QuranVideoPlayerScreenState();
}

class _QuranVideoPlayerScreenState extends State<QuranVideoPlayerScreen> {
  Player? _player;
  VideoController? _controller;
  bool _isInitialized = false;

  final String _fallbackDirectUrl = "https://archive.org/download/quran-video-hd-mishary-alayou-rashed/067.mp4";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupPlayerPipeline();
    });
  }

  Future<void> _setupPlayerPipeline() async {
    try {
      if (_player != null) {
        await _player!.dispose();
      }

      final playerInstance = Player();

      // ✅ CRITICAL FIX: Direct GPU Decoding fallback configuration for MediaTek hardware profiles
      if (playerInstance.platform is NativePlayer) {
        final nativePlayer = playerInstance.platform as NativePlayer;
        await nativePlayer.setProperty('hwdec', 'mediacodec');
        await nativePlayer.setProperty('cache', 'yes');
        await nativePlayer.setProperty('demuxer-max-bytes', '24000000');
      }

      final controllerInstance = VideoController(
        playerInstance,
        configuration: const VideoControllerConfiguration(
          enableHardwareAcceleration: true,
        ),
      );

      if (!mounted) return;

      setState(() {
        _player = playerInstance;
        _controller = controllerInstance;
        _isInitialized = true;
      });

      debugPrint("🎬 Opening stable direct Quran video stream...");

      // Delay initialization window processing to protect hardware layouts
      await Future.delayed(const Duration(milliseconds: 300));

      await _player!.open(
        Media(
          _fallbackDirectUrl,
          httpHeaders: {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 13; TECNO KM7)',
          },
        ),
        play: true,
      );
      debugPrint("🚀 Streaming direct video frame nodes successfully!");

    } catch (e) {
      debugPrint("❌ Playback Setup Pipeline Error: $e");
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = const Color(0xFF006437);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: themeColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Quran Video Stream',
          style: TextStyle(color: themeColor, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Now Playing Stream",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 4,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                color: Colors.black,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: (_isInitialized && _controller != null)
                      ? Video(
                    controller: _controller!,
                    controls: AdaptiveVideoControls,
                  )
                      : Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Surah Al-Mulk - Mishary Rashid Alafasy",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}