import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:todo_to_json/models/todo.dart';

/// Provides SQLite database operations for persisting todos and settings.
class DatabaseService {
  Database? _db;

  /// Returns the singleton database instance, initializing it if necessary.
  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'todo_app.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE todos (
            id TEXT PRIMARY KEY,
            text TEXT NOT NULL,
            isCompleted INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
    );
  }

  /// Retrieves all saved todos from the database.
  Future<List<Todo>> getTodos() async {
    try {
      final db = await database;
      final maps = await db.query('todos');
      return maps.map((map) {
        return Todo(
          id: map['id']! as String,
          text: map['text']! as String,
          isCompleted: (map['isCompleted']! as int) == 1,
        );
      }).toList();
    } on Object catch (error, stackTrace) {
      developer.log(
        'Failed to get todos from SQLite',
        error: error,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Inserts a new todo record into the database.
  Future<void> insertTodo(Todo todo) async {
    try {
      final db = await database;
      await db.insert(
        'todos',
        {
          'id': todo.id,
          'text': todo.text,
          'isCompleted': todo.isCompleted ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } on Object catch (error, stackTrace) {
      developer.log(
        'Failed to insert todo in SQLite',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Updates an existing todo record in the database.
  Future<void> updateTodo(Todo todo) async {
    try {
      final db = await database;
      await db.update(
        'todos',
        {
          'text': todo.text,
          'isCompleted': todo.isCompleted ? 1 : 0,
        },
        where: 'id = ?',
        whereArgs: [todo.id],
      );
    } on Object catch (error, stackTrace) {
      developer.log(
        'Failed to update todo in SQLite',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Deletes todos matching the provided [ids].
  Future<void> deleteTodos(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      final db = await database;
      final placeholders = List.filled(ids.length, '?').join(',');
      await db.delete(
        'todos',
        where: 'id IN ($placeholders)',
        whereArgs: ids,
      );
    } on Object catch (error, stackTrace) {
      developer.log(
        'Failed to delete todos in SQLite',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Loads application settings.
  Future<Map<String, dynamic>> getSettings() async {
    try {
      final db = await database;
      final maps = await db.query('settings');
      final result = <String, dynamic>{};
      for (final row in maps) {
        final key = row['key']! as String;
        final val = row['value']! as String;
        if (val == 'true') {
          result[key] = true;
        } else if (val == 'false') {
          result[key] = false;
        } else {
          result[key] = val;
        }
      }
      return result;
    } on Object catch (error, stackTrace) {
      developer.log(
        'Failed to load settings from SQLite',
        error: error,
        stackTrace: stackTrace,
      );
      return {};
    }
  }

  /// Saves a single setting key-value pair.
  Future<void> setSetting(String key, String value) async {
    try {
      final db = await database;
      await db.insert(
        'settings',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } on Object catch (error, stackTrace) {
      developer.log(
        'Failed to set setting in SQLite',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
