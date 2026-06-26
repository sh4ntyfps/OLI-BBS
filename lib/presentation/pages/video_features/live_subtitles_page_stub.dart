import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/utils/tts_helper.dart';
import '../../providers/settings_provider.dart';

class LiveSubtitlesPage extends StatefulWidget {
  const LiveSubtitlesPage({super.key});

  @override
  State<LiveSubtitlesPage> createState() => _LiveSubtitlesPageState();
}

class _LiveSubtitlesPageState extends State<LiveSubtitlesPage> {
  CameraController? _cameraController;
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = "";
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initializeCamera();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_text.isEmpty) {
      _text = Provider.of<SettingsProvider>(context, listen: false).translate('listening_hint');
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      debugPrint("Error inicializando cámara: $e");
    }
  }

  void _showHelp(SettingsProvider settings) {
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
        content: Text(settings.translate('instr_subtitles')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  void _listen(SettingsProvider settings) async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    bool available = await _speech.initialize();
    if (available) {
      if (mounted) setState(() => _isListening = true);
      HapticFeedbackHelper.light();

      _speech.listen(
        localeId: settings.locale.languageCode == 'es' ? 'es_PE' : 'en_US',
        onResult: (val) {
          if (mounted) {
            setState(() {
              _text = val.recognizedWords;
              if (val.hasConfidenceRating && val.confidence > 0) {
                HapticFeedbackHelper.success();
              }
            });
          }
        },
      );
    }
  }

  Future<void> _scanText() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      HapticFeedbackHelper.light();

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Recortar Texto',
            toolbarColor: AppTheme.primaryBlue,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Recortar Texto',
          ),
        ],
      );

      if (croppedFile != null && mounted) {
        // OCR no disponible en web - mostrar mensaje
        setState(() {
          _text = "OCR no disponible en versión web. Usa la app móvil.";
        });
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _speech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    if (!_isInitialized || _cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue)),
      );
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_cameraController!),
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.5), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            top: 40,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            top: 40,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.help_outline_rounded, color: Colors.white, size: 30),
              onPressed: () => _showHelp(settings),
            ),
          ),
          Positioned(
            bottom: 150,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(18),
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.5), width: 1.5),
              ),
              child: Stack(
                children: [
                  SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Center(
                      child: Text(
                        _text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5
                        ),
                      ),
                    ),
                  ),
                  if (_text.isNotEmpty && _text != settings.translate('listening_hint'))
                    Positioned(
                      top: -10,
                      right: -10,
                      child: IconButton(
                        icon: const Icon(Icons.volume_up_rounded, color: AppTheme.primaryBlue, size: 28),
                        onPressed: () {
                          TtsHelper.speak(_text, settings.locale.languageCode);
                          HapticFeedbackHelper.light();
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton(
                  heroTag: "ocr_btn",
                  elevation: 4,
                  backgroundColor: Colors.white,
                  onPressed: _scanText,
                  child: const Icon(Icons.document_scanner_rounded, color: AppTheme.primaryBlue),
                ),
                GestureDetector(
                  onTap: () => _listen(settings),
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: _isListening ? Colors.redAccent : AppTheme.primaryBlue,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_isListening ? Colors.red : AppTheme.primaryBlue).withOpacity(0.4),
                          blurRadius: 15,
                          spreadRadius: 2
                        )
                      ]
                    ),
                    child: Icon(
                      _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                      color: Colors.white,
                      size: 45
                    ),
                  ),
                ),
                const SizedBox(width: 56),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
