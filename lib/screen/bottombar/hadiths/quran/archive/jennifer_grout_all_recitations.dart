import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class JenniferGroutAllRecitationsScreen extends StatefulWidget {
  const JenniferGroutAllRecitationsScreen({Key? key}) : super(key: key);

  @override
  State<JenniferGroutAllRecitationsScreen> createState() => _JenniferGroutAllRecitationsScreenState();
}

class _JenniferGroutAllRecitationsScreenState extends State<JenniferGroutAllRecitationsScreen> {
  int? _currentlyPlayingIndex;
  String? _activeVideoUrl;
  bool _isProcessingClick = false;

  final List<Map<String, String>> _recitations = [
    {
      'surahNo': '1',
      'title': 'Surah Al-Fatiha',
      'subtitle': 'সূরা আল-ফাতিহা',
      'duration': '2:15',
      'url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
    },
    {
      'surahNo': '2',
      'title': 'Surah Al-Baqarah (Ayatul Kursi)',
      'subtitle': 'সূরা আল-বাকারাহ (আয়ানুল কুরসী)',
      'duration': '3:45',
      'url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
    },
    {
      'surahNo': '55',
      'title': 'Surah Ar-Rahman',
      'subtitle': 'সূরা আর-রহমান',
      'duration': '12:30',
      'url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
    },
  ];

  void _handlePlayRecitation(int index, String videoUrl) {
    if (_isProcessingClick) return;

    if (_currentlyPlayingIndex == index) {
      setState(() {
        _isProcessingClick = true;
      });
      _cleanupPlayer();
      setState(() {
        _isProcessingClick = false;
      });
    } else {
      setState(() {
        _isProcessingClick = true;
        _currentlyPlayingIndex = index;
        _activeVideoUrl = videoUrl;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isProcessingClick = false;
          });
        }
      });
    }
  }

  void _cleanupPlayer() {
    setState(() {
      _currentlyPlayingIndex = null;
      _activeVideoUrl = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = Color(0xFF006437);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        title: const Text(
          'Jennifer Grout Recitations',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
        ),
        backgroundColor: themeColor,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          if (_activeVideoUrl != null && _currentlyPlayingIndex != null)
            IsolatedVideoViewport(
              key: ValueKey('isolated_surface_${_currentlyPlayingIndex}_$_activeVideoUrl'),
              videoUrl: _activeVideoUrl!,
              onClose: _cleanupPlayer,
            ),
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              itemCount: _recitations.length,
              itemBuilder: (context, index) {
                final item = _recitations[index];
                final isItemActive = _currentlyPlayingIndex == index;

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isItemActive ? themeColor.withOpacity(0.06) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isItemActive ? themeColor : Colors.grey.withOpacity(0.15),
                      width: isItemActive ? 1.5 : 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    onTap: () => _handlePlayRecitation(index, item['url']!),
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: isItemActive ? themeColor : themeColor.withOpacity(0.08),
                      child: isItemActive
                          ? const Icon(Icons.graphic_eq, color: Colors.white, size: 18)
                          : Text(item['surahNo']!, style: const TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    title: Text(
                      item['title']!,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isItemActive ? themeColor : Colors.black87),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(item['subtitle']!, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ),
                    trailing: Icon(
                      isItemActive ? Icons.pause_circle_filled : Icons.play_circle_fill,
                      color: themeColor,
                      size: 28,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class IsolatedVideoViewport extends StatefulWidget {
  final String videoUrl;
  final VoidCallback onClose;

  const IsolatedVideoViewport({
    Key? key,
    required this.videoUrl,
    required this.onClose,
  }) : super(key: key);

  @override
  State<IsolatedVideoViewport> createState() => _IsolatedVideoViewportState();
}

class _IsolatedVideoViewportState extends State<IsolatedVideoViewport> {
  // Use late initialization to guarantee object creation synchronization
  late final Player _player;
  late final VideoController _videoController;

  bool _isPlayerInitialized = false;
  bool _isBuffering = false;

  @override
  void initState() {
    super.initState();
    _initializeIsolatedPlayer();
  }

  void _initializeIsolatedPlayer() {
    try {
      // 1. Instantly allocate players synchronously on init to match widget layout attachment
      _player = Player();

      // Configure mpv parameters before attaching the controller layout
      if (_player.platform is NativePlayer) {
        final nativePlayer = _player.platform as NativePlayer;
        nativePlayer.setProperty('hwdec', 'mediacodec'); // Use Android system codecs
        nativePlayer.setProperty('cache', 'yes');
        nativePlayer.setProperty('demuxer-max-bytes', '16000000');
      }

      // 2. Build the controller mapping right away
      _videoController = VideoController(
        _player,
        configuration: const VideoControllerConfiguration(
          enableHardwareAcceleration: true,
        ),
      );

      // Listen for buffering updates
      _player.stream.buffering.listen((bufferingState) {
        if (mounted) {
          setState(() {
            _isBuffering = bufferingState;
          });
        }
      });

      setState(() {
        _isPlayerInitialized = true;
      });

      // 3. Queue the video file stream immediately after properties match up
      _player.open(
        Media(
          widget.videoUrl,
          httpHeaders: {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 13; TECNO KM7)',
          },
        ),
        play: true,
      );
    } catch (e) {
      debugPrint("❌ Isolated Frame Recovery Guard Caught: $e");
    }
  }

  @override
  void dispose() {
    // Synchronously stop stream processing before sending memory release to native C layers
    _player.stop().then((_) {
      _player.dispose();
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fix layout viewport dimensions cleanly
    final double defaultWidth = MediaQuery.of(context).size.width;
    final double calculatedHeight = defaultWidth * 9 / 16;

    return Container(
      color: Colors.black,
      width: defaultWidth,
      height: calculatedHeight,
      child: Stack(
        children: [
          // If player layout is built, render the view frame inside a forced AspectRatio
          if (_isPlayerInitialized)
            Positioned.fill(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Video(
                  controller: _videoController,
                  controls: AdaptiveVideoControls,
                ),
              ),
            )
          else
            const SizedBox.expand(),

          // Overlay loader if initial loading holds, or if network buffer happens
          if (!_isPlayerInitialized || _isBuffering)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),

          // Dismiss Button
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 22),
              style: IconButton.styleFrom(backgroundColor: Colors.black54),
              onPressed: widget.onClose,
            ),
          ),
        ],
      ),
    );
  }
}