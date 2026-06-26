import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:proyecto/core/utils/haptic_feedback_helper.dart';

enum NotificationType {
  friendRequest,
  friendAdded,
  incomingCall,
  sosAlert,
  soundAlert,
  chatMessage,
}

class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final String fromUid;
  final String? fromName;
  final String? channelName;
  final String? extraData;
  final DateTime timestamp;
  final bool read;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.fromUid,
    this.fromName,
    this.channelName,
    this.extraData,
    required this.timestamp,
    this.read = false,
  });

  factory AppNotification.fromFirestore(String id, Map<String, dynamic> data) {
    return AppNotification(
      id: id,
      type: NotificationType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => NotificationType.friendRequest,
      ),
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      fromUid: data['fromUid'] ?? '',
      fromName: data['fromName'],
      channelName: data['channelName'],
      extraData: data['extraData'],
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: data['read'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'type': type.name,
    'title': title,
    'body': body,
    'fromUid': fromUid,
    'fromName': fromName,
    'channelName': channelName,
    'extraData': extraData,
    'timestamp': Timestamp.fromDate(timestamp),
    'read': read,
  };
}

class NotificationHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static StreamSubscription<QuerySnapshot>? _subscription;
  static int _notificationId = 0;
  static String? _currentUid;
  static void Function(AppNotification)? onNotificationTap;
  static AppNotification? _pendingNotification;
  static int Function()? _unreadCountCallback;
  static final Set<String> _shownIds = {};

  // Mapa de palabras → pictogramas/emojis para notificaciones
  static const Map<String, String> _pictogramMap = {
    'comer': '🍽️', 'hambre': '🍽️', 'cena': '🍽️', 'comida': '🍽️', 'desayuno': '🍽️',
    'agua': '💧', 'sed': '💧', 'beber': '💧',
    'amor': '❤️', 'te_amo': '❤️', 'te_quiero': '❤️', 'corazon': '❤️',
    'hola': '👋', 'saludar': '👋',
    'gracias': '🙏',
    'feliz': '😊', 'alegria': '😊', 'contento': '😊',
    'triste': '😢', 'llorar': '😢',
    'enojado': '😠',
    'medico': '🏥', 'hospital': '🏥', 'doctor': '🩺', 'enfermedad': '🤒', 'dolor': '🤕',
    'fiesta': '🎉', 'cumpleanos': '🎂',
    'viaje': '✈️', 'viajar': '✈️', 'avion': '✈️',
    'casa': '🏠', 'hogar': '🏠',
    'perro': '🐕', 'gato': '🐈',
    'musica': '🎵', 'cancion': '🎵',
    'sol': '☀️', 'playa': '🏖️', 'mar': '🌊',
    'calor': '🔥', 'frio': '❄️', 'nieve': '❄️',
    'emergencia': '🚨', 'ayuda': '🆘', 'peligro': '⚠️', 'sos': '🆘',
    'escuela': '📚', 'clase': '📚', 'estudiar': '📚', 'universidad': '🎓',
    'trabajo': '💼', 'oficina': '💼', 'jefe': '👔',
    'amigo': '🤝', 'amiga': '🤝',
    'familia': '👨‍👩‍👧‍👦',
    'telefono': '📱', 'celular': '📱', 'llamada': '📞',
    'mensaje': '💬', 'chat': '💬',
    'cafe': '☕',
    'dormir': '😴', 'sueno': '😴', 'cama': '🛏️',
    'compras': '🛒', 'comprar': '🛒', 'tienda': '🛒',
    'ejercicio': '🏋️', 'gym': '🏋️', 'gimnasio': '🏋️',
  };

  /// Agrega un pictograma al body según el texto
  static String _addPictogram(String text) {
    final lower = text.toLowerCase();
    for (final entry in _pictogramMap.entries) {
      if (lower.contains(entry.key)) {
        return '${entry.value} $text';
      }
    }
    return text;
  }

  static Future<void> init() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) {
          final parts = payload.split('|');
          if (parts.length >= 2) {
            final notif = AppNotification(
              id: parts[0],
              type: NotificationType.values.firstWhere((e) => e.name == parts[1]),
              title: '',
              body: '',
              fromUid: parts.length > 2 ? parts[2] : '',
              channelName: parts.length > 3 ? parts[3] : null,
              fromName: parts.length > 4 ? parts[4] : null,
              timestamp: DateTime.now(),
            );
            if (onNotificationTap != null) {
              onNotificationTap!(notif);
            } else {
              _pendingNotification = notif;
            }
          }
        }
      },
    );
  }

  static void replayPending() {
    if (_pendingNotification != null && onNotificationTap != null) {
      final notif = _pendingNotification!;
      _pendingNotification = null;
      onNotificationTap!(notif);
    }
  }

  static void startListening(String uid) {
    _currentUid = uid;
    _subscription?.cancel();
    _shownIds.clear();
    _subscription = _firestore
        .collection('notifications')
        .doc(uid)
        .collection('items')
        .where('read', isEqualTo: false)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final id = change.doc.id;
          if (_shownIds.contains(id)) continue;
          _shownIds.add(id);
          final data = change.doc.data() as Map<String, dynamic>;
          final notif = AppNotification.fromFirestore(id, data);
          _showLocalNotification(notif);
        }
      }
    });
  }

  static void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _currentUid = null;
  }

  static Future<void> sendNotification({
    required String recipientUid,
    required NotificationType type,
    required String title,
    required String body,
    String? fromUid,
    String? fromName,
    String? channelName,
    String? extraData,
  }) async {
    try {
      final notif = AppNotification(
        id: '',
        type: type,
        title: title,
        body: body,
        fromUid: fromUid ?? '',
        fromName: fromName,
        channelName: channelName,
        extraData: extraData,
        timestamp: DateTime.now(),
      );
      await _firestore
          .collection('notifications')
          .doc(recipientUid)
          .collection('items')
          .add(notif.toMap());
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  static Future<void> _showLocalNotification(AppNotification notif) async {
    if (notif.fromUid == _currentUid) return;

    // Agregar pictograma al body según el tipo
    final body = notif.type == NotificationType.chatMessage
        ? _addPictogram(notif.body)
        : notif.type == NotificationType.sosAlert
            ? '🚨 ${notif.body}'
            : notif.body;

    // Título con pictograma
    final title = notif.type == NotificationType.sosAlert
        ? '🚨 ${notif.title}'
        : notif.type == NotificationType.incomingCall
            ? '📞 ${notif.title}'
            : notif.title;

    // Configuración específica por tipo
    final vibrationPattern = _getVibrationPattern(notif.type);
    final importance = notif.type == NotificationType.sosAlert
        ? Importance.max
        : notif.type == NotificationType.incomingCall
            ? Importance.high
            : Importance.high;

    final priority = notif.type == NotificationType.sosAlert
        ? Priority.max
        : Priority.high;

    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      notif.type == NotificationType.sosAlert
          ? 'senalink_emergency'
          : notif.type == NotificationType.incomingCall
              ? 'senalink_calls'
              : 'senalink_notifications',
      notif.type == NotificationType.sosAlert
          ? 'Emergencias'
          : notif.type == NotificationType.incomingCall
              ? 'Llamadas'
              : 'Notificaciones SeñaLink',
      channelDescription: notif.type == NotificationType.sosAlert
          ? 'Alertas de emergencia SOS'
          : 'Notificaciones de la app',
      importance: importance,
      priority: priority,
      playSound: true,
      enableVibration: true,
      vibrationPattern: vibrationPattern,
      icon: '@mipmap/ic_launcher',
      category: notif.type == NotificationType.sosAlert
          ? AndroidNotificationCategory.alarm
          : notif.type == NotificationType.incomingCall
              ? AndroidNotificationCategory.call
              : AndroidNotificationCategory.message,
    );

    final NotificationDetails details = NotificationDetails(android: androidDetails);

    final payload = '${notif.id}|${notif.type.name}|${notif.fromUid}|${notif.channelName ?? ''}|${notif.fromName ?? ''}';

    await _localNotifications.show(
      _notificationId++,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Patrón de vibración según el tipo de notificación
  static Int64List? _getVibrationPattern(NotificationType type) {
    switch (type) {
      case NotificationType.sosAlert:
        return Int64List.fromList([0, 1000, 500, 1000, 500, 1000]); // 3 vibraciones largas (alarma)
      case NotificationType.incomingCall:
        return Int64List.fromList([0, 500, 300, 500, 300, 500]); // 3 pulsos medianos
      case NotificationType.chatMessage:
        return Int64List.fromList([0, 100]); // 1 pulso corto
      case NotificationType.friendRequest:
        return Int64List.fromList([0, 200, 100, 200]); // 2 pulsos
      case NotificationType.friendAdded:
        return Int64List.fromList([0, 100, 50, 100, 50, 100]); // 3 pulsos rápidos (alegría)
      case NotificationType.soundAlert:
        return Int64List.fromList([0, 500, 200, 500, 200, 500]); // alerta de sonido detectado
    }
  }

  static Future<void> markAsRead(String notifId) async {
    if (_currentUid == null) return;
    try {
      await _firestore
          .collection('notifications')
          .doc(_currentUid)
          .collection('items')
          .doc(notifId)
          .update({'read': true});
    } catch (_) {}
  }

  static Stream<QuerySnapshot> getUnreadStream(String uid) {
    return _firestore
        .collection('notifications')
        .doc(uid)
        .collection('items')
        .where('read', isEqualTo: false)
        .snapshots();
  }
}
