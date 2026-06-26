import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:proyecto/core/theme/app_theme.dart';
import 'package:proyecto/core/constants/strings.dart';
import 'package:proyecto/core/services/notification_service.dart';
import 'package:proyecto/core/services/notification_helper.dart';
import 'package:proyecto/presentation/pages/onboarding/splash_screen.dart';
import 'package:proyecto/presentation/providers/settings_provider.dart';
import 'package:proyecto/presentation/providers/auth_provider.dart';
import 'package:proyecto/presentation/providers/friends_provider.dart';
import 'package:proyecto/presentation/providers/chat_provider.dart';
import 'package:proyecto/presentation/providers/profile_provider.dart';
import 'package:proyecto/presentation/providers/sound_detection_provider.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  final localNotifications = FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
  await localNotifications.initialize(initSettings);

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'high_importance_channel',
    'Notificaciones de Chat',
    importance: Importance.max,
    priority: Priority.high,
  );
  const NotificationDetails details = NotificationDetails(android: androidDetails);

  await localNotifications.show(
    message.hashCode,
    message.notification?.title ?? 'SeñaLink AI',
    message.notification?.body ?? 'Tienes una nueva notificación',
    details,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (kIsWeb) {
      // TODO: Reemplaza con tu config de Firebase Web desde Firebase Console
      // (Project Settings > General > Your apps > Web)
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyBTrbKyBrJamr3WzP1QOFAcbVxdJF7xaV0",
          authDomain: "senalink-ai.firebaseapp.com",
          projectId: "senalink-ai",
          storageBucket: "senalink-ai.firebasestorage.app",
          messagingSenderId: "711910750511",
          appId: "1:711910750511:web:eff3bb3a4703abb32449da",
          measurementId: "G-1T96P9T5MT",
        ),
      );
    } else {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      await NotificationService.initialize();
    }
  } catch (e) {
    debugPrint("Error inicial: $e");
  }

  await NotificationHelper.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FriendsProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => SoundDetectionProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppStrings.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,
      locale: settings.locale,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(settings.fontSizeMultiplier),
          ),
          child: child!,
        );
      },
      home: const SplashScreen(),
    );
  }
}
