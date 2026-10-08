import 'package:flutter/foundation.dart';
import 'package:todo_to_json/models/todo.dart';

/// The immutable state of the application.
@immutable
class AppState {
  /// The todos currently tracked by the application state.
  final List<Todo> todos;

  /// Whether the application is currently in dark mode.
  final bool isDarkMode;

  /// Whether the application asks for confirmation before deleting a todo.
  final bool asksForDeletionConfirmation;

  /// The identifiers of todos currently selected by the application.
  final Set<String> selectedTodoIds;

  /// Creates application state with the provided values.
  AppState({
    List<Todo> todos = const [],
    this.isDarkMode = false,
    this.asksForDeletionConfirmation = true,
    Set<String> selectedTodoIds = const {},
  }) : todos = List.unmodifiable(todos),
       selectedTodoIds = Set.unmodifiable(selectedTodoIds);

  /// Returns a copy of this state with the provided values updated.
  AppState copyWith({
    List<Todo>? todos,
    bool? isDarkMode,
    bool? asksForDeletionConfirmation,
    Set<String>? selectedTodoIds,
  }) {
    return AppState(
      todos: todos ?? this.todos,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      asksForDeletionConfirmation:
          asksForDeletionConfirmation ?? this.asksForDeletionConfirmation,
      selectedTodoIds: selectedTodoIds ?? this.selectedTodoIds,
    );
  }

  /// Returns a JSON-compatible representation of this application state.
  Map<String, dynamic> toJson() {
    return {
      'todos': todos.map((todo) => todo.toJson()).toList(),
      'isDarkMode': isDarkMode,
      'asksForDeletionConfirmation': asksForDeletionConfirmation,
    };
  }

  /// Creates application state from its JSON representation.
  factory AppState.fromJson(Map<String, dynamic> json) {
    return AppState(
      todos: (json['todos'] as List<dynamic>)
          .map((todoJson) => Todo.fromJson(todoJson as Map<String, dynamic>))
          .toList(),
      isDarkMode: json['isDarkMode'] as bool? ?? false,
      asksForDeletionConfirmation:
          json['asksForDeletionConfirmation'] as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppState &&
          runtimeType == other.runtimeType &&
          listEquals(todos, other.todos) &&
          isDarkMode == other.isDarkMode &&
          asksForDeletionConfirmation == other.asksForDeletionConfirmation &&
          setEquals(selectedTodoIds, other.selectedTodoIds);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(todos),
    isDarkMode,
    asksForDeletionConfirmation,
    Object.hashAllUnordered(selectedTodoIds),
  );
}
