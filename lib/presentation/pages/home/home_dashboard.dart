import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../widgets/pressable_card.dart';
import '../../widgets/glow_divider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/auth_provider.dart';
import '../pictograms/pictograms_page.dart';
import '../emergency/emergency_page.dart';
import '../emergency/sound_alert_page.dart';
import '../video_features/live_subtitles_page.dart';
import '../video_features/face_to_face_page.dart';
import '../video_features/sign_language_page.dart';
import '../phrases/quick_phrases_page.dart';

class HomeDashboard extends StatelessWidget {
  const HomeDashboard({super.key});

  void _showHelp(BuildContext context, SettingsProvider settings) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.lightbulb_rounded, color: Colors.amber),
            const SizedBox(width: 10),
            Text(settings.translate('how_to_use')),
          ],
        ),
        content: Text(settings.translate('instr_home')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final profileProv = Provider.of<ProfileProvider>(context);
    final authProv = Provider.of<AuthProvider>(context);
    final user = profileProv.userProfile;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Hero(
          tag: 'logo-text',
          child: Material(
            color: Colors.transparent,
            child: Text(
              'SeñaLink AI',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, 
                fontSize: 24, 
                color: Theme.of(context).textTheme.displayLarge?.color
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.lightbulb_outline_rounded, color: AppTheme.primaryBlue),
            onPressed: () => _showHelp(context, settings),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.language_rounded, color: AppTheme.primaryBlue),
            onSelected: (String value) {
              settings.setLocale(Locale(value));
              HapticFeedbackHelper.light();
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(value: 'es', child: Text('Español 🇪🇸')),
              const PopupMenuItem(value: 'en', child: Text('English 🇺🇸')),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.primaryBlue.withAlpha(26),
                  backgroundImage: (user?.profilePhoto != null && user!.profilePhoto!.isNotEmpty)
                      ? NetworkImage(user.profilePhoto!) : null,
                  child: (user?.profilePhoto == null || user!.profilePhoto!.isEmpty)
                      ? const Icon(Icons.person, size: 24, color: AppTheme.primaryBlue) : null,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${settings.translate('welcome').split('\n')[0]},",
                        style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textGrey),
                      ),
                      Text(
                        user?.name ?? authProv.user?.name ?? 'Usuario',
                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ).animate().fadeIn(),
            
            const SizedBox(height: 32),

            ShaderMask(
              shaderCallback: (bounds) => AppGradients.heroText.createShader(bounds),
              child: Text(
                settings.translate('how_to_help'),
                style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, height: 1.2, color: Colors.white),
              ),
            ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1),
            
            const SizedBox(height: 24),
            
            // GRID DE FUNCIONES SEGÚN TIPO DE DISCAPACIDAD
            GridView.extent(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              maxCrossAxisExtent: 220,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.1,
              children: [
                _buildModernCard(context, settings.translate('pictograms'), Icons.grid_view_rounded, const Color(0xFF6366F1), const PictogramsPage()),
                _buildModernCard(context, settings.translate('quick_phrases'), Icons.forum_rounded, const Color(0xFF8B5CF6), const QuickPhrasesPage()),
                // Alerta de sonido solo para quienes pueden oír (Mudo y Sordomudo)
                if (settings.disabilityType != DisabilityType.hearing)
                  _buildModernCard(context, settings.translate('sound_alert_title'), Icons.hearing_rounded, const Color(0xFFF59E0B), const SoundAlertPage()),
                _buildModernCard(context, "SOS Agitar", Icons.vibration_rounded, Colors.redAccent, const EmergencyPage()),
              ],
            ).animate().fadeIn(delay: 400.ms),

            // Video features visibles para todos
            const SizedBox(height: 16),
            const GlowDivider(margin: 24),
            const SizedBox(height: 16),
            _buildSectionHeader(context, settings.translate('video_features')),
            const SizedBox(height: 16),
            _buildVideoCarousel(context, settings),
            
            const SizedBox(height: 100), 
          ],
        ),
      ),
    );
  }

  Widget _buildModernCard(BuildContext context, String title, IconData icon, Color color, Widget? dest) {
    return PressableCard(
      onTap: () {
        HapticFeedbackHelper.light();
        if (dest != null) Navigator.push(context, MaterialPageRoute(builder: (_) => dest));
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withAlpha(26), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 10),
          Text(title, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(title, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold));
  }

  Widget _buildVideoCarousel(BuildContext context, SettingsProvider settings) {
    final items = <Widget>[];
    switch (settings.disabilityType) {
      case DisabilityType.hearing:
        items.addAll([
          _buildHorizontalPressable(context, settings.translate('subtitles'), Icons.closed_caption_rounded, const Color(0xFF9333EA), const LiveSubtitlesPage()),
          _buildHorizontalPressable(context, "Texto a Seña", Icons.front_hand_rounded, const Color(0xFF10B981), const SignLanguagePage()),
        ]);
      case DisabilityType.speech:
        items.addAll([
          _buildHorizontalPressable(context, "Seña a Texto", Icons.camera_alt_rounded, const Color(0xFF10B981), const SignLanguagePage()),
          _buildHorizontalPressable(context, settings.translate('face_to_face'), Icons.duo_rounded, const Color(0xFFDB2777), const FaceToFacePage()),
        ]);
      case DisabilityType.both:
        items.addAll([
          _buildHorizontalPressable(context, "Texto a Seña", Icons.front_hand_rounded, const Color(0xFF10B981), const SignLanguagePage()),
          _buildHorizontalPressable(context, settings.translate('face_to_face'), Icons.duo_rounded, const Color(0xFFDB2777), const FaceToFacePage()),
        ]);
    }
    return SizedBox(
      height: 150,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: items,
      ),
    );
  }

  Widget _buildHorizontalPressable(BuildContext context, String title, IconData icon, Color color, Widget dest) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 16),
      child: PressableCard(
        color: color,
        shadow: [BoxShadow(color: color.withAlpha(64), blurRadius: 10, offset: const Offset(0, 5))],
        onTap: () {
          HapticFeedbackHelper.success();
          Navigator.push(context, MaterialPageRoute(builder: (_) => dest));
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 38),
            const SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
