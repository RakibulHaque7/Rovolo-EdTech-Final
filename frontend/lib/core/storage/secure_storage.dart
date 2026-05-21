import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage =
      const FlutterSecureStorage();

  Future<void> saveAccessToken(String token) async {
    await _storage.write(
      key: 'access_token',
      value: token,
    );
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(
      key: 'access_token',
    );
  }

  Future<void> saveRefreshToken(String token) async {
    await _storage.write(
      key: 'refresh_token',
      value: token,
    );
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(
      key: 'refresh_token',
    );
  }

  Future<void> saveRole(String role) async {
    await _storage.write(
      key: 'role',
      value: role,
    );
  }

  Future<String?> getRole() async {
    return await _storage.read(
      key: 'role',
    );
  }

  Future<void> saveSession({
    required String access,
    required String refresh,
    required String role,
  }) async {
    await saveAccessToken(access);
    await saveRefreshToken(refresh);
    await saveRole(role);
  }

  Future<void> clearSession() async {
    await _storage.deleteAll();
  }
}