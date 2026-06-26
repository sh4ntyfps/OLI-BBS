import 'dart:convert';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:provider/provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../providers/auth_provider.dart';

class SignTrainingPage extends StatefulWidget {
  const SignTrainingPage({super.key});

  @override
  State<SignTrainingPage> createState() => _SignTrainingPageState();
}

const int _seqLen = 45;
const int _poseDim = 132;
const int _faceDim = 1404;
const int _featDim = _poseDim + _faceDim;

class _SignTrainingPageState extends State<SignTrainingPage> {
  CameraController? _cameraController;
  final PoseDetector _poseDetector = PoseDetector(options: PoseDetectorOptions(mode: PoseDetectionMode.stream));
  final FaceMeshDetector _faceMeshDetector = FaceMeshDetector(option: FaceMeshDetectorOptions.faceMesh);

  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _modelReady = false;

  bool _isRecording = false;
  bool _isBusy = false;
  int _cameraIndex = 0;
  late String _selectedCategory;
  late String _selectedLabel;
  List<List<double>> _currentSequence = [];
  int _sampleCount = 0;

  final Map<String, List<String>> _dataset = {
    "Santiago — Emergencias y Salud": [
      "Dolor", "sangre", "medicina", "receta", "pastilla", "tos", "fiebre", "mareo", "alergia", "herida", "ambulancia", "camilla", "inyección", "venda", "yeso", "farmacia", "psicólogo", "dentista", "operación", "síntoma", "examen", "rayos-x", "silla de ruedas", "muletas", "presión", "corazón", "pulmón", "estómago", "cabeza", "garganta", "brazo", "pierna", "mano", "pie", "dedo", "espalda", "cuello", "oído", "ojos", "nariz", "boca", "dientes", "lengua", "quemadura", "asfixia", "desmayo", "veneno", "peligro", "fuego", "choque", "robo", "policía", "bomberos", "salida", "entrada", "escalera", "ascensor", "prohibido", "urgente", "calma",
      "Necesito un médico urgente.", "Me duele mucho la cabeza.", "Soy alérgico a esta medicina.", "Llamen a una ambulancia ahora.", "¿Dónde está la farmacia más cercana?", "Tengo mucha fiebre y tos.", "Me caí y me duele el brazo.", "Necesito mis pastillas para la presión.", "No puedo respirar bien.", "¿Cuál es su tipo de sangre?", "Me siento mareado y con náuseas.", "El niño tiene dolor de estómago.", "¿Dónde está el hospital de emergencias?", "Necesito una silla de ruedas.", "Mi abuelo tuvo un desmayo.", "Me corté la mano muy profundo.", "¿A qué hora abre el dentista?", "Por favor, mantenga la calma.", "Hay un fuego en la cocina.", "Ayuda, me robaron mi billetera."
    ],
    "Mari — Hogar y Vida Diaria": [
      "Mesa", "silla", "cama", "sofá", "lámpara", "ventana", "puerta", "cocina", "baño", "cuarto", "sala", "jardín", "llave", "control", "televisor", "radio", "internet", "wifi", "enchufe", "luz", "agua", "jabón", "toalla", "cepillo", "pasta", "espejo", "peine", "champú", "papel", "plato", "vaso", "cuchara", "tenedor", "cuchillo", "servilleta", "olla", "sartén", "microondas", "nevera", "escoba", "trapeador", "basura", "ropa", "zapato", "pantalón", "camisa", "medias", "gorra", "reloj", "billetera", "celular", "cargador", "audífonos", "mochila", "paraguas", "plancha", "lavadora", "almohada", "manta", "alfombra",
      "La llave está sobre la mesa.", "¿Me das la contraseña del wifi?", "Necesito limpiar mi cuarto hoy.", "Se acabó el papel higiénico.", "Voy a ducharme en diez minutos.", "Cierra la puerta al salir, por favor.", "No encuentro el control del televisor.", "La luz de la sala no prende.", "Pon la ropa en la lavadora.", "¿Dónde guardaste mi mochila azul?", "Apaga el microondas cuando termine.", "Abre la ventana, hace mucho calor.", "Necesito un peine y jabón nuevo.", "El sofá es muy cómodo y suave.", "Trae una toalla limpia del baño.", "Vamos a ver una película juntos.", "Ayúdame a sacar la basura afuera.", "Mi cama necesita mantas nuevas.", "El cargador del celular no funciona.", "Revisa si hay agua en la nevera."
    ],
    "Andre — Alimentación y Sabores": [
      "Pan", "leche", "café", "té", "azúcar", "sal", "huevo", "queso", "mantequilla", "mermelada", "arroz", "pasta", "carne", "pollo", "pescado", "ensalada", "sopa", "fruta", "manzana", "plátano", "naranja", "uva", "fresa", "limón", "verdura", "papa", "tomate", "cebolla", "zanahoria", "choclo", "postre", "helado", "pastel", "galleta", "chocolate", "jugo", "refresco", "cerveza", "vino", "desayuno", "almuerzo", "cena", "hambre", "sed", "rico", "feo", "caliente", "frío", "dulce", "salado", "ácido", "picante", "cocinar", "freír", "hervir", "cortar", "servir", "pagar", "cuenta", "propina",
      "¿Qué hay de comer hoy?", "Quiero café sin azúcar, por favor.", "Este pescado está muy rico.", "Tengo mucha sed, quiero agua fría.", "La sopa está demasiado caliente.", "¿Me pasas la sal y la pimienta?", "No me gusta la comida picante.", "Quiero un helado de chocolate de postre.", "Vamos a desayunar pan con huevo.", "¿Cuánto cuesta la cuenta total?", "Este jugo de naranja está muy ácido.", "Prefiero comer ensalada y pollo frito.", "El arroz necesita un poco más de sal.", "¿Tienen comida para vegetarianos aquí?", "Quiero una manzana roja y dulce.", "La carne está muy dura para cortar.", "¿A qué hora es el almuerzo?", "Muchas gracias por la deliciosa cena.", "Quiero beber un té caliente ahora.", "Trae más servilletas a la mesa."
    ],
    "Carlos — Educación y Trabajo": [
      "Lápiz", "cuaderno", "libro", "borrador", "regla", "tijera", "pegamento", "mochila", "tarea", "examen", "nota", "clase", "profesor", "alumno", "director", "universidad", "instituto", "curso", "diploma", "aprender", "leer", "escribir", "dibujar", "calcular", "oficina", "jefe", "empleado", "reunión", "horario", "sueldo", "contrato", "firma", "sello", "computadora", "teclado", "mouse", "pantalla", "correo", "mensaje", "llamada", "zoom", "presentación", "idea", "proyecto", "éxito", "error", "corregir", "equipo", "ayuda", "pregunta", "respuesta", "duda", "saber", "olvidar", "recordar", "pensar", "entender", "explicar", "silencio", "atención",
      "Mañana tengo un examen muy difícil.", "¿Me prestas tu cuaderno de notas?", "El profesor explica la clase muy bien.", "Tengo una reunión de trabajo importante.", "Ya envié el informe por correo.", "¿Cuál es la tarea para el lunes?", "Necesito un borrador y una regla.", "No entiendo esta pregunta del libro.", "Mi jefe quiere hablar conmigo hoy.", "El proyecto fue un éxito total.", "Guarda silencio en la biblioteca, por favor.", "¿Dónde está mi computadora portátil?", "Necesito imprimir este documento ahora.", "Vamos a trabajar en equipo este semestre.", "Olvidé mi contraseña del sistema.", "La presentación empieza en cinco minutos.", "¿Puedes explicarme la idea otra vez?", "Tengo muchas dudas sobre este curso.", "Escribe tu nombre y firma aquí.", "El horario de clases cambió ayer."
    ],
    "Andryck — Emociones y Relaciones": [
      "Amor", "odio", "miedo", "sorpresa", "vergüenza", "orgullo", "celos", "envidia", "esperanza", "confianza", "duda", "paz", "guerra", "amigo", "enemigo", "novio", "novia", "esposo", "esposa", "hijo", "hija", "hermano", "hermana", "abuelo", "abuela", "tío", "tía", "primo", "sobrino", "vecino", "conocido", "extraño", "grupo", "solo", "juntos", "ayudar", "cuidar", "besar", "abrazar", "pelear", "perdonar", "invitar", "visitar", "extrañar", "prometer", "cumplir", "mentir", "verdad", "secreto", "favor", "regalo", "fiesta", "boda", "cumpleaños", "muerte", "nacimiento", "crecer", "envejecer", "joven", "viejo",
      "Te quiero mucho, mejor amigo.", "Perdóname por mi error del pasado.", "¿Quieres ir a una fiesta conmigo?", "Mañana es mi cumpleaños número veinte.", "Confío mucho en lo que dice mi hermano.", "Me siento muy orgulloso de ti.", "Estoy un poco sorprendido por la noticia.", "No tengas miedo, yo estoy aquí.", "Ella es mi novia y la amo.", "Mi vecino es una person muy amable.", "Vamos a visitar a los abuelos hoy.", "Te extraño mucho cuando no estás.", "Te prometo que diré la verdad siempre.", "Es un secreto, no se lo digas a nadie.", "Recibí un regalo muy bonito ayer.", "¿Quieres ser mi pareja de baile?", "Me da mucha vergüenza hablar en público.", "Siempre estaremos juntos pase lo que pase.", "Mis padres celebran su boda hoy.", "Siento mucha paz en este lugar."
    ],
    "Cinthia — Ciudad y Transporte": [
      "Calle", "avenida", "esquina", "cuadra", "parque", "plaza", "puente", "edificio", "tienda", "market", "centro comercial", "cine", "teatro", "museo", "banco", "cajero", "correo", "iglesia", "estadio", "gimnasio", "hotel", "playa", "río", "cerro", "paradero", "bus", "taxi", "tren", "metro", "avión", "barco", "bicicleta", "moto", "conducir", "viajar", "boleto", "pasaje", "mapa", "GPS", "norte", "sur", "este", "oeste", "cerca", "lejos", "derecha", "izquierda", "derecho", "atrás", "arriba", "abajo", "semáforo", "señal", "tráfico", "multa", "accidente", "rápido", "lento", "parar", "continuar",
      "El paradero está a dos cuadras.", "Tome un taxi para ir al centro.", "¿Cuánto cuesta el boleto de tren?", "Gira a la derecha en la esquina.", "El banco está muy lejos de aquí.", "Cruza el puente con mucho cuidado.", "¿Dónde puedo comprar un mapa hoy?", "El bus viene muy rápido por la avenida.", "Hay mucho tráfico en la calle principal.", "Estaciónate detrás de ese carro azul.", "El semáforo está en rojo, espera.", "El market vende frutas muy baratas.", "Vamos al cine a ver una película.", "Mi casa queda cerca de la plaza.", "¿A qué hora sale el próximo avión?", "El parque es perfecto para caminar.", "Perdí mi pasaje de regreso a casa.", "Sigue derecho hasta llegar al museo.", "El hotel tiene una vista muy bonita.", "El cajero automático no tiene dinero."
    ],
    "Anahy — Naturaleza y Tiempo": [
      "Sol", "luna", "estrella", "cielo", "nube", "lluvia", "nieve", "viento", "trueno", "rayo", "calor", "frío", "clima", "árbol", "flor", "planta", "tierra", "arena", "piedra", "montaña", "mar", "olas", "isla", "desierto", "animal", "perro", "gato", "pájaro", "caballo", "vaca", "león", "tigre", "oso", "elefante", "mono", "serpiente", "pez", "insecto", "tiempo", "segundo", "minuto", "hora", "día", "semana", "mes", "año", "siglo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo", "enero", "verano", "invierno", "primavera", "otoño", "temprano", "tarde",
      "Hoy hace mucho calor afuera.", "Mira qué bonita es esa flor roja.", "Mi perro es muy juguetón y cariñoso.", "La próxima semana viajaré a la playa.", "Lloverá el viernes por la tarde.", "Las estrellas brillan mucho esta noche.", "El árbol del jardín es muy viejo.", "Escuché un trueno muy fuerte recién.", "Me gusta ver las nubes en el cielo.", "El gato duerme sobre la tierra seca.", "Vamos a la montaña el domingo temprano.", "El mar tiene olas muy grandes hoy.", "¿Qué hora tienes en tu reloj?", "Faltan cinco minutos para la reunión.", "El invierno es mi estación favorita.", "Vi un pájaro azul en el parque.", "El viento sopla muy fuerte hoy.", "Estamos en el siglo veintiuno ahora.", "Mañana será un día muy especial.", "La luna está llena y muy brillante."
    ],
    "Juan — Conceptos y Tecnología": [
      "Color", "rojo", "azul", "verde", "amarillo", "blanco", "negro", "gris", "marrón", "naranja", "morado", "forma", "círculo", "cuadrado", "triángulo", "grande", "pequeño", "largo", "corto", "ancho", "angosto", "nuevo", "viejo", "caro", "barato", "gratis", "buscar", "encontrar", "perder", "ganar", "comprar", "vender", "cambiar", "romper", "arreglar", "usar", "prender", "apagar", "cargar", "descargar", "subir", "bajar", "link", "página", "red social", "foto", "video", "audio", "música", "película", "cámara", "flash", "vibración", "batería", "señal", "teclado", "digital", "contraseña", "usuario", "perfil",
      "Mi color favorito es el azul.", "Este teléfono celular es muy caro.", "La batería está por acabarse pronto.", "Pásame el link de la página web.", "¿Puedes arreglar mi computadora rota?", "El círculo es más grande que el cuadrado.", "Esta camisa es demasiado corta para mí.", "Encontré mi billetera en el suelo.", "Quiero comprar zapatos nuevos y baratos.", "La foto de perfil se ve genial.", "Baja el volumen de la música, por favor.", "Prende la cámara para la videollamada.", "Mi contraseña tiene letras y números.", "El video se descargó muy rápido hoy.", "No tengo señal de internet aquí.", "Sube esa imagen a tu red social.", "Necesito cargar la batería del control.", "El teclado está un poco sucio ahora.", "Mira este video, es muy divertido.", "Todo lo que ves aquí es gratis."
    ]
  };

