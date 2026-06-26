import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../core/utils/tts_helper.dart';
import '../../../data/datasources/local/pictogram_database.dart';
import '../../providers/settings_provider.dart';
import '../../providers/auth_provider.dart';

class QuickPhrasesPage extends StatefulWidget {
  const QuickPhrasesPage({super.key});

  @override
  State<QuickPhrasesPage> createState() => _QuickPhrasesPageState();
}

class _QuickPhrasesPageState extends State<QuickPhrasesPage> {
  String _selectedCategory = 'General';
  bool _showOnlyFavorites = false;
  final List<String> _categories = ['General', 'Salud', 'Comida', 'Emergencia'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.user != null) {
        await PictogramDatabase.instance.setupDefaultPictograms(auth.user!.id);
        if (mounted) setState(() {});
      }
    });
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
        content: Text(settings.translate('instr_quick_phrases')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  void _confirmDelete(int id, String text) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Eliminar frase"),
        content: Text("¿Estás seguro de que quieres eliminar \"$text\"?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          TextButton(
            onPressed: () async {
              await PictogramDatabase.instance.deletePhrase(id);
              if (mounted) {
                Navigator.pop(context);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Frase eliminada"))
                );
              }
            },
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddPhraseDialog(String uid) {
    final textController = TextEditingController();
    String selectedCategory = _categories.first;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Nueva frase"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "Escribe tu frase aquí",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: InputDecoration(
                  labelText: "Categoría",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                ),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setDialogState(() => selectedCategory = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
            ElevatedButton(
              onPressed: () async {
                final text = textController.text.trim();
                if (text.isEmpty) return;
                await PictogramDatabase.instance.savePhrase(uid, text, selectedCategory);
                if (ctx.mounted) Navigator.pop(ctx);
                setState(() {});
                HapticFeedbackHelper.success();
              },
              child: const Text("Guardar"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final authProv = Provider.of<AuthProvider>(context);
    final isSpanish = settings.locale.languageCode == 'es';
    final uid = authProv.user?.id ?? '';

    return Scaffold(
      floatingActionButton: uid.isNotEmpty ? FloatingActionButton(
        onPressed: () => _showAddPhraseDialog(uid),
        backgroundColor: AppTheme.primaryBlue,
        child: const Icon(Icons.add, color: Colors.white),
      ) : null,
      appBar: AppBar(
        title: Text(isSpanish ? 'Frases Rápidas' : 'Quick Phrases'),
        actions: [
          IconButton(
            icon: Icon(_showOnlyFavorites ? Icons.favorite : Icons.favorite_border, 
                color: _showOnlyFavorites ? Colors.red : null),
            onPressed: () => setState(() => _showOnlyFavorites = !_showOnlyFavorites),
          ),
          IconButton(
            icon: const Icon(Icons.lightbulb_outline_rounded),
            onPressed: () => _showHelp(settings),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_showOnlyFavorites)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: ['General', 'Salud', 'Comida', 'Emergencia', 'Mis Frases'].map((cat) {
                  bool isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (val) => setState(() => _selectedCategory = cat),
                      selectedColor: AppTheme.primaryBlue.withAlpha(50),
                    ),
                  );
                }).toList(),
              ),
            ),
          Expanded(
            child: uid.isEmpty 
              ? const Center(child: Text("Inicia sesión para ver tus frases"))
              : FutureBuilder<List<Map<String, dynamic>>>(
                  future: (_showOnlyFavorites || _selectedCategory == 'Mis Frases')
                      ? PictogramDatabase.instance.getFavoritePhrases(uid)
                      : PictogramDatabase.instance.getPhrasesByCategory(uid, _selectedCategory),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    final phrases = snapshot.data ?? [];
                    
                    if (phrases.isEmpty) {
                      return Center(
                        child: Text(
                          (_showOnlyFavorites || _selectedCategory == 'Mis Frases')
                              ? "No tienes frases favoritas\nMarca frases con ♥ para verlas aquí"
                              : "No hay frases en esta categoría"),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: phrases.length,
                      itemBuilder: (context, index) {
                        final item = phrases[index];
                        bool isFav = item['isFavorite'] == 1;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            title: Text(item['text'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            leading: IconButton(
                              icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, 
                                  color: isFav ? Colors.red : Colors.grey),
                              onPressed: () async {
                                await PictogramDatabase.instance.togglePhraseFavorite(item['id'], !isFav);
                                setState(() {});
                              },
                            ),
                            trailing: const Icon(Icons.volume_up, color: AppTheme.primaryBlue),
                            onTap: () {
                              HapticFeedbackHelper.light();
                              TtsHelper.speak(item['text'], settings.locale.languageCode);
                            },
                            onLongPress: () => _confirmDelete(item['id'], item['text']),
                          ),
                        );
                      },
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}
