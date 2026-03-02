import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthApi {
  static const String baseUrl = "http://10.0.2.2:8000";
  // 10.0.2.2 = localhost for Android emulator

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Login failed');
    }
  }
}
