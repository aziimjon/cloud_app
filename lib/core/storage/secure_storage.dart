import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userIdKey = 'user_id';
  static const _fullNameKey = 'full_name';

  static Future<void> saveFullName(String name) async {
    try {
      await _storage.write(key: _fullNameKey, value: name);
    } catch (_) {}
  }

  static Future<String?> getFullName() async {
    try {
      return await _storage.read(key: _fullNameKey);
    } catch (_) {
      await clearTokens();
      return null;
    }
  }

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    try {
      await _storage.write(key: _accessTokenKey, value: accessToken);
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    } catch (_) {}
  }

  static Future<void> saveUserId(String userId) async {
    try {
      await _storage.write(key: _userIdKey, value: userId);
    } catch (_) {}
  }

  static Future<String?> getUserId() async {
    try {
      return await _storage.read(key: _userIdKey);
    } catch (_) {
      await clearTokens();
      return null;
    }
  }

  static Future<String?> getAccessToken() async {
    try {
      return await _storage.read(key: _accessTokenKey);
    } catch (_) {
      await clearTokens();
      return null;
    }
  }

  static Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _refreshTokenKey);
    } catch (_) {
      await clearTokens();
      return null;
    }
  }

  static Future<void> clearTokens() async {
    try {
      await _storage.deleteAll();
    } catch (_) {}
  }
}