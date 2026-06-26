import 'package:vibration/vibration.dart';

class HapticFeedbackHelper {
  static Future<void> success() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 100);
    }
  }

  static Future<void> error() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [0, 500, 200, 500]);
    }
  }

  static Future<void> light() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 50);
    }
  }

  // ─── Patrones específicos para notificaciones ────────────────────────

  /// Mensaje de chat nuevo — pulso corto
  static Future<void> notificationMessage() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 100);
    }
  }

  /// Solicitud de amistad — 2 pulsos
  static Future<void> notificationFriendRequest() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [0, 200, 100, 200]);
    }
  }

  /// Alerta de sonido detectado — pulsos intermitentes
  static Future<void> notificationSoundAlert() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [0, 500, 200, 500, 200, 500]);
    }
  }

  /// Llamada entrante — 3 pulsos medianos
  static Future<void> notificationIncomingCall() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [0, 500, 300, 500, 300, 500]);
    }
  }

  /// Emergencia SOS — vibración continua de alerta
  static Future<void> notificationSOS() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [0, 1000, 500, 1000, 500, 1000]);
    }
  }
}
