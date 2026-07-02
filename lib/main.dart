import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'presentation/splash/splash_screen.dart';
import 'presentation/onboarding/onboarding_screen.dart';
import 'presentation/onboarding/name_input_screen.dart';

// StateProvider for managing the ThemeMode across the entire app
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  
  // Initialize date formatting for Indonesian locale
  await initializeDateFormatting('id_ID', null);
  
  final prefs = await SharedPreferences.getInstance();
  final seen = prefs.getBool('onboarding_done') ?? false;
  final nameEntered = prefs.getBool('user_name_entered') ?? (prefs.getString('user_name') != null);
  final themeStr = prefs.getString('theme_mode') ?? 'dark';
  final initialTheme = themeStr == 'light' ? ThemeMode.light : ThemeMode.dark;
  
  runApp(
    ProviderScope(
      overrides: [
        themeModeProvider.overrideWith((ref) => initialTheme),
      ],
      child: MyApp(seenOnboarding: seen, nameEntered: nameEntered),
    ),
  );
}

class MyApp extends ConsumerWidget {
  final bool seenOnboarding;
  final bool nameEntered;
  const MyApp({super.key, required this.seenOnboarding, required this.nameEntered});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'DompetAI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: !seenOnboarding 
          ? const OnboardingScreen() 
          : (!nameEntered ? const NameInputScreen() : const SplashScreen()),
    );
  }
}

