import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class EcoPointsService {
  static const String _baseUrl = 'http://10.0.2.2:8000'; // Android emulator
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Get JWT token from storage
  Future<String?> _getToken() async {
    // First try to get from dedicated jwt_token key
    final token = await _secureStorage.read(key: 'jwt_token');
    if (token != null && token.isNotEmpty) {
      return token;
    }

    // Fallback to fastapi_user storage
    final userId = await _secureStorage.read(key: 'current_user_id');
    if (userId != null) {
      final userData = await _secureStorage.read(key: 'fastapi_user_$userId');
      if (userData != null) {
        final data = jsonDecode(userData);
        return data['token'];
      }
    }
    return null;
  }

  // Store JWT token
  Future<void> _storeToken(String token) async {
    final userId = await _secureStorage.read(key: 'current_user_id');
    if (userId != null) {
      final existingData = await _secureStorage.read(
        key: 'fastapi_user_$userId',
      );
      Map<String, dynamic> data = {};
      if (existingData != null) {
        data = jsonDecode(existingData);
      }
      data['token'] = token;
      await _secureStorage.write(
        key: 'fastapi_user_$userId',
        value: jsonEncode(data),
      );
    }
  }

  // ========== DASHBOARD ==========

  Future<Map<String, dynamic>?> getDashboard(int userId) async {
    try {
      final token = await _getToken();

      final url = Uri.parse('$_baseUrl/user/$userId/dashboard');
      final response = await http
          .get(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        print('Dashboard response: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Get dashboard error: $e');
      }
      return null;
    }
  }

  // ========== PROFILE ==========

  Future<Map<String, dynamic>?> getProfile(int userId) async {
    try {
      final token = await _getToken();

      final url = Uri.parse('$_baseUrl/user/$userId/profile');
      final response = await http
          .get(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        print('Profile response: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Get profile error: $e');
      }
      return null;
    }
  }

  // ========== TRIPS ==========

  Future<List<Map<String, dynamic>>?> getTrips(int userId) async {
    try {
      final token = await _getToken();

      final url = Uri.parse('$_baseUrl/trip/$userId/trips');
      final response = await http
          .get(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        print('Trips response: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.cast<Map<String, dynamic>>();
        }
        return null;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Get trips error: $e');
      }
      return null;
    }
  }

  // ========== LEADERBOARD ==========

  Future<List<Map<String, dynamic>>?> getLeaderboard() async {
    try {
      final url = Uri.parse('$_baseUrl/leaderboard');
      final response = await http
          .get(url, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        print('Leaderboard response: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['entries'] != null) {
          return (data['entries'] as List).cast<Map<String, dynamic>>();
        }
        return null;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Get leaderboard error: $e');
      }
      return null;
    }
  }

  // ========== ADD TRIP ==========

  Future<Map<String, dynamic>?> addTrip({
    required int userId,
    required double distance,
    required double duration,
    required String routeType,
    required String startLocation,
    required String endLocation,
  }) async {
    try {
      final token = await _getToken();

      final url = Uri.parse('$_baseUrl/trip/add');
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'user_id': userId,
              'distance': distance,
              'duration': duration,
              'route_type': routeType,
              'start_location': startLocation,
              'end_location': endLocation,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        print('Add trip response: ${response.statusCode}');
        print('Add trip body: ${response.body}');
      }

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Add trip error: $e');
      }
      return null;
    }
  }

  // ========== GET USER RANK ==========

  Future<Map<String, dynamic>?> getUserRank(int userId) async {
    try {
      final token = await _getToken();

      final url = Uri.parse('$_baseUrl/leaderboard/$userId');
      final response = await http
          .get(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        print('User rank response: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Get user rank error: $e');
      }
      return null;
    }
  }
}
