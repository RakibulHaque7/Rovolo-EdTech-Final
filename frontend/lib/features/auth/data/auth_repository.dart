import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/secure_storage.dart';

class AuthRepository {

  final ApiClient _apiClient =
      ApiClient();

  final SecureStorageService
      _storage =
      SecureStorageService();


  // LOGIN
  Future<Map<String, dynamic>>
      login({

    required String username,

    required String password,

  }) async {

    try {

      final tokenResponse =
          await _apiClient.post(

        '/api/token/',

        data: {

          'username':
              username.trim(),

          'password':
              password,

        },

      );

      if (tokenResponse.statusCode !=
          200) {

        throw 'Login failed';

      }

      final access =
          tokenResponse
              .data['access'];

      final refresh =
          tokenResponse
              .data['refresh'];

      await _storage.saveSession(

        access:
            access,

        refresh:
            refresh,

        role: '',

      );


      final profileResponse =
          await _apiClient.get(
        '/api/me/',
      );

      if (profileResponse.statusCode !=
          200) {

        throw 'Profile fetch failed';

      }

      final profile =
          Map<String,
              dynamic>.from(
        profileResponse.data,
      );

      final role =
          profile['role']
                  ?.toString()
                  .toLowerCase() ??
              'student';


      await _storage.saveSession(

        access:
            access,

        refresh:
            refresh,

        role:
            role,

      );


      return {

        'success':
            true,

        'role':
            role,

        'profile':
            profile,

      };

    } on DioException catch (e) {

      if (e.response
              ?.statusCode ==
          401) {

        throw 'Invalid credentials';

      }

      throw 'Backend unavailable';

    } catch (e) {

      throw e.toString();

    }
  }


  // REGISTER
  Future<Map<String, dynamic>>
      register({

    required String username,

    required String email,

    required String password,

    required String role,

  }) async {

    try {

      final response =
          await _apiClient.post(

        '/api/register/',

        data: {

          'username':
              username,

          'email':
              email,

          'password':
              password,

          'role':
              role,

        },

      );

      if (response.statusCode ==
          201) {

        return {

          'success':
              true,

          'data':
              response.data,

        };
      }

      throw 'Registration failed';

    } on DioException catch (e) {

      if (e.response !=
          null) {

        throw e.response
            .toString();

      }

      throw 'Server unavailable';

    }
  }


  // LOGOUT
  Future<void> logout()
      async {

    await _storage.clearSession();

  }


  // CHECK LOGIN
  Future<bool>
      isLoggedIn()
      async {

    final token =
        await _storage
            .getAccessToken();

    return token != null &&
        token.isNotEmpty;

  }


  // CURRENT ROLE
  Future<String?>
      currentRole()
      async {

    return await _storage
        .getRole();

  }


  // PROFILE
  Future<Map<String,
      dynamic>>
      profile()
      async {

    final response =
        await _apiClient.get(
      '/api/me/',
    );

    return Map<String,
        dynamic>.from(
      response.data,
    );
  }
}