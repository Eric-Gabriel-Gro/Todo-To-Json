import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_to_json/models/app_state.dart';
import 'package:todo_to_json/models/todo.dart';
import 'package:todo_to_json/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel(
    'plugins.flutter.io/path_provider',
  );

  test('saves and loads application state from a JSON file', () async {
    final documentsDirectory = await Directory.systemTemp.createTemp(
      'todo-to-json-',
    );
    final setMockMethodCallHandler = TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler;
    setMockMethodCallHandler(pathProviderChannel, (call) async {
      expect(call.method, 'getApplicationDocumentsDirectory');
      return documentsDirectory.path;
    });

    addTearDown(() async {
      setMockMethodCallHandler(pathProviderChannel, null);
      await documentsDirectory.delete(recursive: true);
    });

    final storageService = StorageService();
    expect(await storageService.loadAppState(), isNull);

    final state = AppState(
      todos: const [
        Todo(id: 'todo-1', text: 'Call mom', isCompleted: true),
      ],
      isDarkMode: true,
      asksForDeletionConfirmation: false,
      selectedTodoIds: const {'todo-1'},
    );

    await storageService.saveAppState(state);

    final savedFile = File('${documentsDirectory.path}/todo_app_state.json');
    expect(savedFile.existsSync(), isTrue);
    expect(
      jsonDecode(await savedFile.readAsString()),
      state.toJson(),
    );
    expect(
      await storageService.loadAppState(),
      state.copyWith(selectedTodoIds: const {}),
    );
  });
}
