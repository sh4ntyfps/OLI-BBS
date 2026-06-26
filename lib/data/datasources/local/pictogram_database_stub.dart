import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PictogramDatabase {
  static final PictogramDatabase instance = PictogramDatabase._init();
  PictogramDatabase._init();

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  // ==========================================
  // PICTOGRAMAS
  // ==========================================

  List<Map<String, dynamic>> _decodeToList(dynamic decoded) {
    if (decoded is List) {
      return List<Map<String, dynamic>>.from(decoded);
    }
    if (decoded is Map && decoded.containsKey('pictograms')) {
      return List<Map<String, dynamic>>.from(decoded['pictograms'] as List);
    }
    return [];
  }

  Future<void> setupDefaultPictograms(String uid) async {
    final prefs = await _prefs;
    final picKey = 'pictograms_$uid';

    final existingPics = prefs.getString(picKey);
    final needsPics = existingPics == null || jsonDecode(existingPics) is Map;

    if (needsPics) {
      final List<Map<String, dynamic>> pics = [
        {'userId': uid, 'title': 'Yo', 'category': 'Persona', 'imagePath': 'assets/pictograms/personas/yo.png'},
        {'userId': uid, 'title': 'Tú', 'category': 'Persona', 'imagePath': 'assets/pictograms/personas/tu.png'},
        {'userId': uid, 'title': 'Nosotros', 'category': 'Persona', 'imagePath': 'assets/pictograms/personas/nosotros.png'},
        {'userId': uid, 'title': 'Mamá', 'category': 'Persona', 'imagePath': 'assets/pictograms/personas/mama.png'},
        {'userId': uid, 'title': 'Papá', 'category': 'Persona', 'imagePath': 'assets/pictograms/personas/papa.png'},
        {'userId': uid, 'title': 'Abuelo', 'category': 'Persona', 'imagePath': 'assets/pictograms/personas/abuelo.png'},
        {'userId': uid, 'title': 'Abuela', 'category': 'Persona', 'imagePath': 'assets/pictograms/personas/abuela.png'},
        {'userId': uid, 'title': 'Hermano', 'category': 'Persona', 'imagePath': 'assets/pictograms/personas/hermano.png'},
        {'userId': uid, 'title': 'Hermana', 'category': 'Persona', 'imagePath': 'assets/pictograms/personas/hermana.png'},
        {'userId': uid, 'title': 'Hijo', 'category': 'Persona', 'imagePath': 'assets/pictograms/personas/hijo.png'},
        {'userId': uid, 'title': 'Hija', 'category': 'Persona', 'imagePath': 'assets/pictograms/personas/hija.png'},
        {'userId': uid, 'title': 'Amigo/a', 'category': 'Persona', 'imagePath': 'assets/pictograms/personas/amigo.png'},
        {'userId': uid, 'title': 'Médico', 'category': 'Persona', 'imagePath': 'assets/pictograms/personas/medico.png'},
        {'userId': uid, 'title': 'Profesor', 'category': 'Persona', 'imagePath': 'assets/pictograms/personas/profesor.png'},
        {'userId': uid, 'title': 'Quiero', 'category': 'Acción', 'imagePath': 'assets/pictograms/acciones/quiero.png'},
        {'userId': uid, 'title': 'Necesito', 'category': 'Acción', 'imagePath': 'assets/pictograms/acciones/necesito.png'},
        {'userId': uid, 'title': 'Comer', 'category': 'Acción', 'imagePath': 'assets/pictograms/acciones/comer.png'},
        {'userId': uid, 'title': 'Beber', 'category': 'Acción', 'imagePath': 'assets/pictograms/acciones/beber.png'},
        {'userId': uid, 'title': 'Dormir', 'category': 'Acción', 'imagePath': 'assets/pictograms/acciones/dormir.png'},
        {'userId': uid, 'title': 'Ayudar', 'category': 'Acción', 'imagePath': 'assets/pictograms/acciones/ayuda_v.png'},
        {'userId': uid, 'title': 'Baño', 'category': 'Necesidades', 'imagePath': 'assets/pictograms/necesidades/bano.png'},
        {'userId': uid, 'title': 'Agua', 'category': 'Necesidades', 'imagePath': 'assets/pictograms/necesidades/agua.png'},
        {'userId': uid, 'title': 'Comida', 'category': 'Necesidades', 'imagePath': 'assets/pictograms/necesidades/comida.png'},
        {'userId': uid, 'title': 'Gafas', 'category': 'Necesidades', 'imagePath': 'assets/pictograms/necesidades/gafas.png'},
        {'userId': uid, 'title': 'Casa', 'category': 'Lugar', 'imagePath': 'assets/pictograms/lugares/casa.png'},
        {'userId': uid, 'title': 'Hospital', 'category': 'Lugar', 'imagePath': 'assets/pictograms/lugares/hospital.png'},
        {'userId': uid, 'title': 'Feliz', 'category': 'Emoción', 'imagePath': 'assets/pictograms/emociones/feliz.png'},
        {'userId': uid, 'title': 'Triste', 'category': 'Emoción', 'imagePath': 'assets/pictograms/emociones/triste.png'},
        {'userId': uid, 'title': '¡Ayuda!', 'category': 'Emergencia', 'imagePath': 'assets/pictograms/emergencia/ayuda.png'},
      ];
      await prefs.setString(picKey, jsonEncode(pics));
    }

    final phraseKey = 'phrases_$uid';
    final existingPhrases = prefs.getString(phraseKey);
    if (existingPhrases == null) {
      final List<Map<String, dynamic>> defaultPhrases = [
        {'userId': uid, 'text': '¿Cómo estás?', 'category': 'General', 'isFavorite': 1},
        {'userId': uid, 'text': 'Muchas gracias', 'category': 'General', 'isFavorite': 0},
        {'userId': uid, 'text': 'Por favor', 'category': 'General', 'isFavorite': 0},
        {'userId': uid, 'text': 'De nada', 'category': 'General', 'isFavorite': 0},
        {'userId': uid, 'text': 'Un gusto conocerte', 'category': 'General', 'isFavorite': 0},
        {'userId': uid, 'text': 'Buenos días', 'category': 'General', 'isFavorite': 0},
        {'userId': uid, 'text': 'Buenas tardes', 'category': 'General', 'isFavorite': 0},
        {'userId': uid, 'text': 'Buenas noches', 'category': 'General', 'isFavorite': 0},
        {'userId': uid, 'text': 'Hasta luego', 'category': 'General', 'isFavorite': 0},
        {'userId': uid, 'text': 'Nos vemos pronto', 'category': 'General', 'isFavorite': 0},
        {'userId': uid, 'text': '¿Puedes ayudarme?', 'category': 'General', 'isFavorite': 0},
        {'userId': uid, 'text': 'Estoy bien, gracias', 'category': 'General', 'isFavorite': 0},
        {'userId': uid, 'text': 'Necesito un médico', 'category': 'Salud', 'isFavorite': 1},
        {'userId': uid, 'text': 'Me duele la cabeza', 'category': 'Salud', 'isFavorite': 0},
        {'userId': uid, 'text': 'Tengo fiebre', 'category': 'Salud', 'isFavorite': 0},
        {'userId': uid, 'text': 'Llama una ambulancia', 'category': 'Salud', 'isFavorite': 1},
        {'userId': uid, 'text': 'Necesito una farmacia', 'category': 'Salud', 'isFavorite': 0},
        {'userId': uid, 'text': 'Soy alérgico a...', 'category': 'Salud', 'isFavorite': 0},
        {'userId': uid, 'text': '¿Dónde está el hospital?', 'category': 'Salud', 'isFavorite': 0},
        {'userId': uid, 'text': 'Necesito mis medicinas', 'category': 'Salud', 'isFavorite': 0},
        {'userId': uid, 'text': 'Me siento mareado', 'category': 'Salud', 'isFavorite': 0},
        {'userId': uid, 'text': '¿Puedes llevarme al doctor?', 'category': 'Salud', 'isFavorite': 0},
        {'userId': uid, 'text': 'Tengo hambre', 'category': 'Comida', 'isFavorite': 0},
        {'userId': uid, 'text': 'Quiero agua, por favor', 'category': 'Comida', 'isFavorite': 0},
        {'userId': uid, 'text': 'La cuenta, por favor', 'category': 'Comida', 'isFavorite': 0},
        {'userId': uid, 'text': '¿Qué recomiendas?', 'category': 'Comida', 'isFavorite': 0},
        {'userId': uid, 'text': 'Está delicioso', 'category': 'Comida', 'isFavorite': 0},
        {'userId': uid, 'text': 'Sin azúcar, por favor', 'category': 'Comida', 'isFavorite': 0},
        {'userId': uid, 'text': '¿Tienen menú vegetariano?', 'category': 'Comida', 'isFavorite': 0},
        {'userId': uid, 'text': '¡Ayuda!', 'category': 'Emergencia', 'isFavorite': 1},
        {'userId': uid, 'text': 'Llama al 911', 'category': 'Emergencia', 'isFavorite': 1},
        {'userId': uid, 'text': 'Estoy perdido/a', 'category': 'Emergencia', 'isFavorite': 0},
        {'userId': uid, 'text': 'Necesito ayuda urgente', 'category': 'Emergencia', 'isFavorite': 1},
        {'userId': uid, 'text': 'Hay una emergencia', 'category': 'Emergencia', 'isFavorite': 0},
        {'userId': uid, 'text': '¿Puedes llamar por mí?', 'category': 'Emergencia', 'isFavorite': 0},
      ];
      await prefs.setString(phraseKey, jsonEncode(defaultPhrases));
    }
  }

  Future<List<Map<String, dynamic>>> _getData(String uid) async {
    final prefs = await _prefs;
    final key = 'pictograms_$uid';
    final raw = prefs.getString(key);
    if (raw == null) return [];
    final decoded = jsonDecode(raw);
    return _decodeToList(decoded);
  }

  Future<void> _saveData(String uid, List<Map<String, dynamic>> data) async {
    final prefs = await _prefs;
    await prefs.setString('pictograms_$uid', jsonEncode(data));
  }

  Future<int> addPictogram(String uid, String title, String category, String imagePath) async {
    final data = await _getData(uid);
    final int newId = data.isEmpty ? 1 : (data.last['id'] as int) + 1;
    data.add({'id': newId, 'userId': uid, 'title': title, 'category': category, 'imagePath': imagePath, 'usageCount': 0, 'isFavorite': 0});
    await _saveData(uid, data);
    return newId;
  }

  Future<List<Map<String, dynamic>>> getPictograms(String uid, {String? search}) async {
    final data = await _getData(uid);
    if (search != null && search.isNotEmpty) {
      return data.where((p) => (p['title'] as String).toLowerCase().contains(search.toLowerCase())).toList();
    }
    return data;
  }

  Future<List<Map<String, dynamic>>> getFavoritePictograms(String uid) async {
    final data = await _getData(uid);
    return data.where((p) => p['isFavorite'] == 1).toList();
  }

  Future<void> togglePictogramFavorite(int id, bool isFavorite) async {
    final prefs = await _prefs;
    final allKeys = prefs.getKeys().where((k) => k.startsWith('pictograms_'));
    for (final key in allKeys) {
      final raw = prefs.getString(key);
      if (raw == null) continue;
      final data = _decodeToList(jsonDecode(raw));
      final idx = data.indexWhere((p) => p['id'] == id);
      if (idx != -1) {
        data[idx]['isFavorite'] = isFavorite ? 1 : 0;
        await prefs.setString(key, jsonEncode(data));
        break;
      }
    }
  }

  Future<void> incrementUsage(int id) async {
    final prefs = await _prefs;
    final allKeys = prefs.getKeys().where((k) => k.startsWith('pictograms_'));
    for (final key in allKeys) {
      final raw = prefs.getString(key);
      if (raw == null) continue;
      final data = _decodeToList(jsonDecode(raw));
      final idx = data.indexWhere((p) => p['id'] == id);
      if (idx != -1) {
        data[idx]['usageCount'] = (data[idx]['usageCount'] as int? ?? 0) + 1;
        await prefs.setString(key, jsonEncode(data));
        break;
      }
    }
  }

  Future<int> deletePictogram(int id) async {
    final prefs = await _prefs;
    final allKeys = prefs.getKeys().where((k) => k.startsWith('pictograms_'));
    for (final key in allKeys) {
      final raw = prefs.getString(key);
      if (raw == null) continue;
      final data = _decodeToList(jsonDecode(raw));
      final before = data.length;
      data.removeWhere((p) => p['id'] == id);
      if (data.length < before) {
        await prefs.setString(key, jsonEncode(data));
        return before - data.length;
      }
    }
    return 0;
  }

  // ==========================================
  // FRASES
  // ==========================================

  Future<List<Map<String, dynamic>>> _getPhraseData(String uid) async {
    final prefs = await _prefs;
    final raw = prefs.getString('phrases_$uid');
    if (raw == null) return [];
    final decoded = jsonDecode(raw);
    return _decodeToList(decoded);
  }

  Future<void> _savePhraseData(String uid, List<Map<String, dynamic>> data) async {
    final prefs = await _prefs;
    await prefs.setString('phrases_$uid', jsonEncode(data));
  }

  Future<void> savePhrase(String uid, String text, String category, {int isFav = 1}) async {
    final data = await _getPhraseData(uid);
    final int newId = data.isEmpty ? 1 : (data.last['id'] as int) + 1;
    data.add({'id': newId, 'userId': uid, 'text': text, 'category': category, 'isFavorite': isFav});
    await _savePhraseData(uid, data);
  }

  Future<List<Map<String, dynamic>>> getPhrasesByCategory(String uid, String category) async {
    final data = await _getPhraseData(uid);
    return data.where((p) => p['category'] == category).toList();
  }

  Future<List<Map<String, dynamic>>> getFavoritePhrases(String uid) async {
    final data = await _getPhraseData(uid);
    return data.where((p) => p['isFavorite'] == 1).toList();
  }

  Future<void> togglePhraseFavorite(int id, bool isFavorite) async {
    final prefs = await _prefs;
    final allKeys = prefs.getKeys().where((k) => k.startsWith('phrases_'));
    for (final key in allKeys) {
      final raw = prefs.getString(key);
      if (raw == null) continue;
      final data = _decodeToList(jsonDecode(raw));
      final idx = data.indexWhere((p) => p['id'] == id);
      if (idx != -1) {
        data[idx]['isFavorite'] = isFavorite ? 1 : 0;
        await prefs.setString(key, jsonEncode(data));
        break;
      }
    }
  }

  Future<int> updatePhraseText(int id, String newText) async {
    final prefs = await _prefs;
    final allKeys = prefs.getKeys().where((k) => k.startsWith('phrases_'));
    for (final key in allKeys) {
      final raw = prefs.getString(key);
      if (raw == null) continue;
      final data = _decodeToList(jsonDecode(raw));
      final idx = data.indexWhere((p) => p['id'] == id);
      if (idx != -1) {
        data[idx]['text'] = newText;
        await prefs.setString(key, jsonEncode(data));
        return 1;
      }
    }
    return 0;
  }

  Future<int> deletePhrase(int id) async {
    final prefs = await _prefs;
    final allKeys = prefs.getKeys().where((k) => k.startsWith('phrases_'));
    for (final key in allKeys) {
      final raw = prefs.getString(key);
      if (raw == null) continue;
      final data = _decodeToList(jsonDecode(raw));
      final before = data.length;
      data.removeWhere((p) => p['id'] == id);
      if (data.length < before) {
        await prefs.setString(key, jsonEncode(data));
        return before - data.length;
      }
    }
    return 0;
  }

  // ==========================================
  // HISTORIAL DE TRADUCCIONES
  // ==========================================

  Future<void> saveTranslation(String uid, String text, String type) async {}
  Future<List<Map<String, dynamic>>> getTranslationHistory(String uid) async => [];
  Future<int> deleteTranslation(int id) async => 0;
  Future<void> clearTranslationHistory(String uid) async {}
}
