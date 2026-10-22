import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:todo_to_json/models/app_state.dart';
import 'package:todo_to_json/models/todo.dart';
import 'package:todo_to_json/services/database_service.dart';
import 'package:todo_to_json/services/storage_service.dart';
import 'package:uuid/uuid.dart';

/// Provides the service used for JSON-based file persistence.
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

/// Provides the service used for SQLite database persistence.
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

/// Represents the persistence strategy type.
enum StorageType {
  /// Persistence via JSON file.
  json,

  /// Persistence via SQLite database.
  sqlite,
}

/// Manages the runtime selection of the storage persistence strategy.
class StorageTypeNotifier extends Notifier<StorageType> {
  @override
  StorageType build() {
    unawaited(_loadPreference());
    return StorageType.json;
  }

  Future<void> _loadPreference() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/storage_preference.txt');
      if (file.existsSync()) {
        final content = await file.readAsString();
        if (content.trim() == 'sqlite') {
          state = StorageType.sqlite;
        }
      }
    } on Object catch (_) {}
  }

  /// Updates the active storage type.
  void selectType(StorageType type) {
    if (state != type) {
      state = type;
      unawaited(_savePreference(type));
    }
  }

  Future<void> _savePreference(StorageType type) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/storage_preference.txt');
      await file.writeAsString(type.name);
    } on Object catch (_) {}
  }

  /// Toggles between JSON and SQLite storage.
  void toggle() {
    selectType(
      state == StorageType.json ? StorageType.sqlite : StorageType.json,
    );
  }
}

/// Provides the current storage persistence strategy type.
final storageTypeProvider =
    NotifierProvider<StorageTypeNotifier, StorageType>(
  StorageTypeNotifier.new,
);

/// Abstract interface for app state management.
abstract class AppStateNotifier extends Notifier<AppState> {
  /// Loads persisted state into memory.
  Future<void> loadState();

  /// Adds a new todo with the specified [text].
  void addTodo(String text);

  /// Toggles the completion state of the todo with the given [id].
  void toggleTodo(String id);

  /// Toggles selection of the todo with the given [id].
  void toggleSelection(String id);

  /// Clears all currently selected todos.
  void clearSelection();

  /// Deletes all selected todos from state and persistence.
  void deleteSelectedTodos();

  /// Toggles between light and dark mode.
  void toggleDarkMode();

  /// Toggles whether deletion requires confirmation.
  void toggleDeletionConfirmation();
}

/// Persists application state by serializing the entire state tree into a JSON file.
class JsonAppStateNotifier extends AppStateNotifier {
  late final StorageService _storageService;
  final _uuid = const Uuid();
  final List<AppState Function(AppState)> _pendingUpdates = [];
  Future<void>? _loadFuture;
  bool _isRestoring = true;
  bool _hasPendingPersistentChanges = false;

  @override
  AppState build() {
    _storageService = ref.watch(storageServiceProvider);
    unawaited(loadState());
    return AppState();
  }

  @override
  Future<void> loadState() => _loadFuture ??= _restoreState();

