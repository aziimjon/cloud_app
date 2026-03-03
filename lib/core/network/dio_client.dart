import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../config/app_config.dart';
import '../storage/secure_storage.dart';

class DioClient {
  static Dio? _dio;

  static Dio get instance {
    _dio ??= _createDio();
    return _dio!;
  }

  // Сброс при logout — чтобы новый пользователь получил чистый инстанс
  static void reset() => _dio = null;

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.instance.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(_AuthInterceptor(dio));
    dio.interceptors.add(PrettyDioLogger(
      requestHeader: true,
      requestBody: true,
      responseBody: true,
      responseHeader: false,
      error: true,
      compact: true,
    ));

    return dio;
  }
}

class _AuthInterceptor extends Interceptor {
  final Dio dio;
  bool _isRefreshing = false;

  _AuthInterceptor(this.dio);

  @override
  void onRequest(
      RequestOptions options,
      RequestInterceptorHandler handler,
      ) async {
    final token = await SecureStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;
      try {
        final refreshToken = await SecureStorage.getRefreshToken();
        if (refreshToken == null) {
          await SecureStorage.clearTokens();
          handler.next(err);
          return;
        }

        final refreshDio = Dio(
          BaseOptions(baseUrl: AppConfig.instance.baseUrl),
        );

        // ✅ ИСПРАВЛЕНО: правильный endpoint для refresh
        // POST /authentication/users/token/refresh/
        // body: {refresh: token}
        // response: {access: newToken}
        final response = await refreshDio.post(
          '/authentication/users/token/refresh/',
          data: {'refresh': refreshToken},
        );

        // ✅ ИСПРАВЛЕНО: ответ содержит просто {access: "..."}
        // не вложенный result
        final newAccessToken = response.data['access'] as String;

        await SecureStorage.saveTokens(
          accessToken: newAccessToken,
          // refresh токен остаётся тем же (если backend не выдаёт новый)
          refreshToken: refreshToken,
        );

        err.requestOptions.headers['Authorization'] =
        'Bearer $newAccessToken';

        final retryResponse = await dio.fetch(err.requestOptions);
        handler.resolve(retryResponse);
      } catch (_) {
        await SecureStorage.clearTokens();
        handler.next(err);
      } finally {
        _isRefreshing = false;
      }
    } else {
      handler.next(err);
    }
  }
}