import 'dart:async';

import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/errors/app_exception.dart';
import '../../sync/auto_sync_service.dart';

class AuthRepository {
  final Dio _dio = DioClient.instance;

  String _extractError(dynamic data) {
    if (data == null) return 'Unknown error';
    if (data is Map) {
      if (data.containsKey('detail')) return data['detail'].toString();
      if (data.containsKey('message')) return data['message'].toString();
      if (data.containsKey('non_field_errors')) {
        final errs = data['non_field_errors'];
        return errs is List ? errs.join(', ') : errs.toString();
      }
      return data.values.join(', ');
    } else if (data is List) {
      return data.join(', ');
    }
    return data.toString();
  }

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

      final data = response.data is Map
          ? response.data as Map<String, dynamic>
          : {};
      final accessToken =
          data['access'] ??
          data['access_token'] ??
          data['result']?['access_token'];
      final refreshToken =
          data['refresh'] ??
          data['refresh_token'] ??
          data['result']?['refresh_token'];

      await SecureStorage.saveTokens(
        accessToken: accessToken?.toString() ?? '',
        refreshToken: refreshToken?.toString() ?? '',
      );
      unawaited(AutoSyncService().initialize());

      final me = await _dio.get('authentication/users/me/');
      final meData = me.data is Map && me.data.containsKey('result')
          ? me.data['result']
          : me.data;
      if (meData is Map) {
        if (meData.containsKey('id'))
          await SecureStorage.saveUserId(meData['id'].toString());
        final fullName = meData['full_name']?.toString();
        if (fullName != null) await SecureStorage.saveFullName(fullName);
      }
    } on DioException catch (e) {
      throw AppException(
        message: _extractError(e.response?.data) != 'Unknown error'
            ? _extractError(e.response?.data)
            : 'Login failed',
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
      final data = response.data is Map
          ? response.data as Map<String, dynamic>
          : {};
      final result = data.containsKey('result') ? data['result'] : data;
      return result['otp_key']?.toString() ?? '';
    } on DioException catch (e) {
      throw AppException(
        message: _extractError(e.response?.data) != 'Unknown error'
            ? _extractError(e.response?.data)
            : 'Registration failed',
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

      final data = response.data is Map
          ? response.data as Map<String, dynamic>
          : {};
      final result = data.containsKey('result') ? data['result'] : data;

      final accessToken = result['access'] ?? result['access_token'];
      final refreshToken = result['refresh'] ?? result['refresh_token'];

      if (accessToken != null) {
        await SecureStorage.saveTokens(
          accessToken: accessToken.toString(),
          refreshToken: refreshToken?.toString() ?? '',
        );
        unawaited(AutoSyncService().initialize());
        final me = await _dio.get('authentication/users/me/');
        final meData = me.data is Map && me.data.containsKey('result')
            ? me.data['result']
            : me.data;
        if (meData is Map) {
          if (meData.containsKey('id'))
            await SecureStorage.saveUserId(meData['id'].toString());
          final fullName = meData['full_name']?.toString();
          if (fullName != null) await SecureStorage.saveFullName(fullName);
        }
      }
    } on DioException catch (e) {
      throw AppException(
        message: _extractError(e.response?.data) != 'Unknown error'
            ? _extractError(e.response?.data)
            : 'OTP verification failed',
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
      final data = response.data is Map
          ? response.data as Map<String, dynamic>
          : {};
      final result = data.containsKey('result') ? data['result'] : data;
      return result['otp_key']?.toString() ?? '';
    } on DioException catch (e) {
      throw AppException(
        message: _extractError(e.response?.data) != 'Unknown error'
            ? _extractError(e.response?.data)
            : 'Resend failed',
        statusCode: e.response?.statusCode,
      );
    }
  }

  // LOGOUT
  Future<void> logout() async {
    await SecureStorage.clearTokens();
  }
}
