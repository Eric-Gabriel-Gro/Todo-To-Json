import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'package:todo_to_json/models/app_state.dart';

/// Persists and restores the application's state.
class StorageService {
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/todo_app_state.json');
  }

  /// Saves the application's current state to disk.
  Future<void> saveAppState(AppState state) async {
    final file = await _localFile;
    final jsonString = jsonEncode(state.toJson());
    await file.writeAsString(jsonString);
  }

  /// Loads the application's saved state, or returns `null` when unavailable.
  Future<AppState?> loadAppState() async {
    try {
      final file = await _localFile;
      if (!file.existsSync()) {
        return null;
      }
      final jsonString = await file.readAsString();
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      return AppState.fromJson(jsonMap);
    } on Object catch (error, stackTrace) {
      developer.log(
        'Error loading app state; using default state.',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}
