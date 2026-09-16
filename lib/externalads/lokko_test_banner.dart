import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:quran_complete/externalads/ad_helper.dart'; // 🟩 FIXED: Added the central mapping import

class QuranBannerAd extends StatefulWidget {
  final AdSize adSize;
  const QuranBannerAd({super.key, this.adSize = AdSize.banner});

  @override
  State<QuranBannerAd> createState() => _QuranBannerAdState();
}

class _QuranBannerAdState extends State<QuranBannerAd> with AutomaticKeepAliveClientMixin {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeYourServices();
    });
  }

  @override
  void dispose() {
    debugPrint("QURAN_ADS: Widget is being DISPOSED!");
    _bannerAd?.dispose();
    super.dispose();
  }

  void _loadAd() {
    // Guard clause: Do not build an ad request if widget was detached during delays
    if (!mounted) return;

    debugPrint("QURAN_ADS: Requesting banner layout from server...");

    _bannerAd = BannerAd(
      adUnitId: AdHelper.bannerAdUnitId, // 🟩 FIXED: Pulls dynamic real/test values cleanly
      size: widget.adSize, // Dynamically uses passed size configuration
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint("QURAN_ADS: SUCCESS! Ad layout successfully established.");
          if (!mounted) return;
          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint("QURAN_ADS: FAIL! Ad failed to render layout: ${error.message}");
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _bannerAd = null; // Safety cleanup step
            _isLoaded = false;
          });
        },
      ),
    );

    _bannerAd!.load();
  }

  Future<void> _initializeYourServices() async {
    // Soft delay to allow page transition transitions to settle cleanly
    await Future.delayed(const Duration(milliseconds: 300));
    _loadAd();
  }

  @override
  Widget build(BuildContext context) {
    // Enforces the AutomaticKeepAliveClientMixin structural layout contract
    super.build(context);

    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Center(
      child: SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }
}