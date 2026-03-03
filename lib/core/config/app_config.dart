enum Environment { dev, prod }

class AppConfig {
  final Environment environment;
  final String baseUrl;
  final String tusUrl;

  const AppConfig({
    required this.environment,
    required this.baseUrl,
    required this.tusUrl,
  });

  static late AppConfig instance;

  static void initialize(Environment env) {
    switch (env) {
      case Environment.dev:
        instance = const AppConfig(
          environment: Environment.dev,
          // ✅ ИСПРАВЛЕНО: /server/api/v1/ — рабочий путь (не /api/v1/)
          baseUrl: 'http://192.168.1.100/server/api/v1/',
          // TUS работает на отдельном порту 1080
          tusUrl: 'http://192.168.1.100:1080/files/',
        );
        break;
      case Environment.prod:
        instance = const AppConfig(
          environment: Environment.prod,
          baseUrl: 'https://api.yourdomain.com/server/api/v1',
          tusUrl: 'https://api.yourdomain.com:1080/files/',
        );
        break;
    }
  }
}