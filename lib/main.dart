import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/config/app_config.dart';
import 'core/services/language_notifier.dart';
import 'features/auth/presentation/splash_page.dart';
import 'l10n/app_localizations.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  ThemeNotifier — global singleton, no Provider needed
// ═══════════════════════════════════════════════════════════════════════════════

class ThemeNotifier extends ChangeNotifier {
  ThemeNotifier._();
  static final ThemeNotifier instance = ThemeNotifier._();

  static const _key = 'theme_mode';
  ThemeMode _mode = ThemeMode.light;
  ThemeMode get mode => _mode;

  /// Call once at app startup (before runApp)
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    _mode = stored == 'dark' ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void toggle() {
    setMode(_mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  void setMode(ThemeMode m) {
    if (_mode == m) return;
    _mode = m;
    notifyListeners();
    SharedPreferences.getInstance().then((p) {
      p.setString(_key, m == ThemeMode.dark ? 'dark' : 'light');
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Themes
// ═══════════════════════════════════════════════════════════════════════════════

final ThemeData _lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF1A73E8),
    brightness: Brightness.light,
  ),
  scaffoldBackgroundColor: const Color(0xFFF5F7FA),
  cardColor: Colors.white,
  dividerColor: const Color(0xFFE2E8F0),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: Colors.black,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: Colors.white,
  ),
);

final ThemeData _darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: const ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF1A73E8),
    onPrimary: Colors.white,
    secondary: Color(0xFF1A73E8),
    onSecondary: Colors.white,
    error: Color(0xFFEF4444),
    onError: Colors.white,
    surface: Color(0xFF161B22),
    onSurface: Color(0xFFE6EDF3),
    surfaceContainerHighest: Color(0xFF21262D),
  ),
  scaffoldBackgroundColor: const Color(0xFF0D1117),
  cardColor: const Color(0xFF161B22),
  dividerColor: const Color(0xFF30363D),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF161B22),
    foregroundColor: Color(0xFFE6EDF3),
    elevation: 0,
    surfaceTintColor: Colors.transparent,
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: Color(0xFF161B22),
  ),
  dialogTheme: const DialogThemeData(
    backgroundColor: Color(0xFF161B22),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: Color(0xFF161B22),
  ),
  inputDecorationTheme: InputDecorationTheme(
    fillColor: const Color(0xFF21262D),
    filled: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    hintStyle: const TextStyle(color: Color(0xFF8B949E)),
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Color(0xFFE6EDF3)),
    bodyMedium: TextStyle(color: Color(0xFFE6EDF3)),
    bodySmall: TextStyle(color: Color(0xFF8B949E)),
    titleLarge: TextStyle(color: Color(0xFFE6EDF3)),
    titleMedium: TextStyle(color: Color(0xFFE6EDF3)),
    titleSmall: TextStyle(color: Color(0xFF8B949E)),
    labelLarge: TextStyle(color: Color(0xFFE6EDF3)),
    labelMedium: TextStyle(color: Color(0xFF8B949E)),
    labelSmall: TextStyle(color: Color(0xFF8B949E)),
  ),
);

// ═══════════════════════════════════════════════════════════════════════════════
//  App Entry Point
// ═══════════════════════════════════════════════════════════════════════════════

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.initialize(Environment.dev);
  await ThemeNotifier.instance.init();
  await LanguageNotifier.instance.init();
  runApp(const CloudApp());
}

class CloudApp extends StatelessWidget {
  const CloudApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([ThemeNotifier.instance, LanguageNotifier.instance]),
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'MyCloud',
          theme: _lightTheme,
          darkTheme: _darkTheme,
          themeMode: ThemeNotifier.instance.mode,
          
          // 🌐 Localization configuration
          locale: LanguageNotifier.instance.locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'), // English
            Locale('ru'), // Russian
            Locale('uz'), // Uzbek
          ],
          
          home: const SplashPage(),
        );
      },
    );
  }
}
