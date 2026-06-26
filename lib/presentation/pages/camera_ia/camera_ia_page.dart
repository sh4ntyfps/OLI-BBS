import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/haptic_feedback_helper.dart';

class CameraIAPage extends StatefulWidget {
  const CameraIAPage({super.key});

  @override
  State<CameraIAPage> createState() => _CameraIAPageState();
}

class _CameraIAPageState extends State<CameraIAPage> {
  CameraController? _controller;
  bool _isProcessing = false;
  String _detectedText = "Apunta a un cartel o símbolo...";

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _controller = CameraController(cameras.first, ResolutionPreset.high);
    try {
      await _controller!.initialize();
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      debugPrint('Error de cámara: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _scan() async {
    setState(() => _isProcessing = true);
    HapticFeedbackHelper.light();
    
    // Simulación de procesamiento de IA
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      setState(() {
        _isProcessing = false;
        _detectedText = "Símbolo detectado: ACCESIBILIDAD";
      });
      HapticFeedbackHelper.success();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Pantalla completa de cámara
          Positioned.fill(child: CameraPreview(_controller!)),

          // Marco de escaneo
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Stack(
                children: [
                  if (_isProcessing)
                    const Center(child: CircularProgressIndicator(color: Colors.white)),
                ],
              ),
            ),
          ),

          // Resultado del escaneo
          Positioned(
            bottom: 140,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _detectedText,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Botones de acción
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton.filled(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 30),
                  style: IconButton.styleFrom(backgroundColor: Colors.white24),
                ),
                GestureDetector(
                  onTap: _scan,
                  child: Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primaryBlue, width: 5),
                    ),
                    child: Icon(Icons.center_focus_strong_rounded, size: 40, color: AppTheme.primaryBlue),
                  ),
                ),
                IconButton.filled(
                  onPressed: () {},
                  icon: const Icon(Icons.flash_on, size: 30),
                  style: IconButton.styleFrom(backgroundColor: Colors.white24),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
