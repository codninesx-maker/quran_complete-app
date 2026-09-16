import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:quran_complete/screen/bottombar/hadiths/quran/audio_controller.dart';
import 'package:quran_complete/screen/dashboard_view.dart';
import 'package:quran_complete/supabase_client.dart';
import 'screen/dashboard_logic.dart';

// 🛠️ CHANGED: Explicitly return Future<void> to secure underlying native bindings
Future<void> main() async {
  // 1️⃣ Ensure Flutter app engine bindings are ready
  WidgetsFlutterBinding.ensureInitialized();

  // 2️⃣ Initialize MediaKit (Mandatory for video rendering frames to paint!)
  MediaKit.ensureInitialized();

  // 3️⃣ Initialize JustAudioBackground with proper system properties
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.rxai.quran_complete.channel.audio',
      androidNotificationChannelName: 'Quran Audio Playback',
      androidNotificationOngoing: true,
      androidShowNotificationBadge: true,
    );
    debugPrint("✅ JustAudio Background Service Initialized Successfully");
  } catch (e) {
    debugPrint("❌ Audio Background Init Error: $e");
  }

  // 4️⃣ Initialize Google Mobile Ads SDK Engine
  try {
    // 🟩 CRITICAL: Secure AdMob lifecycle allocations before loading the view
    await MobileAds.instance.initialize();
    debugPrint("✅ Google Mobile Ads SDK Initialized Successfully");
  } catch (e) {
    debugPrint("❌ Mobile Ads Init Error: $e");
  }

  // 4️⃣ Initialize Supabase
  try {
    await SupabaseManager.init();
    debugPrint("✅ Supabase Engine Initialized Successfully");
  } catch (e) {
    debugPrint("❌ Supabase Init Error: $e");
  }

  // 5️⃣ Run the application once initialization completes
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AudioController()),

        ChangeNotifierProxyProvider<AudioController, DashboardController>(
          create: (context) {
            final controller = DashboardController(
              Provider.of<AudioController>(context, listen: false),
            );

            // 🚀 CRITICAL FIX: Offload all heavy synchronization tasks out of the synchronous creation thread
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Future.delayed(const Duration(milliseconds: 600), () async {
                // 1. Load your Suras
                await controller.fetchSura();

                // 2. Defer other heavy data calls down the microtask event queue
                Future.microtask(() {
                  // Move your 99 Names, Duas, and Hadiths parsing here!
                  // Example: Provider.of<DuaController>(context, listen: false).fetchDuas();
                });
              });
            });

            return controller;
          },
          update: (context, audio, dashboard) => dashboard!,
        ),
      ],
      child: const QuranApp(),
    ),
  );
}

class QuranApp extends StatelessWidget {
  const QuranApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF006B3C),
      ),
      home: const DashboardView(),
    );
  }
}