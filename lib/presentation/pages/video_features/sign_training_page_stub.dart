import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/settings_provider.dart';

class SignTrainingPage extends StatelessWidget {
  const SignTrainingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Laboratorio SeñaLink AI")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.science_rounded, size: 80, color: AppTheme.primaryBlue),
              const SizedBox(height: 24),
              Text(
                settings.translate('web_ml_unavailable'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.primaryBlue),
              ),
              const SizedBox(height: 12),
              Text(
                settings.translate('web_ml_hint'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
