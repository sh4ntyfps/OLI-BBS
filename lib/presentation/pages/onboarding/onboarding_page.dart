import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../auth/login_page.dart';
import '../../../core/theme/app_theme.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  bool _isLastPage = false;

  final List<OnboardingContent> _contents = [
    OnboardingContent(
      title: 'Rompe las barreras',
      description: 'Traduce lenguaje de señas a texto y voz al instante con inteligencia artificial.',
      icon: Icons.auto_awesome_rounded,
      color: AppTheme.primaryBlue,
    ),
    OnboardingContent(
      title: 'Conversa con fluidez',
      description: 'Usa subtítulos en tiempo real para entender y ser entendido por todos.',
      icon: Icons.forum_rounded,
      color: const Color(0xFF10B981),
    ),
    OnboardingContent(
      title: 'Siempre protegido',
      description: 'Tu seguridad es primero. Envía alertas SOS con tu ubicación en un solo toque.',
      icon: Icons.security_rounded,
      color: const Color(0xFFEF4444),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        padding: const EdgeInsets.only(bottom: 80),
        child: PageView.builder(
          controller: _controller,
          onPageChanged: (index) {
            setState(() => _isLastPage = index == _contents.length - 1);
          },
          itemCount: _contents.length,
          itemBuilder: (context, index) => _buildPage(_contents[index]),
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        height: 100,
        color: Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => _controller.jumpToPage(_contents.length - 1),
              child: Text('SALTAR', style: GoogleFonts.poppins(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            Center(
              child: SmoothPageIndicator(
                controller: _controller,
                count: _contents.length,
                effect: const WormEffect(
                  spacing: 16,
                  dotColor: Color(0xFFE5E7EB),
                  activeDotColor: AppTheme.primaryBlue,
                  dotHeight: 10,
                  dotWidth: 10,
                ),
              ),
            ),
            _isLastPage
                ? TextButton(
                    onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage())),
                    child: Text('LISTO', style: GoogleFonts.poppins(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold)),
                  )
                : TextButton(
                    onPressed: () => _controller.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.easeInOut),
                    child: Text('SIGUIENTE', style: GoogleFonts.poppins(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold)),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingContent content) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Hero(
          tag: 'onboarding-icon-${content.title}',
          child: Container(
            height: 250,
            width: 250,
            decoration: BoxDecoration(
              color: content.color.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(content.icon, size: 120, color: content.color),
          ),
        ),
        const SizedBox(height: 60),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            content.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF111827),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            content.description,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 18,
              color: const Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class OnboardingContent {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  OnboardingContent({required this.title, required this.description, required this.icon, required this.color});
}
