import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/form_model.dart';
import 'security_service.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;
  final SecurityService _security = SecurityService();

  Future<Database?> get database async {
    if (kIsWeb) {
      // SQLite doesn't work on web, return null and use in-memory storage
      return null;
    }
    if (_database != null) {
      try {
        // Verify database is still open and writable
        await _database!.execute('SELECT 1');
        return _database!;
      } catch (e) {
        // Database might be closed, reset and reinitialize
        _database = null;
      }
    }
    try {
      _database = await _initDatabase();
      return _database!;
    } catch (e) {
      print('Error getting database: $e');
      _database = null;
      return null;
    }
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      throw UnsupportedError('SQLite not supported on web');
    }
    try {
      String path = join(await getDatabasesPath(), 'fillora.db');
      return await openDatabase(
        path,
        version: 2,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (e) {
      print('Error initializing database: $e');
      rethrow;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE forms(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        formData TEXT NOT NULL,
        status TEXT NOT NULL,
        progress REAL NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT,
        submittedAt TEXT,
        formType TEXT,
        tags TEXT,
        templateId TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE templates(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        category TEXT,
        formStructure TEXT NOT NULL,
        icon TEXT,
        createdAt TEXT NOT NULL,
        usageCount INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE documents(
        id TEXT PRIMARY KEY,
        formId TEXT,
        fileName TEXT NOT NULL,
        filePath TEXT NOT NULL,
        fileType TEXT NOT NULL,
        uploadedAt TEXT NOT NULL,
        FOREIGN KEY (formId) REFERENCES forms(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE user_preferences(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add icon column to templates table
      try {
        await db.execute('ALTER TABLE templates ADD COLUMN icon TEXT');
      } catch (e) {
        // Column might already exist, ignore error
        print('Error adding icon column (might already exist): $e');
      }
    }
  }

  // In-memory storage for web (fallback)
  static final List<FormModel> _inMemoryForms = [];
  static final List<Map<String, dynamic>> _inMemoryTemplates = [];
  static final Map<String, String> _inMemoryPreferences = {};

  // Form operations
  Future<String> insertForm(FormModel form) async {
    if (kIsWeb) {
      final index = _inMemoryForms.indexWhere((f) => f.id == form.id);
      if (index >= 0) {
        _inMemoryForms[index] = form;
      } else {
        _inMemoryForms.add(form);
      }
      return form.id;
    }
    try {
      final db = await database;
      if (db == null) {
        // Fallback to in-memory storage if database is null
        final index = _inMemoryForms.indexWhere((f) => f.id == form.id);
        if (index >= 0) {
          _inMemoryForms[index] = form;
        } else {
          _inMemoryForms.add(form);
        }
        return form.id;
      }
      
      // SECURITY: Encrypt sensitive data before saving
      final formMap = form.toMap();
      if (formMap['formData'] != null) {
        formMap['formData'] = await _security.encryptData(formMap['formData'] as String);
      }
      if (formMap['description'] != null) {
        formMap['description'] = await _security.encryptData(formMap['description'] as String);
      }
      
      await db.insert('forms', formMap, conflictAlgorithm: ConflictAlgorithm.replace);
      return form.id;
    } catch (e) {
      print('Error inserting form: $e');
      // Fallback to in-memory storage on error
      final index = _inMemoryForms.indexWhere((f) => f.id == form.id);
      if (index >= 0) {
        _inMemoryForms[index] = form;
      } else {
        _inMemoryForms.add(form);
      }
      return form.id;
    }
  }

  Future<List<FormModel>> getAllForms() async {
    if (kIsWeb) {
      // Return in-memory forms sorted by date
      final sorted = List<FormModel>.from(_inMemoryForms);
      sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return sorted;
    }
    try {
      final db = await database;
      if (db == null) return [];
      final List<Map<String, dynamic>> maps = await db.query('forms', orderBy: 'createdAt DESC');
      
      // SECURITY: Decrypt sensitive data after loading
      final decryptedList = <FormModel>[];
      for (final map in maps) {
        final mutableMap = Map<String, dynamic>.from(map);
        if (mutableMap['formData'] != null) {
          mutableMap['formData'] = await _security.decryptData(mutableMap['formData'] as String);
        }
        if (mutableMap['description'] != null) {
          mutableMap['description'] = await _security.decryptData(mutableMap['description'] as String);
        }
        decryptedList.add(FormModel.fromMap(mutableMap));
      }
      return decryptedList;
    } catch (e) {
      print('Error getting forms: $e');
      return [];
    }
  }

  Future<FormModel?> getFormById(String id) async {
    if (kIsWeb) {
      try {
        return _inMemoryForms.firstWhere((f) => f.id == id);
      } catch (e) {
        return null;
      }
    }
    final db = await database;
    if (db == null) return null;
    final List<Map<String, dynamic>> maps = await db.query(
      'forms',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    
    // SECURITY: Decrypt sensitive data after loading
    final mutableMap = Map<String, dynamic>.from(maps.first);
    if (mutableMap['formData'] != null) {
      mutableMap['formData'] = await _security.decryptData(mutableMap['formData'] as String);
    }
    if (mutableMap['description'] != null) {
      mutableMap['description'] = await _security.decryptData(mutableMap['description'] as String);
    }
    
    return FormModel.fromMap(mutableMap);
  }

  Future<int> updateForm(FormModel form) async {
    if (kIsWeb) {
      final index = _inMemoryForms.indexWhere((f) => f.id == form.id);
      if (index >= 0) {
        _inMemoryForms[index] = form.copyWith(updatedAt: DateTime.now());
        return 1;
      }
      return 0;
    }
    final db = await database;
    if (db == null) return 0;
    
    // SECURITY: Encrypt sensitive data before updating
    final formMap = form.copyWith(updatedAt: DateTime.now()).toMap();
    if (formMap['formData'] != null) {
      formMap['formData'] = await _security.encryptData(formMap['formData'] as String);
    }
    if (formMap['description'] != null) {
      formMap['description'] = await _security.encryptData(formMap['description'] as String);
    }
    
    return await db.update(
      'forms',
      formMap,
      where: 'id = ?',
      whereArgs: [form.id],
    );
  }

  Future<int> deleteForm(String id) async {
    if (kIsWeb) {
      final beforeLength = _inMemoryForms.length;
      _inMemoryForms.removeWhere((f) => f.id == id);
      final afterLength = _inMemoryForms.length;
      return beforeLength > afterLength ? 1 : 0;
    }
    final db = await database;
    if (db == null) return 0;
    return await db.delete('forms', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<FormModel>> getFormsByStatus(String status) async {
    if (kIsWeb) {
      final filtered = _inMemoryForms.where((f) => f.status == status).toList();
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return filtered;
    }
    final db = await database;
    if (db == null) return [];
    final List<Map<String, dynamic>> maps = await db.query(
      'forms',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) => FormModel.fromMap(maps[i]));
  }

  // Template operations
  Future<String> insertTemplate(Map<String, dynamic> template) async {
    if (kIsWeb) {
      final index = _inMemoryTemplates.indexWhere((t) => t['id'] == template['id']);
      if (index >= 0) {
        _inMemoryTemplates[index] = template;
      } else {
        _inMemoryTemplates.add(template);
      }
      return template['id'] as String;
    }
    try {
      final db = await database;
      if (db == null) return template['id'] as String;
      
      // SECURITY: Encrypt sensitive data before saving
      final templateMap = Map<String, dynamic>.from(template);
      if (templateMap['formStructure'] != null) {
        templateMap['formStructure'] = await _security.encryptData(templateMap['formStructure'] as String);
      }
      if (templateMap['description'] != null) {
        templateMap['description'] = await _security.encryptData(templateMap['description'] as String);
      }
      
      await db.insert('templates', templateMap, conflictAlgorithm: ConflictAlgorithm.replace);
      return template['id'] as String;
    } catch (e) {
      print('Error inserting template: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAllTemplates() async {
    if (kIsWeb) {
      // Return in-memory templates sorted by usage count
      final sorted = List<Map<String, dynamic>>.from(_inMemoryTemplates);
      sorted.sort((a, b) => (b['usageCount'] as int? ?? 0).compareTo(a['usageCount'] as int? ?? 0));
      return sorted;
    }
    try {
      final db = await database;
      if (db == null) return [];
      final List<Map<String, dynamic>> maps = await db.query('templates', orderBy: 'usageCount DESC');
      
      // SECURITY: Decrypt sensitive data after loading
      final decryptedList = <Map<String, dynamic>>[];
      for (final map in maps) {
        final mutableMap = Map<String, dynamic>.from(map);
        if (mutableMap['formStructure'] != null) {
          mutableMap['formStructure'] = await _security.decryptData(mutableMap['formStructure'] as String);
        }
        if (mutableMap['description'] != null) {
          mutableMap['description'] = await _security.decryptData(mutableMap['description'] as String);
        }
        decryptedList.add(mutableMap);
      }
      return decryptedList;
    } catch (e) {
      print('Error getting templates: $e');
      return [];
    }
  }

  // Preferences
  Future<void> setPreference(String key, String value) async {
    if (kIsWeb) {
      _inMemoryPreferences[key] = value;
      return;
    }
    final db = await database;
    if (db == null) return;
    await db.insert(
      'user_preferences',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getPreference(String key) async {
    if (kIsWeb) {
      return _inMemoryPreferences[key];
    }
    final db = await database;
    if (db == null) return null;
    final List<Map<String, dynamic>> maps = await db.query(
      'user_preferences',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isEmpty) return null;
    return maps.first['value'] as String;
  }

  Future<void> close() async {
    if (kIsWeb) return;
    final db = await database;
    if (db != null) {
      await db.close();
    }
  }
}

