import 'package:flutter/material.dart';

import 'package:todo_to_json/models/todo.dart';

/// Displays a todo in a selectable list tile.
class TodoItem extends StatelessWidget {
  /// The todo represented by this item.
  final Todo todo;

  /// Whether this item is currently selected.
  final bool isSelected;

  /// Whether the parent widget is displaying the item in selection mode.
  final bool isSelectionMode;

  /// Called when the item is tapped.
  final VoidCallback onTap;

  /// Called when the item is long-pressed.
  final VoidCallback onLongPress;

  /// Creates a todo item widget.
  const TodoItem({
    required this.todo,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      selected: isSelected,
      selectedTileColor: Theme.of(
        context,
      ).colorScheme.primaryContainer.withValues(alpha: 0.3),
      leading: Checkbox(
        value: todo.isCompleted,
        onChanged: (_) => onTap(),
      ),
      title: Text(
        todo.text,
        style: TextStyle(
          decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
        ),
      ),
      trailing: isSelectionMode
          ? Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected ? Theme.of(context).colorScheme.primary : null,
            )
          : null,
    );
  }
}
