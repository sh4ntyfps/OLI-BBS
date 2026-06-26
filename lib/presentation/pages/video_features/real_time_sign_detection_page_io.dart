import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:provider/provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../providers/settings_provider.dart';
import 'hand_painter.dart';

const int _seqLen = 45;
const int _poseDim = 132;
const int _faceDim = 1404;
const int _featDim = _poseDim + _faceDim;

class RealTimeSignDetectionPage extends StatefulWidget {
  const RealTimeSignDetectionPage({super.key});

  @override
  State<RealTimeSignDetectionPage> createState() => _RealTimeSignDetectionPageState();
}

class _RealTimeSignDetectionPageState extends State<RealTimeSignDetectionPage> {
  CameraController? _cameraController;
  bool _isBusy = false;

  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
  );
  final FaceMeshDetector _faceMeshDetector = FaceMeshDetector(option: FaceMeshDetectorOptions.faceMesh);

  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _modelReady = false;

  final List<Float32List> _frameBuffer = [];
  String _predictedSign = "";
  double _confidence = 0.0;
  bool _handInFrame = false;
  List<Pose> _poses = [];
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _loadModel();
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _poseDetector.close();
    _faceMeshDetector.close();
    _interpreter?.close();
    super.dispose();
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'models/senalink_model.tflite',
      );

      final inputShape = _interpreter!.getInputTensor(0).shape;
      final expectedInput = _seqLen * _featDim;
      if (inputShape.length < 2 || inputShape[1] != expectedInput) {
        debugPrint("Modelo incompatible: espera ${inputShape[1]}, actual $_featDim por frame");
        _interpreter = null;
        return;
      }

      final labelData = await rootBundle.loadString('assets/models/labels.txt');
      _labels = labelData
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      setState(() => _modelReady = true);
    } catch (e) {
      debugPrint("Error cargando modelo TFLite: $e");
    }
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _cameraController = CameraController(
      cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    await _cameraController?.initialize().then((_) {
      if (!mounted) return;
      _cameraController?.startImageStream(_processCameraImage);
      setState(() {});
    });
  }

  void _processCameraImage(CameraImage image) {
    if (_isBusy) return;
    _isBusy = true;

    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) {
      _isBusy = false;
      return;
    }

    _poseDetector.processImage(inputImage).then((poses) {
      if (mounted) {
        _faceMeshDetector.processImage(inputImage).then((meshes) {
          if (mounted) {
            setState(() {
              _poses = poses;
              _imageSize = Size(image.width.toDouble(), image.height.toDouble());

              if (poses.isNotEmpty) {
                _extractAndPredict(poses.first, meshes.isNotEmpty ? meshes.first : null);
              } else {
                _handInFrame = false;
                if (_predictedSign.isNotEmpty) {
                  _predictedSign = "";
                  _confidence = 0.0;
                }
              }
            });
          }
          _isBusy = false;
        }).catchError((_) {
          if (mounted) {
            setState(() {
              _poses = poses;
              _imageSize = Size(image.width.toDouble(), image.height.toDouble());

              if (poses.isNotEmpty) {
                _extractAndPredict(poses.first, null);
              } else {
                _handInFrame = false;
                if (_predictedSign.isNotEmpty) {
                  _predictedSign = "";
                  _confidence = 0.0;
                }
              }
            });
          }
          _isBusy = false;
        });
      } else {
        _isBusy = false;
      }
    }).catchError((e) {
      _isBusy = false;
    });
  }

  void _extractAndPredict(Pose pose, FaceMesh? mesh) {
    _handInFrame = true;

    final frameData = Float32List(_featDim);
    int i = 0;
    for (final landmark in pose.landmarks.values) {
      if (i + 4 <= _poseDim) {
        frameData[i] = landmark.x;
        frameData[i + 1] = landmark.y;
        frameData[i + 2] = landmark.z;
        frameData[i + 3] = landmark.likelihood;
        i += 4;
      }
    }

    if (mesh != null) {
      int j = _poseDim;
      for (final point in mesh.points) {
        if (j + 3 <= _featDim) {
          frameData[j] = point.x;
          frameData[j + 1] = point.y;
          frameData[j + 2] = point.z;
          j += 3;
        }
      }
    }

    _frameBuffer.add(frameData);
    if (_frameBuffer.length > _seqLen) {
      _frameBuffer.removeAt(0);
    }

    if (_frameBuffer.length == _seqLen && _modelReady && _interpreter != null) {
      _runInference();
    }
  }

  void _runInference() {
    final input = Float32List(_seqLen * _featDim);
    for (int f = 0; f < _seqLen; f++) {
      final frame = _frameBuffer[f];
      input.setRange(f * _featDim, (f + 1) * _featDim, frame);
    }

    final output = Float32List(_labels.length);

    try {
      _interpreter!.run(input, output);
    } catch (e) {
      debugPrint("Error en inferencia TFLite: $e");
      return;
    }

    final probs = output;
    double maxProb = 0.0;
    int maxIdx = 0;
    for (int i = 0; i < probs.length; i++) {
      if (probs[i] > maxProb) {
        maxProb = probs[i];
        maxIdx = i;
      }
    }

    if (maxProb > 0.3 && maxIdx < _labels.length) {
      final newSign = _labels[maxIdx];
      if (_predictedSign != newSign && newSign.isNotEmpty) {
        HapticFeedbackHelper.success();
      }
      setState(() {
        _predictedSign = newSign;
        _confidence = maxProb;
      });
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotation.rotation0deg,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          ClipRRect(
            child: SizedOverflowBox(
              size: MediaQuery.of(context).size,
              child: CameraPreview(_cameraController!),
            ),
          ),

          if (_poses.isNotEmpty && _imageSize != null)
            CustomPaint(
              size: MediaQuery.of(context).size,
              painter: PosePainter(_poses, _imageSize!, InputImageRotation.rotation0deg),
            ),

          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.transparent,
                  Colors.black.withOpacity(0.5),
                ],
              ),
            ),
          ),

          Center(
            child: Container(
              width: 280,
              height: 350,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _handInFrame ? Colors.cyanAccent : Colors.white.withOpacity(0.3),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),

          Positioned(
            bottom: 60,
            left: 20,
            right: 20,
            child: Column(
              children: [
                if (!_modelReady)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 30),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Text(
                      "Entrena el modelo primero en Laboratorio",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 30),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 20, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        _predictedSign.isNotEmpty
                            ? _predictedSign.toUpperCase()
                            : settings.translate(_predictedSign.isEmpty ? "waiting_sign" : "no_hands"),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.primaryBlue,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (_confidence > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            "${(_confidence * 100).toStringAsFixed(0)}%",
                            style: TextStyle(
                              color: Colors.green[600],
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