  @override
  void initState() {
    super.initState();
    _selectedCategory = _dataset.keys.first;
    _selectedLabel = _dataset[_selectedCategory]![0];
    _loadModel();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProv = Provider.of<AuthProvider>(context, listen: false);
      final String? userName = authProv.user?.name?.toLowerCase();
      if (userName != null) {
        for (String category in _dataset.keys) {
          if (category.toLowerCase().contains(userName)) {
            setState(() {
              _selectedCategory = category;
              _selectedLabel = _dataset[category]![0];
            });
            break;
          }
        }
      }
    });

    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    _cameraIndex = 0;
    _cameraController = CameraController(cameras[_cameraIndex], ResolutionPreset.medium, enableAudio: false, imageFormatGroup: ImageFormatGroup.nv21);
    await _cameraController?.initialize();
    if (mounted) {
      _cameraController?.startImageStream(_processCameraImage);
      setState(() {});
    }
  }

  Future<void> _switchCamera() async {
    final cameras = await availableCameras();
    if (cameras.length < 2) return;
    final newIndex = _cameraIndex == 0 ? 1 : 0;
    await _cameraController?.stopImageStream();
    await _cameraController?.dispose();
    _cameraController = CameraController(cameras[newIndex], ResolutionPreset.medium, enableAudio: false, imageFormatGroup: ImageFormatGroup.nv21);
    await _cameraController?.initialize();
    if (mounted) {
      _cameraIndex = newIndex;
      _cameraController?.startImageStream(_processCameraImage);
      setState(() {});
    }
  }

  void _processCameraImage(CameraImage image) async {
    if (_isBusy || !_isRecording) return;
    _isBusy = true;
    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) { _isBusy = false; return; }
    try {
      final poses = await _poseDetector.processImage(inputImage);
      List<FaceMesh> meshes = [];
      try {
        meshes = await _faceMeshDetector.processImage(inputImage);
      } catch (_) {}
      if (poses.isNotEmpty) {
        _extractCoordinates(poses.first, meshes.isNotEmpty ? meshes.first : null);
      }
    } catch (e) {
      debugPrint("Error IA: $e");
    }
    _isBusy = false;
  }

  void _extractCoordinates(Pose pose, FaceMesh? mesh) {
    final frameData = List<double>.filled(_featDim, 0.0);
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
    _currentSequence.add(frameData);
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('models/senalink_model.tflite');
      final inputShape = _interpreter!.getInputTensor(0).shape;
      final expectedInput = _seqLen * _featDim;
      if (inputShape.length < 2 || inputShape[1] != expectedInput) {
        debugPrint("Modelo incompatible: espera ${inputShape[1]}, actual $_featDim por frame");
        _interpreter = null;
      } else {
        final labelData = await rootBundle.loadString('assets/models/labels.txt');
        _labels = labelData
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();
        setState(() => _modelReady = true);
      }
    } catch (e) {
      debugPrint("Modelo no disponible: $e");
    }
  }

  String? _evaluateSequence(List<List<double>> sequence) {
    if (!_modelReady || _interpreter == null || _labels.isEmpty) return null;

    final padded = Float32List(_seqLen * _featDim);
    for (int f = 0; f < sequence.length && f < _seqLen; f++) {
      final frame = sequence[f];
      for (int i = 0; i < _featDim && i < frame.length; i++) {
        padded[f * _featDim + i] = frame[i].toDouble();
      }
    }

    final output = Float32List(_labels.length);
    try {
      _interpreter!.run(padded, output);
    } catch (e) {
      debugPrint("Error en inferencia: $e");
      return null;
    }

    double maxProb = 0.0;
    int maxIdx = 0;
    for (int i = 0; i < output.length; i++) {
      if (output[i] > maxProb) {
        maxProb = output[i];
        maxIdx = i;
      }
    }
    return maxProb > 0.3 ? _labels[maxIdx] : null;
  }

  Future<void> _uploadToFirestore() async {
    if (_currentSequence.isEmpty) return;

    final predicted = _evaluateSequence(_currentSequence);
    final bool isCorrect = predicted != null &&
        predicted.toLowerCase() == _selectedLabel.toLowerCase();
    final bool hasModel = _modelReady;

    if (hasModel && predicted != null && !isCorrect) {
      final retry = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text("Seña incorrecta"),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Se esperaba: '$_selectedLabel'"),
            Text("Se reconoció: '$predicted'"),
            const SizedBox(height: 12),
            const Text("Intenta de nuevo con más precisión.", style: TextStyle(color: Colors.orange)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("DESCARTAR", style: TextStyle(color: Colors.red))),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("SUBIR COMO EJEMPLO")),
          ],
        ),
      );
      if (retry != true) {
        setState(() => _currentSequence = []);
        return;
      }
    } else if (hasModel && isCorrect) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text("¡Bien hecho!", style: TextStyle(color: Colors.green)),
          content: Text("Se reconoció correctamente '$_selectedLabel' con la seña que realizaste."),
          actions: [
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("CONTINUAR")),
          ],
        ),
      );
    } else if (hasModel && predicted == null) {
      final retry = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text("No se reconoció"),
          content: const Text("El modelo no pudo reconocer la seña. ¿Quieres intentar de nuevo o subirla como ejemplo de entrenamiento?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("DESCARTAR", style: TextStyle(color: Colors.red))),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("SUBIR DE TODOS MODOS")),
          ],
        ),
      );
      if (retry != true) {
        setState(() => _currentSequence = []);
        return;
      }
    }

    try {
      final authProv = Provider.of<AuthProvider>(context, listen: false);
      final String userName = authProv.user?.name ?? "anonimo";

      await FirebaseFirestore.instance.collection('datasets').add({
        'usuario': userName,
        'etiqueta': _selectedLabel,
        'categoria': _selectedCategory,
        'secuencia': _currentSequence,
        'frames': _currentSequence.length,
        'fecha': FieldValue.serverTimestamp(),
      });

      setState(() {
        _sampleCount++;
        _currentSequence = [];
      });
      HapticFeedbackHelper.success();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Seña enviada a la base de datos!")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al subir")));
      }
    }
  }

  String _getSenaPath(String label) {
    final String member = _selectedCategory.split(" —").first.trim().toLowerCase();
    final String cleanLabel = label.toLowerCase()
        .replaceAll(RegExp(r'[^\w\sáéíóúñ]+'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    return "assets/senas/$member/$cleanLabel.webp";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Laboratorio SeñaLink AI")),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                if (_cameraController != null && _cameraController!.value.isInitialized)
                  FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: _cameraController!.value.previewSize!.width,
                      height: _cameraController!.value.previewSize!.height,
                      child: CameraPreview(_cameraController!),
                    ),
                  )
                else
                  Container(color: Colors.black87, child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(color: Colors.white), SizedBox(height: 12), Text("Inicializando cámara...", style: TextStyle(color: Colors.white54))]))),

                Positioned(
                  top: 20,
                  right: 20,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: AppTheme.primaryBlue, width: 2),
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Image.asset(
                        _getSenaPath(_selectedLabel),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Center(child: Text(_selectedLabel, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.grey))),
                      ),
                    ),
                  ),
                ),

                if (_isRecording)
                  Positioned(top: 20, left: 20, child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)), child: const Text("GRABANDO...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: "Tu Pack Asignado"),
                    items: _dataset.keys.map((k) => DropdownMenuItem(value: k, child: Text(k, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (val) => setState(() { _selectedCategory = val!; _selectedLabel = _dataset[val]![0]; }),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _selectedLabel,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: "Palabra o Frase a grabar"),
                    items: _dataset[_selectedCategory]!.map((l) => DropdownMenuItem(value: l, child: Text(l, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (val) => setState(() => _selectedLabel = val!),
                  ),
                  const Spacer(),
                  Text("Muestras enviadas: $_sampleCount", style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                  if (_modelReady)
                    const Text("Modo evaluación: activo", style: TextStyle(fontSize: 11, color: Colors.green))
                  else
                    const Text("Modelo no disponible - solo recolección", style: TextStyle(fontSize: 11, color: Colors.orange)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _switchCamera,
                        child: Container(
                          width: 50, height: 50, margin: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(color: Colors.white24, shape: BoxShape.circle, border: Border.all(color: Colors.white38)),
                          child: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 24),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          if (_isRecording) {
                            setState(() => _isRecording = false);
                            _uploadToFirestore();
                          } else {
                            setState(() { _isRecording = true; _currentSequence = []; });
                            HapticFeedbackHelper.light();
                          }
                        },
                        child: Container(width: 80, height: 80, decoration: BoxDecoration(color: _isRecording ? Colors.red : AppTheme.primaryBlue, shape: BoxShape.circle, boxShadow: [BoxShadow(color: (_isRecording ? Colors.red : AppTheme.primaryBlue).withOpacity(0.3), blurRadius: 10, spreadRadius: 2)]), child: Icon(_isRecording ? Icons.stop : Icons.fiber_manual_record, color: Colors.white, size: 30)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(_isRecording ? "Presiona para detener y guardar" : "Presiona para grabar", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;
    final plane = image.planes.first;
    return InputImage.fromBytes(bytes: plane.bytes, metadata: InputImageMetadata(size: Size(image.width.toDouble(), image.height.toDouble()), rotation: InputImageRotation.rotation0deg, format: format, bytesPerRow: plane.bytesPerRow));
  }

  @override
  void dispose() { _cameraController?.dispose(); _poseDetector.close(); _faceMeshDetector.close(); super.dispose(); }
}
