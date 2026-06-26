import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/sound_alert_helper.dart';
import '../../providers/sound_detection_provider.dart';
import '../../providers/settings_provider.dart';

class SoundAlertPage extends StatelessWidget {
  const SoundAlertPage({super.key});

  void _showSoundSettings(BuildContext context, SoundDetectionProvider soundProv) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            Text("Configurar Sonidos", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
            const Text("Selecciona qué ruidos quieres que te avisemos", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            Expanded(
              child: Consumer<SoundDetectionProvider>(
                builder: (_, prov, __) => ListView(
                  children: prov.availableSounds.entries.map((entry) {
                    return SwitchListTile(
                      title: Text(entry.value, style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text(entry.key, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      secondary: Icon(_getIconForSound(entry.key), color: AppTheme.primaryBlue),
                      value: prov.enabledSounds.contains(entry.key),
                      onChanged: (val) => prov.toggleSound(entry.key),
                      activeColor: AppTheme.primaryBlue,
                    );
                  }).toList(),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text("Los cambios se guardan automáticamente", style: TextStyle(fontSize: 12, color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForSound(String label) {
    if (label.contains('alarm') || label.contains('detector')) return Icons.notification_important;
    if (label.contains('cry')) return Icons.child_care;
    if (label.contains('siren')) return Icons.warning_amber_rounded;
    if (label.contains('Doorbell') || label.contains('Knock')) return Icons.door_front_door;
    if (label.contains('horn')) return Icons.directions_car;
    return Icons.volume_up;
  }

  @override
  Widget build(BuildContext context) {
    final soundProv = Provider.of<SoundDetectionProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(settings.translate('sound_alert_title')),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_suggest_rounded),
            onPressed: () => _showSoundSettings(context, soundProv),
            tooltip: "Configurar sonidos",
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withAlpha(26),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
            ),
            child: Column(
              children: [
                Icon(
                  soundProv.isListening ? Icons.hearing_rounded : Icons.hearing_disabled_rounded,
                  size: 80,
                  color: soundProv.isListening ? AppTheme.primaryBlue : Colors.grey,
                ).animate(target: soundProv.isListening ? 1 : 0).shake(hz: 2, curve: Curves.easeInOut),
                const SizedBox(height: 20),
                Text(
                  soundProv.isListening ? "ESCUCHANDO EL ENTORNO" : "DETECTOR DESACTIVADO",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: soundProv.isListening ? AppTheme.primaryBlue : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStatusCard(
                    context,
                    title: "Último sonido detectado:",
                    value: soundProv.lastDetectedSound,
                    confidence: soundProv.confidence,
                    isActive: soundProv.isListening,
                  ),
                  const SizedBox(height: 30),
                  
                  _buildTestCard(context),
                  
                  const SizedBox(height: 20),
                  Text(
                    "Estás vigilando ${soundProv.enabledSounds.length} tipos de sonidos.",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(30.0),
            child: ElevatedButton(
              onPressed: () {
                if (soundProv.isListening) {
                  soundProv.stopListening();
                } else {
                  soundProv.startListening();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: soundProv.isListening ? Colors.red : AppTheme.primaryBlue,
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: Text(
                soundProv.isListening ? "DETENER ESCUCHA" : "ACTIVAR DETECTOR",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(26),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.orange.withAlpha(77)),
      ),
      child: Column(
        children: [
          const Text(
            "¿Quieres probar la alerta?",
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
          ),
          const SizedBox(height: 15),
          OutlinedButton.icon(
            onPressed: () => SoundAlertHelper.triggerIntenseAlert(),
            icon: const Icon(Icons.bolt_rounded, color: Colors.orange),
            label: const Text("PROBAR FLASH + VIBRACIÓN", style: TextStyle(color: Colors.orange)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.orange),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, {required String title, required String value, required double confidence, required bool isActive}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(26), blurRadius: 15)],
        border: Border.all(color: isActive ? AppTheme.primaryBlue.withAlpha(77) : Colors.transparent),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 10),
          Text(
            value.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isActive ? AppTheme.primaryBlue : Colors.grey,
            ),
          ),
          if (isActive && confidence > 0)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                "Nivel: ${confidence.toStringAsFixed(1)} dB",
                style: TextStyle(color: Colors.green[600], fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}
