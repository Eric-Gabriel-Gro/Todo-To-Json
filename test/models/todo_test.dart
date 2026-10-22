import 'package:flutter_test/flutter_test.dart';
import 'package:todo_to_json/models/todo.dart';

void main() {
  test('Todo JSON round-trip preserves all fields', () {
    const todo = Todo(id: 'todo-1', text: 'Call mom', isCompleted: true);

    expect(Todo.fromJson(todo.toJson()), todo);
  });

  test('Todo.fromJson defaults isCompleted to false when omitted', () {
    final todo = Todo.fromJson(const {'id': 'todo-1', 'text': 'Call mom'});
    expect(todo.isCompleted, isFalse);
  });

  test('Todo.fromJson rejects a non-boolean completion value', () {
    expect(
      () => Todo.fromJson(const {
        'id': 'todo-1',
        'text': 'Call mom',
        'isCompleted': 'false',
      }),
      throwsA(isA<TypeError>()),
    );
  });
}
