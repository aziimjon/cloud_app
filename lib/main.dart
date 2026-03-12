import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/config/app_config.dart';
import 'features/auth/presentation/splash_page.dart';

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
    primary: Color(0xFF3B82F6),
    onPrimary: Colors.white,
    secondary: Color(0xFF60A5FA),
    onSecondary: Colors.white,
    error: Color(0xFFEF4444),
    onError: Colors.white,
    surface: Color(0xFF1E293B),
    onSurface: Color(0xFFF8FAFC),
  ),
  scaffoldBackgroundColor: const Color(0xFF0F172A),
  cardColor: const Color(0xFF1E293B),
  dividerColor: const Color(0xFF334155),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF0F172A),
    foregroundColor: Color(0xFFF8FAFC),
    elevation: 0,
    surfaceTintColor: Colors.transparent,
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: Color(0xFF1E293B),
  ),
  inputDecorationTheme: InputDecorationTheme(
    fillColor: const Color(0xFF334155),
    filled: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Color(0xFFF8FAFC)),
    bodyMedium: TextStyle(color: Color(0xFFF8FAFC)),
    bodySmall: TextStyle(color: Color(0xFF94A3B8)),
    titleLarge: TextStyle(color: Color(0xFFF8FAFC)),
    titleMedium: TextStyle(color: Color(0xFFF8FAFC)),
    titleSmall: TextStyle(color: Color(0xFF94A3B8)),
    labelLarge: TextStyle(color: Color(0xFFF8FAFC)),
    labelMedium: TextStyle(color: Color(0xFF94A3B8)),
    labelSmall: TextStyle(color: Color(0xFF94A3B8)),
  ),
);

// ═══════════════════════════════════════════════════════════════════════════════
//  App Entry Point
// ═══════════════════════════════════════════════════════════════════════════════

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.initialize(Environment.dev);
  await ThemeNotifier.instance.init();
  runApp(const CloudApp());
}

class CloudApp extends StatelessWidget {
  const CloudApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeNotifier.instance,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _lightTheme,
          darkTheme: _darkTheme,
          themeMode: ThemeNotifier.instance.mode,
          home: const SplashPage(),
        );
      },
    );
  }
}