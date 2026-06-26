import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/data/all_signs.dart';
import '../../providers/settings_provider.dart';
import 'real_time_sign_detection_page.dart';

class SignLanguagePage extends StatefulWidget {
  const SignLanguagePage({super.key});

  @override
  State<SignLanguagePage> createState() => _SignLanguagePageState();
}

class _SignLanguagePageState extends State<SignLanguagePage> {
  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(settings.translate('sign_ia'), style: const TextStyle(fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.translate), text: 'Texto a Seña'),
              Tab(icon: Icon(Icons.camera_alt), text: 'Seña a Texto'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _TextToSignView(),
            RealTimeSignDetectionPage(), // El traductor por cámara que están entrenando
          ],
        ),
      ),
    );
  }
}

class _TextToSignView extends StatefulWidget {
  const _TextToSignView();

  @override
  State<_TextToSignView> createState() => _TextToSignViewState();
}

class _TextToSignViewState extends State<_TextToSignView> {
  final TextEditingController _controller = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  String _displayWord = "";   
  List<String> _sequence = [];
  int _currentIndex = 0;
  bool _isPlaying = false;
  bool _isListening = false;
  bool _isPhrase = false;
  final List<String> _misPalabras = [];

  List<String> _quickWords = [];
  final List<String> _allSigns = AllSigns.words;
  bool _showAllSigns = false;

  @override
  void initState() {
    super.initState();
    final shuffled = List<String>.from(_allSigns)..shuffle();
    _quickWords = shuffled;
  }

  // CARPETAS DE SEÑAS REALES (INTEGRANTES)
  final List<String> _memberFolders = ['santiago', 'mari', 'andre', 'carlos', 'andryck', 'cinthia', 'anahy', 'juan'];

  String _normalize(String text) {
    const withAccents = 'áéíóúüñ';
    const withoutAccents = 'aeiouun';
    String normalized = text.trim().toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
    normalized = normalized.replaceAll(RegExp(r'[^\w_]'), '');
    for (int i = 0; i < withAccents.length; i++) {
      normalized = normalized.replaceAll(withAccents[i], withoutAccents[i]);
    }
    return normalized;
  }

  void _translate() {
    if (_controller.text.trim().isEmpty) return;
    final raw = _controller.text.trim();
    final normalized = _normalize(raw);
    final words = normalized.split('_');
    
    // Check if full phrase image exists
    if (words.length > 1) {
      // Mark as multi-word sequence for display
      setState(() {
        _displayWord = normalized;
        _sequence = words;
        _isPlaying = false;
        _isPhrase = true;
      });
    } else {
      setState(() {
        _displayWord = normalized;
        _sequence = [];
        _isPlaying = false;
        _isPhrase = false;
      });
    }
    _addToMisPalabras(raw);
    HapticFeedbackHelper.light();
  }

  void _addToMisPalabras(String word) {
    final w = word.toLowerCase().trim();
    if (w.isEmpty || _misPalabras.contains(w)) return;
    setState(() {
      _misPalabras.insert(0, w);
      if (_misPalabras.length > 20) _misPalabras.removeLast();
    });
  }

  void _playWordSequence(List<String> words) {
    _currentIndex = 0;
    _isPlaying = true;
    _displayWord = words[0];
    _sequence = words;
    _tickSequence();
  }

  void _tickSequence() {
    if (!_isPlaying || _currentIndex >= _sequence.length - 1) {
      _isPlaying = false;
      return;
    }
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted || !_isPlaying) return;
      setState(() {
        _currentIndex++;
        _displayWord = _sequence[_currentIndex];
      });
      _tickSequence();
    });
  }

  Widget _buildSignDisplay() {
    if (_displayWord.isEmpty) {
      return const Icon(Icons.person_search_rounded, size: 120, color: AppTheme.primaryBlue);
    }
    // For multi-word phrases, try full phrase image first
    if (_isPhrase && !_isPlaying) {
      return _trySignImage(0, _displayWord).animate().fadeIn().scale();
    }
    // Fall back to individual word
    return _trySignImage(0, _displayWord).animate().fadeIn().scale();
  }

  Widget _trySignImage(int index, String word) {
    if (index >= _memberFolders.length) {
      return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.videocam_off_outlined, size: 80, color: Colors.grey),
        const SizedBox(height: 10),
        Text("Seña real no encontrada para: $word", textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ]);
    }
    final folder = _memberFolders[index];
    return Image.asset("assets/senas/$folder/$word.webp", fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Image.asset("assets/senas/$folder/$word.png", fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _trySignImage(index + 1, word),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 20),
          
          // RECUADRO DE IMAGEN DE SEÑA REAL (DICCIONARIO)
          Container(
            height: 320, width: double.infinity, margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.circular(24), 
              border: Border.all(color: Colors.grey[200]!, width: 2),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                _buildSignDisplay(),
                if (_displayWord.isNotEmpty)
                  Positioned(bottom: 20, child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isPlaying && _sequence.length > 1)
                        Text("${_currentIndex + 1}/${_sequence.length}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(_displayWord.toUpperCase().replaceAll('_', ' '), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                      if (_isPhrase && !_isPlaying && _sequence.length > 1)
                        TextButton.icon(
                          onPressed: () => _playWordSequence(_sequence),
                          icon: const Icon(Icons.play_arrow, size: 16),
                          label: const Text("Reproducir palabra por palabra", style: TextStyle(fontSize: 11)),
                          style: TextButton.styleFrom(foregroundColor: AppTheme.primaryBlue, padding: const EdgeInsets.symmetric(horizontal: 8)),
                        ),
                    ],
                  )),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Escribe para ver la seña real:", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  onSubmitted: (_) => _translate(),
                  decoration: InputDecoration(
                    hintText: 'Ej: Dolor, Ayuda, Casa...',
                    prefixIcon: const Icon(Icons.search, color: AppTheme.primaryBlue),
                    suffixIcon: IconButton(
                      icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: _isListening ? Colors.red : AppTheme.primaryBlue),
                      onPressed: () {}, // Conectar lógica voz si es necesario
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                ElevatedButton.icon(
                  onPressed: _translate,
                  icon: const Icon(Icons.play_circle_fill_rounded),
                  label: const Text('VER SEÑA REAL'),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60)),
                ),

                const SizedBox(height: 30),
                const Text("Accesos rápidos", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (!_showAllSigns) ...[
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _quickWords.take(20).map((w) => _buildQuickChip(w)).toList(),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => setState(() => _showAllSigns = true),
                    icon: const Icon(Icons.expand_more, size: 18),
                    label: Text("Ver las ${_allSigns.length} señas disponibles"),
                  ),
                ] else ...[
                  SizedBox(
                    height: 200,
                    child: ListView(
                      children: _allSigns.map((w) => _buildQuickChip(w)).toList(),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() => _showAllSigns = false),
                    icon: const Icon(Icons.expand_less, size: 18),
                    label: const Text("Mostrar solo accesos rápidos"),
                  ),
                ],
                if (_misPalabras.isNotEmpty) ...[
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      const Text("Mis palabras", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _misPalabras.clear()),
                        child: const Text("Limpiar", style: TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _misPalabras.map((w) => _buildQuickChip(w)).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _displayName(String word) {
    return word.replaceAll('_', ' ');
  }

  Widget _buildQuickChip(String label) {
    return ActionChip(
      label: Text(_displayName(label), style: const TextStyle(fontSize: 12)),
      onPressed: () {
        _controller.text = _displayName(label);
        _translate();
      },
    );
  }
}
