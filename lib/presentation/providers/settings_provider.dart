import 'package:flutter/material.dart';

enum DisabilityType { hearing, speech, both }

class SettingsProvider with ChangeNotifier {
  double _fontSizeMultiplier = 1.0;
  Locale _locale = const Locale('es');
  ThemeMode _themeMode = ThemeMode.light;
  String _emergencyContact = "972913326";
  String? _profilePhotoPath;
  bool _shakeSOSEnabled = false;
  DisabilityType _disabilityType = DisabilityType.both;

  double get fontSizeMultiplier => _fontSizeMultiplier;
  Locale get locale => _locale;
  ThemeMode get themeMode => _themeMode;
  String get emergencyContact => _emergencyContact;
  String? get profilePhotoPath => _profilePhotoPath;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get shakeSOSEnabled => _shakeSOSEnabled;

  void setFontSize(double value) {
    _fontSizeMultiplier = value;
    notifyListeners();
  }

  void setLocale(Locale locale) {
    _locale = locale;
    notifyListeners();
  }

  void toggleTheme(bool isOn) {
    _themeMode = isOn ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void setEmergencyContact(String contact) {
    _emergencyContact = contact;
    notifyListeners();
  }

  void setProfilePhoto(String path) {
    _profilePhotoPath = path;
    notifyListeners();
  }

  void toggleShakeSOS(bool value) {
    _shakeSOSEnabled = value;
    notifyListeners();
  }

  DisabilityType get disabilityType => _disabilityType;

  void setDisabilityType(DisabilityType type) {
    _disabilityType = type;
    notifyListeners();
  }

  String get disabilityLabel {
    switch (_disabilityType) {
      case DisabilityType.hearing: return 'Sordo';
      case DisabilityType.speech: return 'Mudo';
      case DisabilityType.both: return 'Sordomudo';
    }
  }

  String get disabilityDescription {
    switch (_disabilityType) {
      case DisabilityType.hearing: return 'Escucho pero no puedo hablar';
      case DisabilityType.speech: return 'Hablo pero no puedo escuchar';
      case DisabilityType.both: return 'No puedo escuchar ni hablar';
    }
  }

  String translate(String key) {
    final Map<String, Map<String, String>> localizedValues = {
      'es': {
        'welcome': 'Comunicación inclusiva\npara todos',
        'how_to_help': '¿Cómo quieres\ncomunicarte hoy?',
        'pictograms': 'Pictogramas',
        'quick_phrases': 'Frases',
        'conversar': 'Conversar',
        'video_features': 'Funciones de Video',
        'subtitles': 'Subtítulos',
        'face_to_face': 'Cara a Cara',
        'sign_ia': 'Señas IA',
        'sos_button': 'Botón SOS',
        'emergency_desc': 'Envía alerta a:',
        'profile': 'Perfil',
        'settings': 'Ajustes',
        'community': 'Comunidad',
        'conversing': 'Conversación',
        'online': 'En línea',
        'hold_to_talk': 'MANTÉN PARA HABLAR',
        'release_to_send': 'SUELTA PARA ENVIAR',
        'listening': 'Escuchando...',
        'dark_mode': 'Modo Oscuro',
        'font_size': 'Tamaño de fuente',
        'language': 'Idioma de la App',
        'security': 'Seguridad',
        'emergency_contact': 'Contacto de Emergencia',
        'sign_out': 'Cerrar Sesión',
        'edit_contact': 'Editar Contacto SOS',
        'enter_phone': 'Ingresa el número de WhatsApp',
        'cancel': 'Cancelar',
        'save': 'Guardar',
        'add': 'Agregar',
        'my_friends': 'Mis Amigos',
        'scan_qr': 'Escanear código QR',
        'enter_manually': 'Ingresar código manualmente',
        'waiting_sign': 'Esperando señas...',
        'no_hands': 'No se detectan manos',
        'hello': '¡HOLA!',
        'thank_you': '¡GRACIAS!',
        'help': '¡AYUDA!',
        'detecting': 'Procesando...',
        'sound_alert_title': 'Alertas de Sonido',
        'f2f_instruction': 'Coloca el celular entre ambos',
        'listening_hint': 'Escuchando...',
        'login_now': 'Iniciar Sesión',
        'register_button': 'Crear Cuenta',
        'email': 'Correo electrónico',
        'password': 'Contraseña',
        'fill_fields': 'Por favor, llena todos los campos',
        'no_account': '¿No tienes cuenta? ',
        'create_account': 'Crear una cuenta',
        'join_community': 'Únete a la comunidad SeñaLink',
        'full_name': 'Nombre Completo',
        'scan_text': 'Escanear Texto',
        'text_result': 'Texto detectado:',
        'how_to_use': 'Cómo usar',
        'instr_home': 'Bienvenido. Elige una función para empezar a comunicarte. El botón rojo SOS enviará tu ubicación por WhatsApp.',
        'instr_pictograms': 'Toca una imagen para que el celular la lea en voz alta. Úsalos para expresar necesidades rápidas.',
        'instr_chat': 'Mantén presionado el botón azul para hablar. Verás una barra que cambia de color según tu volumen de voz.',
        'instr_sound_alert': 'La app escuchará sonidos fuertes (alarmas, gritos) y te avisará con vibración y luz.',
        'instr_signs': 'Coloca tu mano frente a la cámara. IA detectará tus gestos.',
        'instr_ocr': 'Toma una foto a cualquier texto y la app lo transcribirá.',
        'instr_f2f': 'Pantalla dividida para conversar de frente.',
        'instr_subtitles': 'Subtítulos en tiempo real de lo que escuchas.',
        'instr_friends': 'Agrega amigos por QR o código.',
        'instr_profile': 'Configura tu cuenta y contacto SOS.',
        'instr_quick_phrases': 'Lista de frases comunes categorizadas. Toca la bocina para reproducir el audio.',
        'shake_sos': 'SOS por Sacudida',
        'shake_sos_desc': 'Agita el celular para pedir ayuda',
        'web_ml_unavailable': 'No disponible en versión web',
        'web_ml_hint': 'Usa la app móvil para esta función de IA',
      },
      'en': {
        'welcome': 'Inclusive communication\nfor everyone',
        'how_to_help': 'How do you want to\ncommunicate today?',
        'pictograms': 'Pictograms',
        'quick_phrases': 'Phrases',
        'conversar': 'Chat',
        'video_features': 'Video Features',
        'subtitles': 'Subtitles',
        'face_to_face': 'Face to Face',
        'sign_ia': 'Sign IA',
        'sos_button': 'SOS Button',
        'emergency_desc': 'Send alert to:',
        'profile': 'Profile',
        'settings': 'Settings',
        'community': 'Community',
        'conversing': 'Conversation',
        'online': 'Online',
        'hold_to_talk': 'HOLD TO TALK',
        'release_to_send': 'RELEASE TO SEND',
        'listening': 'Listening...',
        'dark_mode': 'Dark Mode',
        'font_size': 'Font Size',
        'language': 'App Language',
        'security': 'Security',
        'emergency_contact': 'Emergency Contact',
        'sign_out': 'Sign Out',
        'edit_contact': 'Edit SOS Contact',
        'enter_phone': 'Enter WhatsApp number',
        'cancel': 'Cancel',
        'save': 'Save',
        'add': 'Add',
        'my_friends': 'My Friends',
        'scan_qr': 'Scan QR Code',
        'enter_manually': 'Enter code manually',
        'waiting_sign': 'Waiting for signs...',
        'no_hands': 'No hands detected',
        'hello': 'HELLO!',
        'thank_you': 'THANK YOU!',
        'help': 'HELP!',
        'detecting': 'Processing...',
        'sound_alert_title': 'Sound Alerts',
        'f2f_instruction': 'Place the phone between you',
        'listening_hint': 'Listening...',
        'login_now': 'Login Now',
        'register_button': 'Register',
        'email': 'Email Address',
        'password': 'Password',
        'fill_fields': 'Please fill all fields',
        'no_account': 'Don\'t have an account? ',
        'create_account': 'Create an Account',
        'join_community': 'Join SeñaLink community',
        'full_name': 'Full Name',
        'scan_text': 'Scan Text',
        'text_result': 'Detected text:',
        'how_to_use': 'How to use',
        'instr_home': 'Welcome. Choose a feature to start communicating.',
        'instr_pictograms': 'Tap an image to speak. Use for quick needs.',
        'instr_chat': 'Hold blue button to talk. Color bar shows volume.',
        'instr_sound_alert': 'Alerts for loud sounds (alarms, shouts).',
        'instr_signs': 'Hand gestures recognition via AI.',
        'instr_ocr': 'Transcribe text from photos.',
        'instr_f2f': 'Split screen for face-to-face chat.',
        'instr_subtitles': 'Real-time speech to text.',
        'instr_friends': 'Add friends via QR or code.',
        'instr_profile': 'Manage account and SOS contact.',
        'instr_quick_phrases': 'Categorized common phrases. Tap speaker icon to play audio.',
        'shake_sos': 'Shake for SOS',
        'shake_sos_desc': 'Shake phone to request help',
        'web_ml_unavailable': 'Not available on web version',
        'web_ml_hint': 'Use the mobile app for this AI feature',
      }
    };
    return localizedValues[_locale.languageCode]?[key] ?? key;
  }
}
