import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class PictogramDatabase {
  static final PictogramDatabase instance = PictogramDatabase._init();
  static Database? _database;

  PictogramDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('senalink_pro_v105.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE pictograms (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId TEXT NOT NULL,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        imagePath TEXT NOT NULL,
        usageCount INTEGER DEFAULT 0,
        isFavorite INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE phrases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId TEXT NOT NULL,
        text TEXT NOT NULL,
        category TEXT NOT NULL,
        isFavorite INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE translation_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId TEXT NOT NULL,
        text TEXT NOT NULL,
        type TEXT NOT NULL,
        createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  // ==========================================
  // PICTOGRAMAS
  // ==========================================

  Future<void> setupDefaultPictograms(String uid) async {
    final db = await instance.database;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM pictograms WHERE userId = ?', [uid]));

    if (count == 0) {
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
      for (var p in pics) await db.insert('pictograms', p);

      final List<Map<String, dynamic>> phrases = [
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
      for (var ph in phrases) await db.insert('phrases', ph);
    }
  }

  Future<int> addPictogram(String uid, String title, String category, String imagePath) async {
    final db = await instance.database;
    return await db.insert('pictograms', {
      'userId': uid,
      'title': title,
      'category': category,
      'imagePath': imagePath,
      'isFavorite': 0
    });
  }

  Future<List<Map<String, dynamic>>> getPictograms(String uid, {String? search}) async {
    final db = await instance.database;
    if (search != null && search.isNotEmpty) {
      return await db.query('pictograms', where: 'userId = ? AND title LIKE ?', whereArgs: [uid, '%$search%']);
    }
    return await db.query('pictograms', where: 'userId = ?', whereArgs: [uid]);
  }

  Future<List<Map<String, dynamic>>> getFavoritePictograms(String uid) async {
    final db = await instance.database;
    return await db.query('pictograms', where: 'userId = ? AND isFavorite = 1', whereArgs: [uid]);
  }

  Future<void> togglePictogramFavorite(int id, bool isFavorite) async {
    final db = await instance.database;
    await db.update('pictograms', {'isFavorite': isFavorite ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> incrementUsage(int id) async {
    final db = await instance.database;
    await db.rawUpdate('UPDATE pictograms SET usageCount = usageCount + 1 WHERE id = ?', [id]);
  }

  Future<int> deletePictogram(int id) async {
    final db = await instance.database;
    return await db.delete('pictograms', where: 'id = ?', whereArgs: [id]);
  }

  // ==========================================
  // FRASES
  // ==========================================

  Future<void> savePhrase(String uid, String text, String category, {int isFav = 1}) async {
    final db = await instance.database;
    await db.insert('phrases', {'userId': uid, 'text': text, 'category': category, 'isFavorite': isFav});
  }

  Future<List<Map<String, dynamic>>> getPhrasesByCategory(String uid, String category) async {
    final db = await instance.database;
    return await db.query('phrases', where: 'userId = ? AND category = ?', whereArgs: [uid, category]);
  }

  Future<List<Map<String, dynamic>>> getFavoritePhrases(String uid) async {
    final db = await instance.database;
    return await db.query('phrases', where: 'userId = ? AND isFavorite = 1', whereArgs: [uid]);
  }

  Future<void> togglePhraseFavorite(int id, bool isFavorite) async {
    final db = await instance.database;
    await db.update('phrases', {'isFavorite': isFavorite ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updatePhraseText(int id, String newText) async {
    final db = await instance.database;
    return await db.update('phrases', {'text': newText}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deletePhrase(int id) async {
    final db = await instance.database;
    return await db.delete('phrases', where: 'id = ?', whereArgs: [id]);
  }

  // ==========================================
  // HISTORIAL DE TRADUCCIONES
  // ==========================================

  Future<void> saveTranslation(String uid, String text, String type) async {
    if (text.isEmpty) return;
    final db = await instance.database;
    await db.insert('translation_history', {'userId': uid, 'text': text, 'type': type});
  }

  Future<List<Map<String, dynamic>>> getTranslationHistory(String uid) async {
    final db = await instance.database;
    return await db.query('translation_history', where: 'userId = ?', orderBy: 'createdAt DESC', limit: 50);
  }

  Future<int> deleteTranslation(int id) async {
    final db = await instance.database;
    return await db.delete('translation_history', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearTranslationHistory(String uid) async {
    final db = await instance.database;
    await db.delete('translation_history', where: 'userId = ?', whereArgs: [uid]);
  }
}
