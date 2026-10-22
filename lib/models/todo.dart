import 'package:freezed_annotation/freezed_annotation.dart';

part 'todo.freezed.dart';
part 'todo.g.dart';

/// A single immutable task in the todo list generated with Freezed.
@freezed
abstract class Todo with _$Todo {
  /// Creates a todo item.
  const factory Todo({
    required String id,
    required String text,
    @Default(false) bool isCompleted,
  }) = _Todo;

  /// Creates a todo from its JSON representation.
  factory Todo.fromJson(Map<String, dynamic> json) => _$TodoFromJson(json);
}
