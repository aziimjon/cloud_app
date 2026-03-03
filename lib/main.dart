import 'package:flutter/material.dart';
import 'core/config/app_config.dart';
import 'core/storage/secure_storage.dart';
import 'features/auth/presentation/splash_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.initialize(Environment.dev);
  runApp(const CloudApp());
}

class CloudApp extends StatelessWidget {
  const CloudApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A73E8),
        ),
        useMaterial3: true,
      ),
      home: const SplashPage(),
    );
  }
}