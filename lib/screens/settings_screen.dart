import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:todo_to_json/providers/app_state_provider.dart';

/// Displays the application's user-configurable settings.
class SettingsScreen extends ConsumerWidget {
  /// Creates the settings screen.
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final notifier = ref.read(appStateProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Dark Mode'),
            value: appState.isDarkMode,
            onChanged: (_) => notifier.toggleDarkMode(),
          ),
          SwitchListTile(
            title: const Text('Ask for Deletion Confirmation'),
            value: appState.asksForDeletionConfirmation,
            onChanged: (_) => notifier.toggleDeletionConfirmation(),
          ),
        ],
      ),
    );
  }
}
