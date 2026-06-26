import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:proyecto/core/theme/app_theme.dart';
import 'package:proyecto/core/utils/haptic_feedback_helper.dart';
import 'package:proyecto/presentation/providers/settings_provider.dart';
import 'package:proyecto/presentation/providers/auth_provider.dart';
import 'package:proyecto/presentation/providers/profile_provider.dart';
import '../auth/login_page.dart';
import '../video_features/sign_training_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isUploading = false;

  Future<void> _pickAndUploadImage(String uid, ProfileProvider profileProv, SettingsProvider settings) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 40);
    if (image == null) return;
    setState(() => _isUploading = true);
    try {
      final storageRef = FirebaseStorage.instance.ref().child('profiles/$uid.jpg');
      await storageRef.putData(await image.readAsBytes());
      final String downloadUrl = await storageRef.getDownloadURL();
      await profileProv.updateProfilePhoto(uid, downloadUrl);
      settings.setProfilePhoto(downloadUrl);
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _showEditContactDialog(BuildContext context, SettingsProvider settings, AuthProvider authProv, ProfileProvider profileProv) async {
    final controller = TextEditingController(text: settings.emergencyContact);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(settings.translate('edit_contact')),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            hintText: settings.translate('enter_phone'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(settings.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(settings.translate('save')),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && authProv.user != null) {
      settings.setEmergencyContact(result);
      await profileProv.updateEmergencyContact(authProv.user!.id, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final authProv = Provider.of<AuthProvider>(context);
    final profileProv = Provider.of<ProfileProvider>(context);
    final user = profileProv.userProfile;

    return Scaffold(
      appBar: AppBar(title: const Text("Mi Perfil", style: TextStyle(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 70,
                    backgroundImage: (user?.profilePhoto != null && user!.profilePhoto!.isNotEmpty) ? NetworkImage(user.profilePhoto!) : null,
                    child: (user?.profilePhoto == null) ? const Icon(Icons.person, size: 70) : null,
                  ),
                  Positioned(bottom: 0, right: 0, child: CircleAvatar(backgroundColor: AppTheme.primaryBlue, child: IconButton(icon: const Icon(Icons.camera_alt, color: Colors.white), onPressed: () => _pickAndUploadImage(authProv.user!.id, profileProv, settings)))),
                  if (_isUploading) const Positioned.fill(child: Center(child: CircularProgressIndicator(color: Colors.white))),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(user?.name ?? "Usuario", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),

            // MODO ENTRENAMIENTO IA
            _buildActionCard(
              title: "Laboratorio de IA",
              subtitle: "Entrena nuevas señas para el sistema",
              icon: Icons.model_training_rounded,
              color: Colors.orange,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SignTrainingPage())),
            ),

            const SizedBox(height: 12),

            // AJUSTES: MODO OSCURO
            _buildActionCard(
              title: settings.translate('dark_mode'),
              subtitle: "Cambiar tema visual",
              icon: Icons.dark_mode,
              color: AppTheme.primaryBlue,
              trailing: Switch(value: settings.isDarkMode, onChanged: (v) => settings.toggleTheme(v)),
            ),

            const SizedBox(height: 12),

            // NUEVO: TAMAÑO DE FUENTE
            _buildActionCard(
              title: settings.translate('font_size'),
              subtitle: "Ajustar el texto de la app",
              icon: Icons.format_size_rounded,
              color: Colors.teal,
              trailing: SizedBox(
                width: 100,
                child: Slider(
                  value: settings.fontSizeMultiplier,
                  min: 0.8,
                  max: 1.4,
                  onChanged: (v) => settings.setFontSize(v),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // NUEVO: IDIOMA
            _buildActionCard(
              title: settings.translate('language'),
              subtitle: settings.locale.languageCode == 'es' ? "Español" : "English",
              icon: Icons.language_rounded,
              color: Colors.blueAccent,
              trailing: DropdownButton<String>(
                value: settings.locale.languageCode,
                underline: const SizedBox(),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                items: const [
                  DropdownMenuItem(value: 'es', child: Text("ES 🇪🇸")),
                  DropdownMenuItem(value: 'en', child: Text("EN 🇺🇸")),
                ],
                onChanged: (val) {
                  if (val != null) {
                    settings.setLocale(Locale(val));
                    HapticFeedbackHelper.light();
                  }
                },
              ),
            ),

            const SizedBox(height: 12),

            _buildActionCard(
              title: settings.translate('emergency_contact'),
              subtitle: user?.emergencyContact ?? settings.emergencyContact,
              icon: Icons.emergency,
              color: Colors.red,
              onTap: () => _showEditContactDialog(context, settings, authProv, profileProv),
            ),

            const SizedBox(height: 12),

            _buildActionCard(
              title: settings.translate('shake_sos'),
              subtitle: settings.translate('shake_sos_desc'),
              icon: Icons.vibration_rounded,
              color: Colors.redAccent,
              trailing: Switch(
                value: settings.shakeSOSEnabled,
                onChanged: (v) => settings.toggleShakeSOS(v),
              ),
            ),

            const SizedBox(height: 20),
            const Text("Tipo de discapacidad", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ...DisabilityType.values.map((type) {
              final isSelected = settings.disabilityType == type;
              String label, desc;
              IconData icon;
              switch (type) {
                case DisabilityType.speech: label = 'Sordo'; desc = 'Puedo hablar pero no escucho'; icon = Icons.hearing_disabled;
                case DisabilityType.hearing: label = 'Mudo'; desc = 'Escucho pero no puedo hablar'; icon = Icons.record_voice_over;
                case DisabilityType.both: label = 'Sordomudo'; desc = 'No puedo escuchar ni hablar'; icon = Icons.sign_language;
              }
              return RadioListTile<DisabilityType>(
                value: type,
                groupValue: settings.disabilityType,
                title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text(desc, style: const TextStyle(fontSize: 11)),
                activeColor: AppTheme.primaryBlue,
                secondary: Icon(icon, color: isSelected ? AppTheme.primaryBlue : Colors.grey, size: 28),
                onChanged: (v) { if (v != null) { settings.setDisabilityType(v); HapticFeedbackHelper.light(); } },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              );
            }),

            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                authProv.logout();
                Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red, minimumSize: const Size(double.infinity, 50)),
              child: const Text("CERRAR SESIÓN", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({required String title, required String subtitle, required IconData icon, required Color color, VoidCallback? onTap, Widget? trailing}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
        trailing: trailing ?? const Icon(Icons.chevron_right, size: 20),
      ),
    );
  }
}
