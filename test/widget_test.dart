import 'dart:async';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_to_json/main.dart';
import 'package:todo_to_json/models/app_state.dart';
import 'package:todo_to_json/models/todo.dart';
import 'package:todo_to_json/providers/app_state_provider.dart';
import 'package:todo_to_json/services/storage_service.dart';

void main() {
  testWidgets('adds todos, toggles completion, and persists state', (
    tester,
  ) async {
    final storageService = _MemoryStorageService();
    await tester.pumpWidget(_testApp(storageService));

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Buy groceries');
    await tester.pump();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Buy groceries'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(storageService.savedState!.todos.single.isCompleted, isTrue);
  });

  testWidgets('deletes selected todos after confirmation', (tester) async {
    final storageService = _MemoryStorageService(
      initialState: AppState(
        todos: const [Todo(id: 'todo-1', text: 'Call mom')],
      ),
    );
    await tester.pumpWidget(_testApp(storageService));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Call mom'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();

    expect(find.text('Confirm Deletion'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Call mom'), findsNothing);
    expect(storageService.savedState!.todos, isEmpty);
  });

  testWidgets('settings switches storage backend', (tester) async {
    final storageService = _MemoryStorageService();
    await tester.pumpWidget(_testApp(storageService));
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    expect(find.text('Storage Backend'), findsOneWidget);
    await tester.tap(find.text('SQLite'));
    await tester.pumpAndSettle();
    expect(find.text('SQLite Database (todo_app.db)'), findsOneWidget);
  });

  testWidgets('settings update theme and deletion confirmation', (
    tester,
  ) async {
    final storageService = _MemoryStorageService();
    await tester.pumpWidget(_testApp(storageService));

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark Mode'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    expect(storageService.savedState!.isDarkMode, isTrue);

    await tester.tap(find.text('Ask for Deletion Confirmation'));
    await tester.pumpAndSettle();

    expect(storageService.savedState!.asksForDeletionConfirmation, isFalse);
  });

  test('AppState equality and hash code use collection contents', () {
    final first = AppState(
      todos: const [Todo(id: 'todo-1', text: 'Call mom')],
      selectedTodoIds: const {'todo-1'},
    );
    final second = AppState(
      todos: const [Todo(id: 'todo-1', text: 'Call mom')],
      selectedTodoIds: const {'todo-1'},
    );

    expect(first, second);
    expect(first.hashCode, second.hashCode);
  });

  test('AppState JSON round-trip restores persisted data only', () {
    final source = AppState(
      todos: const [Todo(id: 'todo-1', text: 'Call mom')],
      isDarkMode: true,
      asksForDeletionConfirmation: false,
      selectedTodoIds: const {'todo-1'},
    );
    final json =
        jsonDecode(jsonEncode(source.toJson())) as Map<String, dynamic>;
    final restored = AppState.fromJson(json);

    expect(
      restored,
      source.copyWith(selectedTodoIds: const {}),
    );
    expect(json.containsKey('selectedTodoIds'), isFalse);
  });

  test('preserves changes made while saved state is loading', () async {
    final storageService = _DelayedStorageService();
    final container = ProviderContainer(
      overrides: [
        storageServiceProvider.overrideWithValue(storageService),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(appStateProvider.notifier)
      ..addTodo('Walk dog');
    storageService.loadCompleter.complete(
      AppState(
        todos: const [Todo(id: 'saved-1', text: 'Call mom')],
      ),
    );
    await notifier.loadState();

    expect(
      container.read(appStateProvider).todos.map((todo) => todo.text),
      containsAll(['Call mom', 'Walk dog']),
    );
    expect(storageService.savedState!.todos, hasLength(2));
  });

  test('AppState defensively copies and protects its collections', () {
    final todos = <Todo>[const Todo(id: 'todo-1', text: 'Call mom')];
    final selectedTodoIds = <String>{'todo-1'};
    final state = AppState(
      todos: todos,
      selectedTodoIds: selectedTodoIds,
    );

    todos.clear();
    selectedTodoIds.clear();

    expect(state.todos, hasLength(1));
    expect(state.selectedTodoIds, contains('todo-1'));
    expect(
      () => state.todos.add(const Todo(id: 'todo-2', text: 'Walk dog')),
      throwsUnsupportedError,
    );
    expect(() => state.selectedTodoIds.add('todo-2'), throwsUnsupportedError);
  });
}

Widget _testApp(_MemoryStorageService storageService) {
  return ProviderScope(
    overrides: [
      storageServiceProvider.overrideWithValue(storageService),
    ],
    child: const TodoApp(),
  );
}

class _MemoryStorageService extends StorageService {
  _MemoryStorageService({AppState? initialState}) : savedState = initialState;

  AppState? savedState;

  @override
  Future<AppState?> loadAppState() async => savedState;

  @override
  Future<void> saveAppState(AppState state) async {
    savedState = state;
  }
}

class _DelayedStorageService extends _MemoryStorageService {
  final Completer<AppState?> loadCompleter = Completer<AppState?>();

  @override
  Future<AppState?> loadAppState() => loadCompleter.future;
}
