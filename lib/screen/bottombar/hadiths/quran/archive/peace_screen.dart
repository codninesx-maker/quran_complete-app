import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:quran_complete/externalads/ad_helper.dart';
import 'package:quran_complete/screen/bottombar/hadiths/quran/archive/archive_afasi_bangla_Screen.dart';

class PeaceScreen extends StatefulWidget {
  const PeaceScreen({Key? key}) : super(key: key);

  @override
  State<PeaceScreen> createState() => _PeaceScreenState();
}

class _PeaceScreenState extends State<PeaceScreen> {
  Player? _player;
  VideoController? _videoController;
  bool _isVideoPlaying = false;
  bool _isBuffering = false;

  // 3️⃣ Interstitial Ad state variables
  InterstitialAd? _returnInterstitialAd;
  bool _isAdLoaded = false;

  // Global direct static file link
  final String _videoUrl =
      "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4";

  Future<void> _toggleInlineVideo() async {
    if (_isVideoPlaying) {
      final oldPlayer = _player;
      setState(() {
        _isVideoPlaying = false;
        _isBuffering = false;
        _player = null;
        _videoController = null;
      });
      await oldPlayer?.dispose();
    } else {
      // 1️⃣ ALWAYS allocate native instances synchronously to prevent 1x1 structural collapse
      final playerInstance = Player();

      if (playerInstance.platform is NativePlayer) {
        final nativePlayer = playerInstance.platform as NativePlayer;
        // Use synchronous property setups tailored for MediaTek / Transsion SoC layers
        nativePlayer.setProperty('hwdec', 'mediacodec');
        nativePlayer.setProperty('vd-lavc-dr', 'no');
        nativePlayer.setProperty('video-unscaled', 'no');
        nativePlayer.setProperty('cache', 'yes');
        nativePlayer.setProperty('demuxer-max-bytes', '16000000');
        nativePlayer.setProperty('demuxer-readahead-secs', '20');
      }

      // 🔑 FIXED: Removed 'androidScaleVideo' parameter cleanly
      final controllerInstance = VideoController(
        playerInstance,
        configuration: const VideoControllerConfiguration(
          enableHardwareAcceleration: true,
        ),
      );

      // Listen for buffering changes
      playerInstance.stream.buffering.listen((bufferingState) {
        if (mounted) {
          setState(() {
            _isBuffering = bufferingState;
          });
        }
      });

      // Assign everything to the state simultaneously
      setState(() {
        _isVideoPlaying = true;
        _isBuffering = true;
        _player = playerInstance;
        _videoController = controllerInstance;
      });

      // 🚀 ADD THIS 300ms PAUSE: Let the device surface finish attaching
      // completely before trying to run native streaming logic.
      await Future.delayed(const Duration(milliseconds: 300));

      try {
        await playerInstance.open(
          Media(
            _videoUrl,
            httpHeaders: {
              'User-Agent': 'Mozilla/5.0 (Linux; Android 13; TECNO KM7)',
            },
          ),
          play: true,
        ).timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw Exception("Streaming server request timeout"),
        );
      } catch (e) {
        debugPrint("❌ Resilient Inline Player Catch: $e");
        await playerInstance.dispose();

        if (!mounted) return;
        setState(() {
          _isVideoPlaying = false;
          _isBuffering = false;
          _player = null;
          _videoController = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    _returnInterstitialAd?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadReturnAd();
    // Move database reads away from the UI assembly point
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        // Call your Duas / Names / Hadiths fetch functions here
        // instead of running them on raw app startup
      });
    });
  }

  // 5️⃣ Load Interstitial Ad method
  void _loadReturnAd() {
    InterstitialAd.load(
      adUnitId: AdHelper.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _returnInterstitialAd = ad;
          _isAdLoaded = true;

          // Clear references and reload when the ad is dismissed or fails
          _returnInterstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _loadReturnAd(); // Reload for the next visit
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _loadReturnAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('❌ Return Interstitial Ad failed to load: ${error.message}');
          _isAdLoaded = false;
        },
      ),
    );
  }

  // 6️⃣ Helper method to show ad safely
  void _showAdIfReady() {
    if (_isAdLoaded && _returnInterstitialAd != null) {
      _returnInterstitialAd!.show();
      _isAdLoaded = false; // Reset local flag state immediately
    } else {
      debugPrint('⚠️ Interstitial Ad was not fully loaded yet when returning.');
    }
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = Color(0xFF006437);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildReciterCard(
              context: context,
              index: 1,
              title: 'Mishary Alafasi (Bangla)',
              subtitle: 'মিশারি রাশিদ আল-আফাসী (বাংলা অনুবাদসহ)',
              icon: Icons.g_translate,
              accentColor: themeColor,
              onTap: () async {
                // 8️⃣ Await the navigation route to finish completely
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ArchiveAlafasiBanglaScreen(),
                  ),
                );

                // 9️⃣ Execution point: The user popped back to this screen
                _showAdIfReady();
              },
            ),
            /*
            _buildReciterCard(
              context: context,
              index: 2,
              title: 'Abdullah Matroud',
              subtitle: 'আব্দুল্লাহ মাতরুদ',
              icon: Icons.record_voice_over,
              accentColor: themeColor,
              onTap: () => debugPrint("Open Abdullah Matroud Screen"),
            ),
            _buildReciterCard(
              context: context,
              index: 3,
              title: 'Jennifer Grout',
              subtitle: 'জেনিফার গ্রাউট',
              icon: Icons.audiotrack,
              accentColor: themeColor,
              onTap: () async {
                // Force release the system audio focus from just_audio_background
                try {
                  final temporaryKillerPlayer = AudioPlayer();
                  await temporaryKillerPlayer.stop();
                  await temporaryKillerPlayer.dispose();
                } catch (e) {
                  debugPrint("Background audio track override log: $e");
                }

                await Future.delayed(const Duration(milliseconds: 150));

                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const JenniferGroutAllRecitationsScreen(),
                  ),
                );
              },
            ),
            _buildReciterCard(
              context: context,
              index: 4,
              title: 'Others',
              subtitle: 'অন্যান্য ক্বারীগণ',
              icon: Icons.more_horiz,
              accentColor: Colors.blueGrey[700]!,
              onTap: () => debugPrint("Open Others Reciters Screen"),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 24, bottom: 8, left: 4),
              child: Text(
                "Featured Video Streams",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            _buildInlineVideoCard(themeColor),*/
          ],
        ),
      ),
    );
  }

  Widget _buildInlineVideoCard(Color themeColor) {
    final double screenWidth = MediaQuery.of(context).size.width - 32;
    final double targetHeight = screenWidth * 9 / 16;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      width: screenWidth,
      height: targetHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.black,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: _isVideoPlaying
            ? LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth <= 1 || constraints.maxHeight <= 1) {
              return const SizedBox.shrink();
            }

            return Stack(
              children: [
                if (_videoController != null)
                  Positioned.fill(
                    child: Video(
                      controller: _videoController!,
                      controls: AdaptiveVideoControls,
                      fill: Colors.black,
                      alignment: Alignment.center,
                      fit: BoxFit.contain,
                    ),
                  ),
                if (_isBuffering)
                  Container(
                    color: Colors.black45,
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
              ],
            );
          },
        )
            : _buildPlaceholder(themeColor),
      ),
    );
  }

  Widget _buildPlaceholder(Color themeColor) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          color: themeColor.withValues(alpha: 0.1), // 🔑 FIXED: Upgraded code deprecation
          child: Center(
            child: Icon(
              Icons.spa_rounded,
              size: 64,
              color: themeColor.withValues(alpha: 0.5), // 🔑 FIXED: Upgraded code deprecation
            ),
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black54, Colors.black54],
            ),
          ),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.play_circle_fill_rounded, size: 56, color: Colors.white),
              onPressed: _toggleInlineVideo,
            ),
            const SizedBox(height: 8),
            const Text(
              'মানসিক প্রশান্তি ভিডিও প্লে করুন',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReciterCard({
    required BuildContext context,
    required int index,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)), // 🔑 FIXED: Upgraded code deprecation
        ],
      ),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.withValues(alpha: 0.12), width: 1), // 🔑 FIXED: Upgraded code deprecation
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: accentColor.withValues(alpha: 0.09), // 🔑 FIXED: Upgraded code deprecation
                  child: Text(
                    index.toString(),
                    style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(icon, color: accentColor.withValues(alpha: 0.7), size: 22), // 🔑 FIXED: Upgraded code deprecation
                const SizedBox(width: 12),
                Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}