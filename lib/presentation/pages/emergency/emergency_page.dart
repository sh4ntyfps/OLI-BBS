import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/utils/location_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/notification_helper.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';

class EmergencyPage extends StatefulWidget {
  const EmergencyPage({super.key});

  @override
  State<EmergencyPage> createState() => _EmergencyPageState();
}

class _EmergencyPageState extends State<EmergencyPage> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEF4444),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'MODO SOS',
            style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4),
          ),
          const SizedBox(height: 60),
          
          // Botón SOS con Animación de Pulso
          Center(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Ondas de pulso
                    _buildPulseCircle(1.0 + _pulseController.value * 0.5, 1.0 - _pulseController.value),
                    _buildPulseCircle(1.0 + _pulseController.value * 1.0, 0.5 - _pulseController.value * 0.5),
                    
                    // Botón Central
                    GestureDetector(
                      onTap: () => _triggerEmergency(context),
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 30,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.warning_rounded, size: 70, color: Color(0xFFEF4444)),
                            SizedBox(height: 5),
                            Text(
                              'SOS',
                              style: TextStyle(fontSize: 50, fontWeight: FontWeight.w900, color: Color(0xFFEF4444)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          
          const SizedBox(height: 80),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 50),
            child: Text(
              'Mantén presionado o toca una vez para pedir ayuda inmediata',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulseCircle(double scale, double opacity) {
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(opacity < 0 ? 0 : opacity),
        ),
      ),
    );
  }

  Future<void> _triggerEmergency(BuildContext context) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    HapticFeedbackHelper.notificationSOS();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ubicación enviada con éxito'), backgroundColor: Colors.black87),
    );
    final url = await LocationHelper.getCurrentLocationUrl();
    if (url != null) {
      await LocationHelper.sendEmergencyWhatsApp(settings.emergencyContact, "¡AYUDA! Ubicación: $url");
    }

    // Notificar a los amigos en la app
    if (auth.user != null) {
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
            body: 'Emergencia! Ubicación: $url',
            fromUid: auth.user!.id,
            fromName: auth.user?.name,
          );
        }
      } catch (_) {}
    }
  }
}