  Future<void> _restoreState() async {
    try {
      final loadedState = await _storageService.loadAppState();
      if (loadedState != null) {
        state = _pendingUpdates.fold(loadedState, (current, update) {
          return update(current);
        });
      }
    } on Object catch (error, stackTrace) {
      developer.log(
        'Error loading JSON app state; keeping current state.',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _isRestoring = false;
      final shouldSave = _hasPendingPersistentChanges;
      _pendingUpdates.clear();
      _hasPendingPersistentChanges = false;
      if (shouldSave) {
        await saveState();
      }
    }
  }

  /// Saves the full state into the JSON file.
  Future<void> saveState() async {
    try {
      await _storageService.saveAppState(state);
    } on Object catch (error, stackTrace) {
      developer.log(
        'Error saving app state to JSON.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _updateState(
    AppState Function(AppState) update, {
    bool persist = false,
  }) {
    state = update(state);
    if (_isRestoring) {
      _pendingUpdates.add(update);
      _hasPendingPersistentChanges |= persist;
    } else if (persist) {
      unawaited(saveState());
    }
  }

  @override
  void addTodo(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final newTodo = Todo(
      id: _uuid.v4(),
      text: trimmed,
    );
    _updateState(
      (current) => current.copyWith(todos: [...current.todos, newTodo]),
      persist: true,
    );
  }

  @override
  void toggleTodo(String id) {
    _updateState(
      (current) => current.copyWith(
        todos: current.todos.map((todo) {
          if (todo.id == id) {
            return todo.copyWith(isCompleted: !todo.isCompleted);
          }
          return todo;
        }).toList(),
      ),
      persist: true,
    );
  }

  @override
  void toggleSelection(String id) {
    _updateState((current) {
      final selectedIds = Set<String>.from(current.selectedTodoIds);
      if (selectedIds.contains(id)) {
        selectedIds.remove(id);
      } else {
        selectedIds.add(id);
      }
      return current.copyWith(selectedTodoIds: selectedIds);
    });
  }

  @override
  void clearSelection() {
    _updateState((current) => current.copyWith(selectedTodoIds: const {}));
  }

  @override
  void deleteSelectedTodos() {
    final selectedIds = Set<String>.from(state.selectedTodoIds);
    if (selectedIds.isEmpty) return;

    _updateState(
      (current) => current.copyWith(
        todos: current.todos
            .where((todo) => !selectedIds.contains(todo.id))
            .toList(),
        selectedTodoIds: const {},
      ),
      persist: true,
    );
  }

  @override
  void toggleDarkMode() {
    _updateState(
      (current) => current.copyWith(isDarkMode: !current.isDarkMode),
      persist: true,
    );
  }

  @override
  void toggleDeletionConfirmation() {
    _updateState(
      (current) => current.copyWith(
        asksForDeletionConfirmation: !current.asksForDeletionConfirmation,
      ),
      persist: true,
    );
  }
}

/// Persists application state in a local SQLite database using granular SQL queries.
class SqliteAppStateNotifier extends AppStateNotifier {
  late final DatabaseService _databaseService;
  final _uuid = const Uuid();

  @override
  AppState build() {
    _databaseService = ref.watch(databaseServiceProvider);
    unawaited(loadState());
    return AppState();
  }

  @override
  Future<void> loadState() async {
    try {
      final todos = await _databaseService.getTodos();
      final settings = await _databaseService.getSettings();

      state = state.copyWith(
        todos: todos,
        isDarkMode: settings['isDarkMode'] as bool? ?? state.isDarkMode,
        asksForDeletionConfirmation:
            settings['asksForDeletionConfirmation'] as bool? ??
            state.asksForDeletionConfirmation,
      );
    } on Object catch (error, stackTrace) {
      developer.log(
        'Error loading state from SQLite database.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  void addTodo(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final newTodo = Todo(
      id: _uuid.v4(),
      text: trimmed,
    );

    state = state.copyWith(todos: [...state.todos, newTodo]);
    unawaited(_databaseService.insertTodo(newTodo));
  }

  @override
  void toggleTodo(String id) {
    Todo? updatedTodo;
    final updatedTodos = state.todos.map((todo) {
      if (todo.id == id) {
        updatedTodo = todo.copyWith(isCompleted: !todo.isCompleted);
        return updatedTodo!;
      }
      return todo;
    }).toList();

    if (updatedTodo != null) {
      state = state.copyWith(todos: updatedTodos);
      unawaited(_databaseService.updateTodo(updatedTodo!));
    }
  }

  @override
  void toggleSelection(String id) {
    final selectedIds = Set<String>.from(state.selectedTodoIds);
    if (selectedIds.contains(id)) {
      selectedIds.remove(id);
    } else {
      selectedIds.add(id);
    }
    state = state.copyWith(selectedTodoIds: selectedIds);
  }

  @override
  void clearSelection() {
    state = state.copyWith(selectedTodoIds: const {});
  }

  @override
  void deleteSelectedTodos() {
    final selectedIds = state.selectedTodoIds.toList();
    if (selectedIds.isEmpty) return;

    state = state.copyWith(
      todos: state.todos
          .where((todo) => !state.selectedTodoIds.contains(todo.id))
          .toList(),
      selectedTodoIds: const {},
    );

    unawaited(_databaseService.deleteTodos(selectedIds));
  }

  @override
  void toggleDarkMode() {
    final newMode = !state.isDarkMode;
    state = state.copyWith(isDarkMode: newMode);
    unawaited(_databaseService.setSetting('isDarkMode', newMode.toString()));
  }

  @override
  void toggleDeletionConfirmation() {
    final newVal = !state.asksForDeletionConfirmation;
    state = state.copyWith(asksForDeletionConfirmation: newVal);
    unawaited(
      _databaseService.setSetting(
        'asksForDeletionConfirmation',
        newVal.toString(),
      ),
    );
  }
}

/// Provides dedicated access to the JSON-backed app state notifier.
final jsonAppStateProvider =
    NotifierProvider<JsonAppStateNotifier, AppState>(
  JsonAppStateNotifier.new,
);

/// Provides dedicated access to the SQLite-backed app state notifier.
final sqliteAppStateProvider =
    NotifierProvider<SqliteAppStateNotifier, AppState>(
  SqliteAppStateNotifier.new,
);

/// Adapts and delegates app state operations to the active persistence strategy.
class DynamicAppStateNotifier extends AppStateNotifier {
  @override
  AppState build() {
    final storageType = ref.watch(storageTypeProvider);
    final targetProvider = storageType == StorageType.json
        ? jsonAppStateProvider
        : sqliteAppStateProvider;

    ref.listen<AppState>(targetProvider, (previous, next) {
      state = next;
    });

    return ref.watch(targetProvider);
  }

  AppStateNotifier get _delegate {
    final storageType = ref.read(storageTypeProvider);
    return storageType == StorageType.json
        ? ref.read(jsonAppStateProvider.notifier)
        : ref.read(sqliteAppStateProvider.notifier);
  }

  @override
  Future<void> loadState() => _delegate.loadState();

  @override
  void addTodo(String text) => _delegate.addTodo(text);

  @override
  void toggleTodo(String id) => _delegate.toggleTodo(id);

  @override
  void toggleSelection(String id) => _delegate.toggleSelection(id);

  @override
  void clearSelection() => _delegate.clearSelection();

  @override
  void deleteSelectedTodos() => _delegate.deleteSelectedTodos();

  @override
  void toggleDarkMode() => _delegate.toggleDarkMode();

  @override
  void toggleDeletionConfirmation() => _delegate.toggleDeletionConfirmation();
}

/// Provides application state and notifier abstraction.
final appStateProvider = NotifierProvider<AppStateNotifier, AppState>(
  DynamicAppStateNotifier.new,
);
