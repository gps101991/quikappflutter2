import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quikappflutter2/services/firebase_service.dart';
import '../config/env_config.dart';
import '../module/myapp.dart';
import '../services/notification_service.dart';
import '../utils/menu_parser.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) {
    print("🔔 Handling a background message: ${message.messageId}");
    print("📝 Message data: ${message.data}");
    print("📌 Notification: ${message.notification?.title}");
  }
}

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Lock orientation to portrait only
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    // Initialize local notifications first
    await initLocalNotifications();

    if (pushNotify) {
      try {
        // Initialize Firebase with options from configuration files
        final options = await loadFirebaseOptionsFromJson();
        await Firebase.initializeApp(options: options);

        // Set background message handler
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

        // Initialize Firebase Messaging
        await initializeFirebaseMessaging();

        debugPrint("✅ Firebase initialized successfully");
      } catch (e) {
        debugPrint("❌ Firebase initialization error: $e");
      }
    } else {
      debugPrint("🚫 Firebase not initialized (pushNotify: $pushNotify, isWeb: $kIsWeb)");
    }

    if (webUrl.isEmpty) {
      debugPrint("❗ Missing WEB_URL environment variable.");
      runApp(MaterialApp(
        home: Scaffold(
          body: Center(child: Text("WEB_URL not configured.")),
        ),
      ));
      return;
    }

    debugPrint("""
      🛠 Runtime Config:
      - pushNotify: $pushNotify
      - webUrl: $webUrl
      - isSplash: $isSplashEnabled,
      - splashLogo: $splashUrl,
      - splashBg: $splashBgUrl,
      - splashDuration: $splashDuration,
      - splashAnimation: $splashAnimation,
      - taglineColor: $splashTaglineColor,
      - spbgColor: $splashBgColor,
      - isBottomMenu: $isBottomMenu,
      - bottomMenuItems: ${parseBottomMenuItems(bottomMenuRaw)},
      - isDeeplink: $isDeepLink,
      - backgroundColor: $bottomMenuBgColor,
      - activeTabColor: $bottomMenuActiveTabColor,
      - textColor: $bottomMenuTextColor,
      - iconColor: $bottomMenuIconColor,
      - iconPosition: $bottomMenuIconPosition,
      - Permissions:
        - Camera: $isCameraEnabled
        - Location: $isLocationEnabled
        - Mic: $isMicEnabled
        - Notification: $isNotificationEnabled
        - Contact: $isContactEnabled
      """);

    runApp(MyApp(
      webUrl: webUrl,
      isSplash: isSplashEnabled,
      splashLogo: splashUrl,
      splashBg: splashBgUrl,
      splashDuration: splashDuration,
      splashAnimation: splashAnimation,
      taglineColor: splashTaglineColor,
      spbgColor: splashBgColor,
      isBottomMenu: isBottomMenu,
      bottomMenuItems: bottomMenuRaw,
      isDeeplink: isDeepLink,
      backgroundColor: bottomMenuBgColor,
      activeTabColor: bottomMenuActiveTabColor,
      textColor: bottomMenuTextColor,
      iconColor: bottomMenuIconColor,
      iconPosition: bottomMenuIconPosition,
      isLoadIndicator: isLoadIndicator,
    ));
  } catch (e, stackTrace) {
    debugPrint("❌ Fatal error during initialization: $e");
    debugPrint("Stack trace: $stackTrace");
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(child: Text("Error: $e")),
      ),
    ));
  }
}