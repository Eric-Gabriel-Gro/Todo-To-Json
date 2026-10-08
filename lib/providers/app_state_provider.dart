import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_to_json/models/app_state.dart';
import 'package:todo_to_json/models/todo.dart';
import 'package:todo_to_json/services/storage_service.dart';
import 'package:uuid/uuid.dart';

/// Provides the service used to persist application state.
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

/// Manages todo data, settings, and persistence.
class AppStateNotifier extends Notifier<AppState> {
  late final StorageService _storageService;
  final _uuid = const Uuid();
  final List<AppState Function(AppState)> _pendingUpdates = [];
  Future<void>? _loadFuture;
  bool _isRestoring = true;
  bool _hasPendingPersistentChanges = false;

  /// Builds the default state and starts restoring persisted state.
  @override
  AppState build() {
    _storageService = ref.watch(storageServiceProvider);
    unawaited(loadState());
    return AppState();
  }

  /// Loads saved state and reapplies any changes made while loading.
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
        'Error loading app state; keeping the current state.',
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

  /// Saves the current application state.
  Future<void> saveState() async {
    try {
      await _storageService.saveAppState(state);
    } on Object catch (error, stackTrace) {
      developer.log(
        'Error saving app state.',
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

  /// Adds a non-empty todo after trimming surrounding whitespace.
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

  /// Toggles completion for the todo with the given [id].
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

  /// Toggles selection for the todo with the given [id].
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

  /// Clears all selected todos.
  void clearSelection() {
    _updateState((current) => current.copyWith(selectedTodoIds: const {}));
  }

  /// Deletes selected todos and persists the updated list.
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

  /// Toggles dark mode and persists the updated setting.
  void toggleDarkMode() {
    _updateState(
      (current) => current.copyWith(isDarkMode: !current.isDarkMode),
      persist: true,
    );
  }

  /// Toggles deletion confirmation and persists the updated setting.
  void toggleDeletionConfirmation() {
    _updateState(
      (current) => current.copyWith(
        asksForDeletionConfirmation: !current.asksForDeletionConfirmation,
      ),
      persist: true,
    );
  }
}

/// Provides application state and its notifier.
final appStateProvider = NotifierProvider<AppStateNotifier, AppState>(() {
  return AppStateNotifier();
});
