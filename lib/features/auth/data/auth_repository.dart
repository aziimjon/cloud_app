import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/errors/app_exception.dart';

class AuthRepository {
  final Dio _dio = DioClient.instance;
  // LOGIN
  Future<void> login({
    required String phoneNumber,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        'authentication/users/login/',
        data: {'phone_number': phoneNumber, 'password': password},
      );
      final result = response.data['result'];
      await SecureStorage.saveTokens(
        accessToken: result['access_token'],
        refreshToken: result['refresh_token'],
      );
      final me = await _dio.get('authentication/users/me/');
      final meData = me.data['result'] ?? me.data;
      await SecureStorage.saveUserId(meData['id'].toString());
      final fullName = meData['full_name']?.toString();
      if (fullName != null) await SecureStorage.saveFullName(fullName);
    } on DioException catch (e) {
      throw AppException(
        message: e.response?.data?['message'] ?? 'Login failed',
        statusCode: e.response?.statusCode,
      );
    }
  }

  // REGISTER → returns otp_key
  Future<String> register({
    required String fullName,
    required String phoneNumber,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        'authentication/users/register/',
        data: {
          'full_name': fullName,
          'phone_number': phoneNumber,
          'password': password,
        },
      );
      final result = response.data['result'] ?? response.data;
      return result['otp_key']?.toString() ?? '';
    } on DioException catch (e) {
      throw AppException(
        message: e.response?.data?['message'] ?? 'Registration failed',
        statusCode: e.response?.statusCode,
      );
    }
  }

  // VERIFY OTP
  Future<void> verifyOtp({required String otpKey, required int otpCode}) async {
    try {
      final response = await _dio.post(
        'authentication/users/otp/verify/',
        data: {'otp_key': otpKey, 'otp_code': otpCode},
      );
      final result = response.data['result'];
      if (result != null && result['access_token'] != null) {
        await SecureStorage.saveTokens(
          accessToken: result['access_token'],
          refreshToken: result['refresh_token'],
        );
        final me = await _dio.get('authentication/users/me/');
        final meData = me.data['result'] ?? me.data;
        await SecureStorage.saveUserId(meData['id'].toString());
        final fullName = meData['full_name']?.toString();
        if (fullName != null) await SecureStorage.saveFullName(fullName);
      }
    } on DioException catch (e) {
      throw AppException(
        message: e.response?.data?['message'] ?? 'OTP verification failed',
        statusCode: e.response?.statusCode,
      );
    }
  }

  // RESEND OTP
  Future<String> resendOtp({required String phoneNumber}) async {
    try {
      final response = await _dio.post(
        'authentication/users/otp/resend/',
        data: {'phone_number': phoneNumber},
      );
      final result = response.data['result'] ?? response.data;
      return result['otp_key']?.toString() ?? '';
    } on DioException catch (e) {
      throw AppException(
        message: e.response?.data?['message'] ?? 'Resend failed',
        statusCode: e.response?.statusCode,
      );
    }
  }

  // LOGOUT
  Future<void> logout() async {
    await SecureStorage.clearTokens();
  }
}
