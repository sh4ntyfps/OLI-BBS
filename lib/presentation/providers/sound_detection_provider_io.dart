import 'dart:async';
import 'package:flutter/material.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../core/utils/sound_alert_helper.dart';

class SoundDetectionProvider with ChangeNotifier {
  bool _isListening = false;
  String _lastDetectedSound = "Silencio";
  double _confidence = 0.0;
  StreamSubscription<NoiseReading>? _noiseSubscription;
  final NoiseMeter _noiseMeter = NoiseMeter();

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

    try {
      _noiseSubscription = _noiseMeter.noise.listen((NoiseReading noiseReading) {
        _processNoise(noiseReading);
      }, onError: (Object error) {
        stopListening();
      });
    } catch (e) {
      _isListening = false;
      notifyListeners();
    }
  }

  void _processNoise(NoiseReading noise) {
    _confidence = noise.maxDecibel;

    if (_enabledSounds.isNotEmpty && _confidence > 80) {
      _lastDetectedSound = "ALERTA DETECTADA";
      _triggerAlert();
    }
    notifyListeners();
  }

  void _triggerAlert() {
    SoundAlertHelper.triggerIntenseAlert(repetitions: 2);
  }

  void stopListening() {
    _noiseSubscription?.cancel();
    _noiseSubscription = null;
    _isListening = false;
    _lastDetectedSound = "Detenido";
    notifyListeners();
  }
}
