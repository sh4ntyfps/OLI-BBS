import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../data/datasources/local/pictogram_database.dart';
import '../../widgets/shimmer_loading.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/tts_helper.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';

class PictogramsPage extends StatefulWidget {
  const PictogramsPage({super.key});

  @override
  State<PictogramsPage> createState() => _PictogramsPageState();
}

class _PictogramsPageState extends State<PictogramsPage> {
  // Se cambia de 'late' a nullable para evitar el LateInitializationError al inicio
  Future<List<Map<String, dynamic>>>? _pictogramsFuture;
  bool _showOnlyFavorites = false;
  final List<String> _sentence = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Usamos addPostFrameCallback para asegurar que el contexto esté disponible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initData();
    });
  }

  void _initData() async {
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user != null) {
      // Cargamos los pictogramas base si es la primera vez
      await PictogramDatabase.instance.setupDefaultPictograms(auth.user!.id);
      _refreshPictograms();
    }
  }

  void _refreshPictograms() {
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user != null) {
      setState(() {
        _pictogramsFuture = _showOnlyFavorites 
            ? PictogramDatabase.instance.getFavoritePictograms(auth.user!.id)
            : PictogramDatabase.instance.getPictograms(auth.user!.id, search: _searchController.text);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(settings.translate('pictograms'), style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(_showOnlyFavorites ? Icons.favorite : Icons.favorite_border, 
                color: _showOnlyFavorites ? Colors.red : null),
            onPressed: () {
              setState(() => _showOnlyFavorites = !_showOnlyFavorites);
              _refreshPictograms();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 🔍 BUSCADOR DE PICTOGRAMAS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => _refreshPictograms(),
              decoration: InputDecoration(
                hintText: 'Buscar palabra (ej: comer, baño)...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.primaryBlue),
                filled: true,
                fillColor: isDark ? AppTheme.darkSurface : Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
          ),

          // ✍️ BARRA DE CONSTRUCCIÓN DE ORACIÓN
          _buildSentenceBar(settings),
          
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _pictogramsFuture,
              builder: (context, snapshot) {
                // Si aún no hay future o está cargando, mostramos shimmer
                if (_pictogramsFuture == null || snapshot.connectionState == ConnectionState.waiting) {
                  return _buildShimmerGrid();
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline_rounded, size: 60, color: Colors.grey.withAlpha(77)),
                        const SizedBox(height: 10),
                        const Text('Error al cargar datos', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 60, color: Colors.grey.withAlpha(77)),
                        const SizedBox(height: 10),
                        Text(_showOnlyFavorites ? 'No tienes favoritos' : 'No se encontró esa palabra',
                          style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }
                final pictograms = snapshot.data!;
                return GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 240, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 0.9,
                  ),
                  itemCount: pictograms.length,
                  itemBuilder: (context, index) => _buildPictogramCard(pictograms[index], settings),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSentenceBar(SettingsProvider settings) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primaryBlue.withAlpha(40), width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _sentence.isEmpty 
                  ? Text("  Toca las imágenes para armar una frase...", style: TextStyle(color: Colors.grey[400], fontSize: 13))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _sentence.map((word) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          margin: const EdgeInsets.only(right: 5),
                          decoration: BoxDecoration(color: AppTheme.primaryBlue.withAlpha(20), borderRadius: BorderRadius.circular(10)),
                          child: Text(word, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue, fontSize: 13)),
                        )).toList(),
                      ),
                    ),
              ),
              if (_sentence.isNotEmpty)
                IconButton(icon: const Icon(Icons.stars_rounded, color: Colors.orange, size: 28), onPressed: _saveBuiltSentence),
              if (_sentence.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.backspace_rounded, color: Colors.redAccent, size: 22), 
                  onPressed: () => setState(() {
                    if (_sentence.isNotEmpty) {
                      _sentence.removeLast(); // Corregido: removeLast() en lugar de removeAt() sin parámetros
                    }
                  })
                ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _sentence.clear()), 
                icon: const Icon(Icons.delete_sweep_rounded, color: Colors.grey), 
                label: const Text("Limpiar", style: TextStyle(color: Colors.grey))
              ),
              ElevatedButton.icon(
                onPressed: () {
                  if (_sentence.isNotEmpty) {
                    TtsHelper.speak(_sentence.join(" "), settings.locale.languageCode);
                    HapticFeedbackHelper.success();
                  }
                },
                icon: const Icon(Icons.volume_up_rounded),
                label: const Text("HABLAR FRASE"),
                style: ElevatedButton.styleFrom(minimumSize: const Size(180, 45)),
              ),
            ],
          )
        ],
      ),
    );
  }

  Future<void> _saveBuiltSentence() async {
    if (_sentence.isEmpty) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user == null) return;
    
    String fullText = _sentence.join(" ");
    await PictogramDatabase.instance.savePhrase(auth.user!.id, fullText, 'Mis Frases', isFav: 1);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Frase guardada en favoritos')));
    HapticFeedbackHelper.success();
  }

  Widget _buildShimmerGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 240, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 0.9),
      itemCount: 4,
      itemBuilder: (context, index) => const ShimmerLoading.rectangular(height: 150),
    );
  }

  Widget _buildPictogramCard(Map<String, dynamic> item, SettingsProvider settings) {
    bool isFav = item['isFavorite'] == 1;
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8, offset: const Offset(0, 4))]),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
             setState(() => _sentence.add(item['title']));
             HapticFeedbackHelper.light();
          },
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12), 
                      child: Image.asset(
                        item['imagePath'], 
                        fit: BoxFit.contain, 
                        errorBuilder: (c, e, s) => Icon(Icons.image_rounded, color: Colors.grey[200], size: 40)
                      )
                    )
                  ),
                  Container(
                    width: double.infinity, 
                    padding: const EdgeInsets.symmetric(vertical: 8), 
                    decoration: BoxDecoration(color: AppTheme.primaryBlue.withAlpha(15), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24))), 
                    child: Text(item['title'], textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))
                  ),
                ],
              ),
              Positioned(
                top: 2, 
                right: 2, 
                child: IconButton(
                  icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : Colors.grey, size: 18), 
                  onPressed: () async {
                    await PictogramDatabase.instance.togglePictogramFavorite(item['id'], !isFav);
                    _refreshPictograms();
                  }
                )
              ),
            ],
          ),
        ),
      ),
    );
  }
}
