import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_to_json/providers/app_state_provider.dart';
import 'package:todo_to_json/screens/settings_screen.dart';
import 'package:todo_to_json/widgets/add_todo_dialog.dart';
import 'package:todo_to_json/widgets/todo_item.dart';

/// Displays, adds, completes, and deletes todos.
class TodoListScreen extends ConsumerWidget {
  /// Creates the todo list screen.
  const TodoListScreen({super.key});

  Future<void> _confirmDeletion(BuildContext context, WidgetRef ref) async {
    final appState = ref.read(appStateProvider);
    final notifier = ref.read(appStateProvider.notifier);

    if (!appState.asksForDeletionConfirmation) {
      notifier.deleteSelectedTodos();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text(
          'Are you sure you want to delete the selected items?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onError,
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      notifier.deleteSelectedTodos();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final notifier = ref.read(appStateProvider.notifier);
    final isSelectionMode = appState.selectedTodoIds.isNotEmpty;

    return PopScope(
      canPop: !isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (isSelectionMode) {
          notifier.clearSelection();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            isSelectionMode
                ? '${appState.selectedTodoIds.length} Selected'
                : 'Todo App',
          ),
          leading: isSelectionMode
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: notifier.clearSelection,
                )
              : null,
          actions: [
            if (isSelectionMode)
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _confirmDeletion(context, ref),
              )
            else
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                ),
              ),
          ],
        ),
        body: appState.todos.isEmpty
            ? const Center(
                child: Text(
                  'No todos yet!\nTap + to add one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              )
            : ListView.builder(
                itemCount: appState.todos.length,
                itemBuilder: (context, index) {
                  final todo = appState.todos[index];
                  final isSelected = appState.selectedTodoIds.contains(todo.id);

                  return TodoItem(
                    key: ValueKey(todo.id),
                    todo: todo,
                    isSelected: isSelected,
                    isSelectionMode: isSelectionMode,
                    onTap: () {
                      if (isSelectionMode) {
                        notifier.toggleSelection(todo.id);
                      } else {
                        notifier.toggleTodo(todo.id);
                      }
                    },
                    onLongPress: () {
                      notifier.toggleSelection(todo.id);
                    },
                  );
                },
              ),
        floatingActionButton: isSelectionMode
            ? null
            : FloatingActionButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (_) => const AddTodoDialog(),
                  );
                },
                child: const Icon(Icons.add),
              ),
      ),
    );
  }
}
