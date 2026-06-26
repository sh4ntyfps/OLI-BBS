import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:proyecto/core/theme/app_theme.dart';
import 'package:proyecto/core/theme/app_gradients.dart';
import 'package:proyecto/presentation/pages/main_navigation_page.dart';
import 'package:proyecto/presentation/providers/auth_provider.dart';
import 'package:proyecto/presentation/providers/settings_provider.dart';
import 'package:proyecto/presentation/providers/profile_provider.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  void _handleLogin(SettingsProvider settings) async {
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final profileProv = Provider.of<ProfileProvider>(context, listen: false);
    
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(settings.translate('fill_fields')))
      );
      return;
    }

    bool success = await authProv.login(
      _emailController.text.trim(), 
      _passwordController.text.trim()
    );

    if (success && mounted) {
      // Cargamos el perfil real apenas entra
      await profileProv.loadProfile(authProv.user!.id);
      
      // Sincronizar contacto de emergencia con SettingsProvider
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      if (profileProv.userProfile?.emergencyContact.isNotEmpty == true) {
        settings.setEmergencyContact(profileProv.userProfile!.emergencyContact);
      }
      
      if (mounted) {
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (context) => const MainNavigationPage())
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authProv.errorMessage ?? 'Error'))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProv = Provider.of<AuthProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const SizedBox(height: 60),
              Hero(
                tag: 'logo',
                child: Container(
                  height: 120, width: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryBlue.withOpacity(0.2), 
                        blurRadius: 25, 
                        offset: const Offset(0, 10)
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Image.asset('assets/images/img_logo.png', fit: BoxFit.cover, 
                      errorBuilder: (c, e, s) => const Icon(Icons.auto_awesome, color: AppTheme.primaryBlue, size: 50)),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'SeñaLink AI', 
                style: GoogleFonts.poppins(
                  fontSize: 32, 
                  fontWeight: FontWeight.bold, 
                  color: Theme.of(context).textTheme.displayLarge?.color
                )
              ),
              const SizedBox(height: 8),
              Text(
                settings.translate('welcome'), 
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: AppTheme.textGrey, fontSize: 16)
              ),
              const SizedBox(height: 48),

              _buildInputField(
                label: settings.translate('email'), 
                hint: 'tu@email.com', 
                icon: Icons.email_outlined, 
                controller: _emailController, 
                keyboardType: TextInputType.emailAddress
              ),
              const SizedBox(height: 24),
              _buildInputField(
                label: settings.translate('password'), 
                hint: '••••••••', 
                icon: Icons.lock_outline, 
                controller: _passwordController,
                isPassword: true, 
                isPasswordVisible: _isPasswordVisible,
                onToggleVisibility: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
              ),

              const SizedBox(height: 32),
              authProv.isLoading
                  ? const CircularProgressIndicator()
                  : Container(
                      decoration: AppGradients.primaryButton(borderRadius: 16),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          minimumSize: const Size(double.infinity, 60),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => _handleLogin(settings),
                        child: Text(settings.translate('login_now')),
                      ),
                    ),
              
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: authProv.isLoading ? null : () async {
                  bool success = await authProv.loginGuest();
                  if (success && mounted) {
                    Navigator.pushReplacement(
                      context, 
                      MaterialPageRoute(builder: (context) => const MainNavigationPage())
                    );
                  }
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 60), 
                  side: BorderSide(color: Colors.grey.shade200, width: 2), 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                ),
                child: Text(settings.locale.languageCode == 'es' ? 'Continuar como invitado' : 'Continue as Guest'),
              ),

              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(settings.translate('no_account'), style: GoogleFonts.poppins(color: AppTheme.textGrey)),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterPage())),
                    child: Text(
                      settings.translate('register_button'), 
                      style: GoogleFonts.poppins(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold)
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label, 
    required String hint, 
    required IconData icon, 
    required TextEditingController controller, 
    TextInputType keyboardType = TextInputType.text, 
    bool isPassword = false, 
    bool isPasswordVisible = false, 
    VoidCallback? onToggleVisibility
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          obscureText: isPassword && !isPasswordVisible,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint, 
            prefixIcon: Icon(icon, color: AppTheme.primaryBlue.withOpacity(0.7)),
            suffixIcon: isPassword ? IconButton(
              icon: Icon(isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey), 
              onPressed: onToggleVisibility
            ) : null,
            filled: true, 
            fillColor: Theme.of(context).cardTheme.color,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}
