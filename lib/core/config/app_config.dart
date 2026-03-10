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
          baseUrl: 'http://94.158.52.27:8000/api/v1/',
          tusUrl: 'http://94.158.52.27:1080/files',
        );
        break;
      case Environment.prod:
        instance = const AppConfig(
          environment: Environment.prod,
          baseUrl: 'http://94.158.52.27:8000/api/v1/',
          tusUrl: 'http://94.158.52.27:1080/files',
        );
        break;
    }
  }
}
