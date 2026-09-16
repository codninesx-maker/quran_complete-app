import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:quran_complete/screen/bottombar/hadiths/quran/audio_controller.dart';
import 'package:quran_complete/screen/dashboard_logic.dart';

class AyaScreen extends StatefulWidget {
  final Map<String, dynamic> sura;

  const AyaScreen({super.key, required this.sura});

  @override
  State<AyaScreen> createState() => _AyaScreenState();
}

class _AyaScreenState extends State<AyaScreen> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();

  late DashboardController _controller;
  int _lastScrolledIndex = -1;

  // ✅ State tracking for our custom edge scrollbar tracker
  double _scrollbarTopOffset = 0.0;
  bool _isDragging = false;

  static const Color kBrandGreen = Color(0xFF006B3C);
  static const Color kHeaderLightGreen = Color(0xFFD0E8D8);

  @override
  void initState() {
    super.initState();
    _controller = context.read<DashboardController>();
    _controller.addListener(_onControllerUpdate);

    // ✅ Listen to list position shifts to move the scroll thumb dynamically as you scroll normally
    _itemPositionsListener.itemPositions.addListener(_updateScrollbarFromList);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.fetchAyas(widget.sura['id']);
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _itemPositionsListener.itemPositions.removeListener(_updateScrollbarFromList);
    super.dispose();
  }

  // ✅ Synchronizes thumb position on screen when list is scrolled manually
  void _updateScrollbarFromList() {
    if (_isDragging || _controller.ayas.isEmpty) return;
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isNotEmpty) {
      // Find the lowest visible index currently on viewport
      int minIndex = positions
          .map((position) => position.index)
          .reduce((min, index) => index < min ? index : min);

      double percentage = minIndex / _controller.ayas.length;
      if (mounted) {
        setState(() {
          _scrollbarTopOffset = percentage;
        });
      }
    }
  }

  // ✅ Translates vertical finger drags directly into instant list index jumps
  void _handleTrackDrag(double localVerticalPixels, double trackMaxHeight) {
    if (_controller.ayas.isEmpty || trackMaxHeight <= 0) return;

    double clampedPixels = localVerticalPixels.clamp(0.0, trackMaxHeight);
    double dragPercentage = clampedPixels / trackMaxHeight;

    setState(() {
      _scrollbarTopOffset = dragPercentage;
    });

    int targetIndex = (dragPercentage * _controller.ayas.length).floor();
    targetIndex = targetIndex.clamp(0, _controller.ayas.length - 1);

    if (_itemScrollController.isAttached) {
      _itemScrollController.jumpTo(index: targetIndex);
    }
  }

  void _onControllerUpdate() {
    if (!mounted) return;

    final audioController = _controller.audioController;
    final currentPlayingAyaId = audioController.currentAyaIndex;

    if (currentPlayingAyaId != -1) {
      final uiIndexToScroll = _controller.ayas.indexWhere((aya) {
        final id = aya['aya_id'] ?? aya['verse_id'];
        return int.tryParse(id.toString()) == currentPlayingAyaId;
      });

      if (uiIndexToScroll != -1 && uiIndexToScroll != _lastScrolledIndex) {
        _lastScrolledIndex = uiIndexToScroll;
        _scrollToIndex(uiIndexToScroll);
      }
    }
  }

  void _scrollToIndex(int index) {
    if (_itemScrollController.isAttached) {
      _itemScrollController.scrollTo(
        index: index,
        alignment: 0.1,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _copyToClipboard(BuildContext context, String arabic, String bangla) {
    HapticFeedback.mediumImpact();
    final textToCopy = "$arabic\n\n$bangla";
    Clipboard.setData(ClipboardData(text: textToCopy));
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DashboardController>();
    final ayas = controller.ayas;

    if (controller.isLoading) {
      return Container(
        color: const Color(0xFFF8FAF8),
        child: const Center(child: CircularProgressIndicator(color: kBrandGreen)),
      );
    }

    if (ayas.isEmpty) {
      return Container(
        color: const Color(0xFFF8FAF8),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.menu_book_rounded, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('কোনো আয়াত পাওয়া যায়নি', style: TextStyle(color: Colors.grey, fontSize: 16)),
              TextButton(
                onPressed: () => controller.fetchAyas(widget.sura['id']),
                child: const Text('পুনরায় চেষ্টা করুন', style: TextStyle(color: kBrandGreen)),
              )
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double screenHeight = constraints.maxHeight;
          const double thumbHeight = 60.0;
          final double trackMaxScrollHeight = screenHeight - thumbHeight;
          final double currentThumbTop = _scrollbarTopOffset * trackMaxScrollHeight;

          return Stack(
            children: [
              // 1. Core Scroll View Area (goes edge-to-edge for wide tracking)
              ScrollablePositionedList.builder(
                itemScrollController: _itemScrollController,
                itemPositionsListener: _itemPositionsListener,
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: ayas.length,
                itemBuilder: (context, index) {
                  final aya = ayas[index];
                  final rawId = aya['aya_id'] ?? aya['verse_id'];
                  final int currentItemAyaId = int.parse(rawId.toString());

                  // Safely resolve explicit IDs into matching Strings for global array lookups
                  final String targetSuraId = (aya['sura_id'] ?? '').toString();
                  final String targetAyaId = (aya['aya_id'] ?? aya['verse_id'] ?? aya['id'] ?? '').toString();

                  return Selector<AudioController, ({int currentEngineAyaId, bool playing})>(
                    selector: (_, ac) => (currentEngineAyaId: ac.currentAyaIndex, playing: ac.isPlaying),
                    builder: (context, audioState, child) {
                      final bool isCurrentPlaying = audioState.currentEngineAyaId == currentItemAyaId;
                      final bool isEngineActive = audioState.playing;
                      final audioController = context.read<AudioController>();

                      return GestureDetector(
                        onLongPress: () => _copyToClipboard(
                          context,
                          aya['arabic_text'] ?? '',
                          aya['bangla_translation'] ?? '',
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: isCurrentPlaying ? kHeaderLightGreen.withOpacity(0.3) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isCurrentPlaying ? kBrandGreen : kHeaderLightGreen,
                                width: isCurrentPlaying ? 1.5 : 1.0,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isCurrentPlaying ? kBrandGreen : kHeaderLightGreen,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          'Aya $currentItemAyaId',
                                          style: TextStyle(
                                            color: isCurrentPlaying ? Colors.white : kBrandGreen,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),

                                      // ✅ FIXED: Read and listen to the global bookmarks state dynamically
                                      Selector<DashboardController, bool>(
                                        selector: (_, dbController) => dbController.bookmarkedAyas.any((element) {
                                          final String currentSuraId = (element['sura_id'] ?? '').toString();
                                          final String currentAyaId = (element['aya_id'] ?? element['verse_id'] ?? element['id'] ?? '').toString();
                                          return currentSuraId == targetSuraId && currentAyaId == targetAyaId;
                                        }),
                                        builder: (context, isCurrentlyBookmarked, child) {
                                          return IconButton(
                                            iconSize: 22,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            icon: Icon(
                                              isCurrentlyBookmarked
                                                  ? Icons.star_rounded
                                                  : Icons.star_border_rounded,
                                              color: isCurrentlyBookmarked
                                                  ? const Color(0xFFFFB300)
                                                  : kBrandGreen.withOpacity(0.4),
                                            ),
                                            onPressed: () {
                                              HapticFeedback.lightImpact();

                                              // 1. Fire local disk sync toggle
                                              controller.toggleAyaBookmark(aya);

                                              // 2. Clear stack notifications and display the synchronized state
                                              ScaffoldMessenger.of(context).clearSnackBars();
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    !isCurrentlyBookmarked // We check inverted since state was just toggled
                                                        ? 'আয়াতটি বুকমার্কে যুক্ত করা হয়েছে'
                                                        : 'বুকমার্ক থেকে অপসারিত হয়েছে',
                                                    style: const TextStyle(fontFamily: 'SolaimanLipi'),
                                                  ),
                                                  duration: const Duration(milliseconds: 800),
                                                  behavior: SnackBarBehavior.floating,
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      ),

                                      IconButton(
                                        icon: Icon(
                                          (isEngineActive && isCurrentPlaying)
                                              ? Icons.pause_circle_filled_rounded
                                              : Icons.play_circle_fill_rounded,
                                          color: kBrandGreen,
                                          size: 32,
                                        ),
                                        onPressed: () {
                                          if (audioController.isBuffering) {
                                            debugPrint("⏳ Audio engine is busy loading/swapping tracks. Tap ignored.");
                                            return;
                                          }

                                          if (isEngineActive && isCurrentPlaying) {
                                            audioController.pause();
                                          } else {
                                            int reliablePlaybackIndex = audioController.findIndexByAyaId(currentItemAyaId);

                                            if (reliablePlaybackIndex != -1) {
                                              audioController.playAyaAudio(reliablePlaybackIndex, ayas);
                                            } else {
                                              audioController.playAyaAudio(index, ayas);
                                            }
                                          }
                                        },
                                      )
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    aya['arabic_text'] ?? '',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                      height: 1.8,
                                      fontFamily: 'Amiri',
                                    ),
                                  ),
                                  const Divider(height: 24, thickness: 0.5),
                                  Text(
                                    aya['bangla_translation'] ?? '',
                                    style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.5),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),

              // 2. Custom Edge-Attached Interactive Drag Scrollbar Gutter
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 24,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragStart: (_) {
                    _isDragging = true;
                    HapticFeedback.lightImpact();
                  },
                  onVerticalDragUpdate: (details) {
                    _handleTrackDrag(details.localPosition.dy, trackMaxScrollHeight);
                  },
                  onVerticalDragEnd: (_) {
                    _isDragging = false;
                  },
                  onTapDown: (details) {
                    _handleTrackDrag(details.localPosition.dy, trackMaxScrollHeight);
                  },
                  child: Stack(
                    children: [
                      Positioned(
                        top: currentThumbTop,
                        right: 4,
                        child: Container(
                          width: 8,
                          height: thumbHeight,
                          decoration: BoxDecoration(
                            color: kBrandGreen.withOpacity(_isDragging ? 0.9 : 0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}