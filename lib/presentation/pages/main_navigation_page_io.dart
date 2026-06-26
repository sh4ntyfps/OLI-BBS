import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:animations/animations.dart';
import 'package:provider/provider.dart';
import 'package:shake/shake.dart';
import '../../core/services/call_service.dart';
import '../../core/services/notification_helper.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/haptic_feedback_helper.dart';
import '../../core/utils/location_helper.dart';
import '../providers/settings_provider.dart';
import '../providers/auth_provider.dart';
import 'home/home_dashboard.dart';
import 'chat/chat_list_page.dart';
import 'chat/chat_page.dart';
import 'friends/friends_page.dart';
import 'settings/profile_page.dart';
import 'video_features/calling_screen.dart';
import 'video_features/smart_video_call_page.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _selectedIndex = 0;
  ShakeDetector? _shakeDetector;
  StreamSubscription? _callSubscription;

  List<Widget> _pages(DisabilityType type) {
    return [const HomeDashboard(), const ChatListPage(), const FriendsPage(), const ProfilePage()];
  }

  List<Widget> _navIcons(DisabilityType type) {
    return [
      const Icon(Icons.home_rounded, size: 30, color: Colors.white),
      const Icon(Icons.forum_rounded, size: 30, color: Colors.white),
      const Icon(Icons.people_rounded, size: 30, color: Colors.white),
      const Icon(Icons.settings_rounded, size: 30, color: Colors.white),
    ];
  }

  @override
  void initState() {
    super.initState();
    _initShakeDetection();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initListeners());
  }

  void _initListeners() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user == null) {
      auth.addListener(_onAuthReady);
      return;
    }
    _startListeners(auth.user!.id);
  }

  void _onAuthReady() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user == null) return;
    auth.removeListener(_onAuthReady);
    _startListeners(auth.user!.id);
  }

  void _startListeners(String uid) {
    // Listener de llamadas entrantes
    _callSubscription = CallService.listenForIncomingCalls(uid).listen((snapshot) {
      if (!snapshot.exists || !mounted) return;
      final data = snapshot.data() as Map<String, dynamic>;
      if (data['status'] == 'calling') {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => IncomingCallDialog(
            callerName: data['callerName'] ?? "Alguien",
            myUid: uid,
            channelName: data['channelName'] ?? '',
          ),
        );
      }
    });

    // Listener de notificaciones en la app
    NotificationHelper.onNotificationTap = (notif) {
      if (!mounted) return;
      NotificationHelper.markAsRead(notif.id);
      switch (notif.type) {
        case NotificationType.incomingCall:
          if (notif.channelName != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SmartVideoCallPage(
                  channelName: notif.channelName!,
                  remoteUserName: notif.fromName ?? 'Alguien',
                  callDocKey: uid,
                ),
              ),
            );
          }
          break;
        case NotificationType.friendRequest:
        case NotificationType.friendAdded:
          setState(() => _selectedIndex = 2);
          break;
        case NotificationType.chatMessage:
          if (notif.channelName != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatPage(
                  chatId: notif.channelName,
                  chatName: notif.extraData,
                ),
              ),
            );
          }
          break;
        default:
          break;
      }
    };
    NotificationHelper.replayPending();
    NotificationHelper.startListening(uid);
  }

  @override
  void dispose() {
    _shakeDetector?.stopListening();
    _callSubscription?.cancel();
    NotificationHelper.stopListening();
    NotificationHelper.onNotificationTap = null;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    auth.removeListener(_onAuthReady);
    super.dispose();
  }

  void _initShakeDetection() {
    _shakeDetector = ShakeDetector.autoStart(
      onPhoneShake: () {
        final settings = Provider.of<SettingsProvider>(context, listen: false);
        if (settings.shakeSOSEnabled) {
          _triggerEmergencySOS(settings.emergencyContact);
        }
      },
      shakeThresholdGravity: 2.7,
    );
  }

  Future<void> _triggerEmergencySOS(String contact) async {
    HapticFeedbackHelper.error();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SOS ACTIVADO POR SACUDIDA'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );

    final googleMapsUrl = await LocationHelper.getCurrentLocationUrl();
    if (googleMapsUrl != null) {
      final String mensaje = "AYUDA DE EMERGENCIA! Mi ubicación: $googleMapsUrl";
      await LocationHelper.sendEmergencyWhatsApp(contact, mensaje);
    }

    // Notificar a amigos
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user != null && googleMapsUrl != null) {
      try {
        final friendsSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(auth.user!.id)
            .collection('friends')
            .get();
        for (var doc in friendsSnap.docs) {
          NotificationHelper.sendNotification(
            recipientUid: doc.id,
            type: NotificationType.sosAlert,
            title: '🚨 SOS - ${auth.user?.name ?? "Alguien"}',
            body: 'Emergencia! Ubicación: $googleMapsUrl',
            fromUid: auth.user!.id,
            fromName: auth.user?.name,
          );
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = Provider.of<SettingsProvider>(context);
    final type = settings.disabilityType;
    final pages = _pages(type);
    final icons = _navIcons(type);

    if (_selectedIndex >= pages.length) _selectedIndex = 0;

    return Scaffold(
      extendBody: true,
      body: PageTransitionSwitcher(
        duration: const Duration(milliseconds: 500),
        transitionBuilder: (child, primaryAnimation, secondaryAnimation) {
          return FadeThroughTransition(
            animation: primaryAnimation,
            secondaryAnimation: secondaryAnimation,
            fillColor: AppTheme.backgroundWhite,
            child: child,
          );
        },
        child: pages[_selectedIndex],
      ),
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: CurvedNavigationBar(
            height: 65.0,
            index: _selectedIndex,
            items: icons,
            color: isDark ? AppTheme.darkSurface.withAlpha(230) : AppTheme.primaryBlue,
            buttonBackgroundColor: AppTheme.primaryBlue,
            backgroundColor: Colors.transparent,
            animationCurve: Curves.easeInOutBack,
            animationDuration: const Duration(milliseconds: 400),
            onTap: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
          ),
        ),
      ),
    );
  }
}
