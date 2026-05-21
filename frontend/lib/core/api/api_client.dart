import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

import '../storage/secure_storage.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;
  final SecureStorageService _storage = SecureStorageService();

  // Local host configuration:
  // Android emulator loopback: 10.0.2.2
  // iOS simulator / desktop / web: 127.0.0.1
  // Adjust this base URL to match your server's deployment or local IP.
  static String get baseUrl {
    if (kIsWeb) return 'http://127.0.0.1:8000';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    } catch (_) {}
    return 'http://127.0.0.1:8000';
  }

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Request & Error interceptor for auto token injecting and silent refresh
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Do not append authorization token to token generation/refresh endpoints
          if (!options.path.contains('/api/token/')) {
            final token = await _storage.getAccessToken();
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          // If response is 401 (Unauthorized) and it's not a login request, try to refresh token
          if (e.response?.statusCode == 401 && !e.requestOptions.path.contains('/api/token/')) {
            try {
              final refreshToken = await _storage.getRefreshToken();
              if (refreshToken != null) {
                // Fetch a new access token
                final refreshResponse = await Dio().post(
                  '$baseUrl/api/token/refresh/',
                  data: {'refresh': refreshToken},
                );

                if (refreshResponse.statusCode == 200) {
                  final newAccessToken = refreshResponse.data['access'];
                  
                  // Save the new access token
                  await _storage.saveAccessToken(newAccessToken);

                  // Clone the original request with the new access token
                  final requestOptions = e.requestOptions;
                  requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';

                  // Retry the original request
                  final response = await dio.fetch(requestOptions);
                  return handler.resolve(response);
                }
              }
            } catch (err) {
              // Refresh token is expired or invalid -> log out the user
              await _storage.clearSession();
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  // Helper HTTP GET method
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    return await dio.get(path, queryParameters: queryParameters);
  }

  // Helper HTTP POST method
  Future<Response> post(String path, {dynamic data, Options? options}) async {
    return await dio.post(path, data: data, options: options);
  }

  // Helper HTTP PATCH method
  Future<Response> patch(String path, {dynamic data, Options? options}) async {
    return await dio.patch(path, data: data, options: options);
  }
}
