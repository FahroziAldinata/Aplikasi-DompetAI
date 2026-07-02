import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../main.dart'; // import themeModeProvider

class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return IconButton(
      icon: Icon(
        isDark ? Icons.light_mode : Icons.dark_mode,
        color: colorScheme.onSurface,
      ),
      onPressed: () async {
        final nextMode = themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
        ref.read(themeModeProvider.notifier).state = nextMode;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('theme_mode', nextMode == ThemeMode.light ? 'light' : 'dark');
      },
    );
  }
}
