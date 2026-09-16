import 'package:flutter/foundation.dart';

class AdHelper {
  // Your Production App ID: ca-app-pub-7494179033430216~4902067377

  static String get nativeAdUnitId => kDebugMode
      ? 'ca-app-pub-3940256099942544/2247696110' // Google Test
      : 'ca-app-pub-7494179033430216/2917437481'; // Real Native

  static String get bannerAdUnitId => kDebugMode
      ? 'ca-app-pub-3940256099942544/6300978111' // Google Test
      : 'ca-app-pub-7494179033430216/3157113545'; // Real Banner

  static String get interstitialAdUnitId => kDebugMode
      ? 'ca-app-pub-3940256099942544/1033173712' // Google Test
      : 'ca-app-pub-7494179033430216/9530950200'; // Real Interstitial
}