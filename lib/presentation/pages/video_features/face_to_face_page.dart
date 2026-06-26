import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../providers/settings_provider.dart';

class FaceToFacePage extends StatefulWidget {
  const FaceToFacePage({super.key});

  @override
  State<FaceToFacePage> createState() => _FaceToFacePageState();
}

class _FaceToFacePageState extends State<FaceToFacePage> {
  late stt.SpeechToText _speech;
  CameraController? _cameraController;
  bool _isListeningTop = false;
  bool _isListeningBottom = false;
  String _topText = "";
  String _bottomText = "";
  bool _showIntro = true;
  bool _isSwapped = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    _cameraController = CameraController(cameras.first, ResolutionPreset.medium);
    await _cameraController?.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  void _listen(bool isTop, SettingsProvider settings) async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() {
        if (isTop) _isListeningTop = true;
        else _isListeningBottom = true;
      });
      _speech.listen(
        onResult: (val) => setState(() {
          if (isTop) _topText = val.recognizedWords;
          else _bottomText = val.recognizedWords;
        }),
      );
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() {
      _isListeningTop = false;
      _isListeningBottom = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    
    return Scaffold(
      body: Stack(
        children: [
          // FONDO DE CÁMARA PARA QUE SE VEAN
          if (_cameraController != null && _cameraController!.value.isInitialized)
            Positioned.fill(child: CameraPreview(_cameraController!)),
          
          // CAPA SEMI-TRANSPARENTE
          Container(color: Colors.black.withOpacity(0.4)),

          Column(
            children: [
              Expanded(
                child: Transform.rotate(
                  angle: math.pi,
                  child: _buildHalf(true, settings),
                ),
              ),
              const Divider(color: Colors.white54, height: 2),
              Expanded(
                child: _buildHalf(false, settings),
              ),
            ],
          ),

          if (_showIntro) _buildIntro(settings),
          
          Positioned(top: 40, left: 10, child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context))),
        ],
      ),
    );
  }

  Widget _buildHalf(bool isTop, SettingsProvider settings) {
    String text = isTop ? (_isSwapped ? _bottomText : _topText) : (_isSwapped ? _topText : _bottomText);
    bool isListening = isTop ? _isListeningTop : _isListeningBottom;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: Text(
                text.isEmpty ? "Toca el micro para hablar" : text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 10, color: Colors.black)]),
              ),
            ),
          ),
          GestureDetector(
            onLongPressStart: (_) => _listen(isTop, settings),
            onLongPressEnd: (_) => _stopListening(),
            child: CircleAvatar(
              radius: 35,
              backgroundColor: isListening ? Colors.red : AppTheme.primaryBlue,
              child: Icon(isListening ? Icons.mic : Icons.mic_none, color: Colors.white, size: 30),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntro(SettingsProvider settings) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_alt, color: Colors.white, size: 80).animate().scale(),
            const Padding(
              padding: EdgeInsets.all(30),
              child: Text("Coloca el móvil entre los dos. Ahora podéis veros y leer el texto al mismo tiempo.", 
                textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 18)),
            ),
            ElevatedButton(onPressed: () => setState(() => _showIntro = false), child: const Text("EMPEZAR")),
          ],
        ),
      ),
    );
  }
}
