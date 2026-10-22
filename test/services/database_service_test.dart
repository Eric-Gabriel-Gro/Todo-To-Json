import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:todo_to_json/models/todo.dart';
import 'package:todo_to_json/services/database_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('DatabaseService CRUD operations on todos and settings', () async {
    final service = DatabaseService();

    const todo = Todo(id: 'test-1', text: 'Test DB');
    await service.insertTodo(todo);

    var todos = await service.getTodos();
    expect(todos.any((t) => t.id == 'test-1' && t.text == 'Test DB'), isTrue);

    final updated = todo.copyWith(isCompleted: true);
    await service.updateTodo(updated);

    todos = await service.getTodos();
    expect(
      todos.firstWhere((t) => t.id == 'test-1').isCompleted,
      isTrue,
    );

    await service.setSetting('isDarkMode', 'true');
    final settings = await service.getSettings();
    expect(settings['isDarkMode'], isTrue);

    await service.deleteTodos(['test-1']);
    todos = await service.getTodos();
    expect(todos.any((t) => t.id == 'test-1'), isFalse);
  });
}
