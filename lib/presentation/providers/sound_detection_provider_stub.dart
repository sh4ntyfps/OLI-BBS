import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SoundDetectionProvider with ChangeNotifier {
  bool _isListening = false;
  String _lastDetectedSound = "Silencio";
  double _confidence = 0.0;

  final Map<String, String> availableSounds = {
    'Smoke detector, smoke alarm': 'Detector de Humo',
    'Fire alarm': 'Alarma de Incendio',
    'Siren': 'Sirena de Emergencia',
    'Ambulance (siren)': 'Ambulancia',
    'Police car (siren)': 'Policía',
    'Emergency vehicle': 'Vehículo de Emergencia',
    'Baby cry, infant cry': 'Bebé Llorando',
    'Doorbell': 'Timbre de Puerta',
    'Knock': 'Alguien toca la Puerta',
    'Screaming': 'Gritos / Chillidos',
    'Shout': 'Grito Fuerte',
    'Breaking': 'Cosas Rompiéndose',
    'Glass': 'Cristal Roto',
    'Shatter': 'Estallido',
    'Car horn': 'Claxon de Auto',
    'Alarm clock': 'Despertador',
    'Telephone bell': 'Teléfono Fijo',
    'Ringtone': 'Celular Sonando',
    'Dog': 'Ladrido de Perro',
    'Explosion': 'Explosión',
  };

  final Set<String> _enabledSounds = {};

  SoundDetectionProvider() {
    _loadEnabledSounds();
  }

  Future<void> _loadEnabledSounds() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('enabled_sounds');
    if (saved != null) {
      final list = List<String>.from(jsonDecode(saved));
      _enabledSounds.addAll(list);
    } else {
      _enabledSounds.addAll({
        'Smoke detector, smoke alarm',
        'Fire alarm',
        'Siren',
        'Baby cry, infant cry',
      });
    }
    notifyListeners();
  }

  Future<void> _saveEnabledSounds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('enabled_sounds', jsonEncode(_enabledSounds.toList()));
  }

  bool get isListening => _isListening;
  String get lastDetectedSound => _lastDetectedSound;
  double get confidence => _confidence;
  Set<String> get enabledSounds => _enabledSounds;

  void toggleSound(String label) {
    if (_enabledSounds.contains(label)) {
      _enabledSounds.remove(label);
    } else {
      _enabledSounds.add(label);
    }
    _saveEnabledSounds();
    notifyListeners();
  }

  void startListening() {
    if (_isListening) return;
    _isListening = true;
    notifyListeners();
  }

  void stopListening() {
    _isListening = false;
    _lastDetectedSound = "Detenido";
    notifyListeners();
  }
}
