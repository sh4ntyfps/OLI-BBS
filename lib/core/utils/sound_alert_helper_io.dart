import 'package:torch_light/torch_light.dart';
import 'package:vibration/vibration.dart';
import 'dart:async';

class SoundAlertHelper {
  static bool _isAlerting = false;

  static Future<void> triggerIntenseAlert({int repetitions = 3}) async {
    if (_isAlerting) return;
    _isAlerting = true;

    for (int i = 0; i < repetitions; i++) {
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(duration: 800, amplitude: 255);
      }

      await _blinkFlash(800);

      await Future.delayed(const Duration(milliseconds: 200));
    }

    _isAlerting = false;
  }

  static Future<void> _blinkFlash(int durationMs) async {
    try {
      if (await TorchLight.isTorchAvailable()) {
        await TorchLight.enableTorch();
        await Future.delayed(Duration(milliseconds: durationMs ~/ 2));
        await TorchLight.disableTorch();
        await Future.delayed(Duration(milliseconds: durationMs ~/ 4));
        await TorchLight.enableTorch();
        await Future.delayed(Duration(milliseconds: durationMs ~/ 4));
        await TorchLight.disableTorch();
      }
    } catch (e) {
      print("Error con el flash: $e");
    }
  }

  static Future<void> alertFireAlarm() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [0, 1000, 500, 1000, 500, 1000]);
    }
    await _blinkFlash(3000);
  }

  static Future<void> alertDoorbell() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [0, 200, 100, 200, 100, 200]);
    }
    await _blinkFlash(1000);
  }
}
