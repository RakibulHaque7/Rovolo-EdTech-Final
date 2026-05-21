import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_client.dart';

class AttendanceRepository {
  final ApiClient _apiClient = ApiClient();

  // Check In with GPS Coordinates & Selfie
  Future<Map<String, dynamic>> checkIn({
    required double latitude,
    required double longitude,
    required XFile selfieFile,
    String? classDivision,
    String? topic,
  }) async {
    try {
      final formData = FormData.fromMap({
        'latitude': latitude,
        'longitude': longitude,
        'selfie': await MultipartFile.fromFile(
          selfieFile.path,
          filename: selfieFile.name,
        ),
        if (classDivision != null) 'class_division': classDivision,
        if (topic != null) 'topic': topic,
      });

      final response = await _apiClient.post(
        '/api/attendance/check-in/',
        data: formData,
      );

      if (response.statusCode == 201) {
        return {
          'success': true,
          'message':
              response.data['message'] ??
                  'Check-in successful',

          'distance':
              response.data[
                  'distance_in_meters'],

          'data':
              response.data['data'],
        };
      }

      return {
        'success': false,
        'error': 'Failed to check in.',
      };

    } on DioException catch (e) {
      final message =
          e.response?.data is Map
              ? (e.response?.data['error'] ??
                  e.response?.data['message'] ??
                  'Check-in failed')
              : 'Failed to connect to check-in API.';

      throw message;

    } catch (e) {
      throw 'Unexpected error during check-in: $e';
    }
  }

  // Check Out
  Future<Map<String, dynamic>> checkOut({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await _apiClient.post(
        '/api/attendance/check-out/',
        data: {
          'latitude': latitude,
          'longitude': longitude,
        },
      );

      if (response.statusCode == 200) {
        return {
          'success': true,

          'message':
              response.data['message'] ??
                  'Check-out successful',

          'working_hours':
              response.data[
                  'working_hours'],

          'distance':
              response.data[
                  'distance_in_meters'],
        };
      }

      return {
        'success': false,
        'error': 'Failed to check out.',
      };

    } on DioException catch (e) {
      final message =
          e.response?.data is Map
              ? (e.response?.data['error'] ??
                  e.response?.data['message'] ??
                  'Check-out failed')
              : 'Failed to connect to check-out API.';

      throw message;

    } catch (e) {
      throw 'Unexpected error during check-out: $e';
    }
  }

  // Dashboard Summary
  Future<Map<String, dynamic>>
      fetchDashboardSummary() async {
    try {
      final response =
          await _apiClient.get(
        '/api/dashboard/summary/',
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': response.data,
        };
      }

      return {
        'success': false,
        'data': {},
      };

    } catch (e) {
      throw 'Cannot fetch dashboard summary: $e';
    }
  }

  // Admin Dashboard Summary
  Future<Map<String, dynamic>>
      fetchAdminSummary() async {
    try {
      final response =
          await _apiClient.get(
        '/api/dashboard/admin-summary/',
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': response.data,
        };
      }

      return {
        'success': false,
        'data': {},
        'error':
            'Failed to load admin summary.',
      };

    } on DioException catch (e) {
      final errorData = e.response?.data;
      String message = 'Failed to load admin summary.';
      if (errorData is Map) {
        message = errorData['error']?.toString() ??
            errorData['message']?.toString() ??
            errorData['detail']?.toString() ??
            errorData.toString();
      } else if (errorData != null) {
        message = errorData.toString();
      }

      final status = e.response?.statusCode;
      if (status != null) {
        message = '[$status] $message';
      }

      return {
        'success': false,
        'data': {},
        'error': message,
      };

    } catch (e) {
      return {
        'success': false,
        'data': {},
        'error':
            'Cannot fetch admin summary: $e',
      };
    }
  }

  // School Dashboard Summary
  Future<Map<String, dynamic>>
      fetchSchoolSummary() async {
    try {
      final response =
          await _apiClient.get(
        '/api/dashboard/school-summary/',
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': response.data,
        };
      }

      return {
        'success': false,
        'data': {},
      };

    } catch (e) {
      throw 'Cannot fetch school summary: $e';
    }
  }

  Future<Map<String, dynamic>>
      fetchAttendanceReport() async {
    try {
      final response = await _apiClient.get(
        '/api/attendance/reports/today/',
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': response.data,
        };
      }

      return {
        'success': false,
        'data': {},
      };
    } catch (e) {
      throw 'Cannot fetch attendance report: $e';
    }
  }

  Future<Map<String, dynamic>>
      fetchMonthlyAnalytics() async {
    try {
      final response = await _apiClient.get(
        '/api/attendance/reports/monthly/',
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': response.data,
        };
      }

      return {
        'success': false,
        'data': {},
      };
    } catch (e) {
      throw 'Cannot fetch monthly analytics: $e';
    }
  }

  Future<Map<String, dynamic>>
      fetchAttendanceHistory() async {
    try {
      final response = await _apiClient.get(
        '/api/attendance/history/',
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': response.data['data'] ?? [],
        };
      }

      return {
        'success': false,
        'data': [],
      };
    } catch (e) {
      throw 'Cannot fetch attendance history: $e';
    }
  }

  Future<Map<String, dynamic>>
      fetchLeaveHistory() async {
    try {
      final response = await _apiClient.get(
        '/api/leave/history/',
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': response.data['data'] ?? [],
        };
      }

      return {
        'success': false,
        'data': [],
      };
    } catch (e) {
      throw 'Cannot fetch leave history: $e';
    }
  }

  Future<Map<String, dynamic>>
      fetchSchoolList() async {
    try {
      final response = await _apiClient.get(
        '/api/schools/list/',
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': response.data,
        };
      }

      return {
        'success': false,
        'data': [],
      };
    } catch (e) {
      throw 'Cannot fetch school list: $e';
    }
  }

  Future<Map<String, dynamic>>
      fetchUsers({String? role}) async {
    try {
      final response = await _apiClient.get(
        '/api/users/list/',
        queryParameters: role != null ? {'role': role} : null,
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': response.data,
        };
      }

      return {
        'success': false,
        'data': [],
      };
    } catch (e) {
      throw 'Cannot fetch users: $e';
    }
  }

  // Update Geofence
  Future<Map<String, dynamic>>
      updateSchoolGeofence({
    required double latitude,
    required double longitude,
    required int allowedRadius,
  }) async {
    try {
      final response =
          await _apiClient.post(
        '/api/dashboard/school-update-geofence/',
        data: {
          'latitude': latitude,
          'longitude': longitude,
          'allowed_radius':
              allowedRadius,
        },
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'school':
              response.data['school'],
        };
      }

      return {
        'success': false,
      };

    } catch (e) {
      throw 'Update geofence failed: $e';
    }
  }

  // Update Leave Status
  Future<Map<String, dynamic>>
      updateLeaveStatus({
    required int leaveId,
    required String status,
  }) async {
    try {
      final response =
          await _apiClient.patch(
        '/api/leave/update-status/$leaveId/',
        data: {
          'status':
              status.toLowerCase(),
        },
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data':
              response.data['data'],
        };
      }

      return {
        'success': false,
      };

    } catch (e) {
      throw 'Leave update failed: $e';
    }
  }
}