import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationHelper {
  /// Obtiene la ubicación actual y devuelve un enlace de Google Maps
  static Future<String?> getCurrentLocationUrl() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Verificar si el servicio de ubicación está habilitado
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    // Obtener coordenadas
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    return 'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';
  }

  /// Envía la ubicación por WhatsApp a un número específico
  static Future<void> sendEmergencyWhatsApp(String phoneNumber, String message) async {
    final url = Uri.parse("whatsapp://send?phone=$phoneNumber&text=${Uri.encodeComponent(message)}");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      // Si no tiene WhatsApp, intentar por SMS
      final smsUrl = Uri.parse("sms:$phoneNumber?body=${Uri.encodeComponent(message)}");
      if (await canLaunchUrl(smsUrl)) {
        await launchUrl(smsUrl);
      }
    }
  }
}
