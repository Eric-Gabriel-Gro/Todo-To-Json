import 'package:flutter/foundation.dart';

/// A single immutable task in the todo list.
@immutable
class Todo {
  /// The unique identifier of this todo.
  final String id;

  /// The todo's display text.
  final String text;

  /// Whether this todo has been completed.
  final bool isCompleted;

  /// Creates a todo with the given [id] and [text].
  const Todo({
    required this.id,
    required this.text,
    this.isCompleted = false,
  });

  /// Returns a copy of this todo with the supplied values changed.
  Todo copyWith({
    String? id,
    String? text,
    bool? isCompleted,
  }) {
    return Todo(
      id: id ?? this.id,
      text: text ?? this.text,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  /// Converts this todo to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isCompleted': isCompleted,
    };
  }

  /// Creates a todo from its JSON representation.
  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'] as String,
      text: json['text'] as String,
      isCompleted: json['isCompleted'] as bool,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Todo &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          text == other.text &&
          isCompleted == other.isCompleted;

  @override
  int get hashCode => id.hashCode ^ text.hashCode ^ isCompleted.hashCode;
}
