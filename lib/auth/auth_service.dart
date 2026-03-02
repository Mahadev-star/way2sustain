import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class User {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoURL;
  final bool isGuest;
  final String? token; // For JWT token if needed

  // Eco statistics from backend
  final double ecoPoints;
  final int totalTrips;
  final double totalKm;
  final double totalCo2Saved;
  final int? rank;

  User({
    required this.uid,
    this.email,
    this.displayName,
    this.photoURL,
    this.isGuest = false,
    this.token,
    this.ecoPoints = 0.0,
    this.totalTrips = 0,
    this.totalKm = 0.0,
    this.totalCo2Saved = 0.0,
    this.rank,
  });

  // Copy with method to update stats
  User copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoURL,
    bool? isGuest,
    String? token,
    double? ecoPoints,
    int? totalTrips,
    double? totalKm,
    double? totalCo2Saved,
    int? rank,
  }) {
    return User(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      isGuest: isGuest ?? this.isGuest,
      token: token ?? this.token,
      ecoPoints: ecoPoints ?? this.ecoPoints,
      totalTrips: totalTrips ?? this.totalTrips,
      totalKm: totalKm ?? this.totalKm,
      totalCo2Saved: totalCo2Saved ?? this.totalCo2Saved,
      rank: rank ?? this.rank,
    );
  }
}

class AuthService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final Random _random = Random();

  User? _currentUser;

  // FastAPI base URL
  static const String _baseUrl = 'http://10.0.2.2:8000'; // Android emulator

  // Get current user
  User? get currentUser => _currentUser;

  // Stream for auth state changes
  Stream<User?> get authStateChanges => _createAuthStream();

  // ========== FASTAPI REGISTRATION ==========

  Future<User?> registerWithEmail({
    required String email,
    required String password,
    required String name,
    String? username, // Optional: if not provided, use email as username
  }) async {
    try {
      const url = '$_baseUrl/register';

      if (kDebugMode) {
        print('Registering user at: $url');
      }

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'username':
                  username ??
                  email.split('@').first, // Use email prefix as username
              'email': email,
              'password': password,
              'name': name,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        print('Response status: ${response.statusCode}');
      }
      if (kDebugMode) {
        print('Response body: ${response.body}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        // If status is 201 (Created), assume success regardless of response body
        if (response.statusCode == 201) {
          // Create user with provided data - account was created on server
          final user = User(
            uid: DateTime.now().millisecondsSinceEpoch.toString(),
            email: email,
            displayName: name,
            isGuest: false,
          );

          // Create local profile
          await _createUserProfile(user, name: name);

          // Store credentials securely
          await _secureStorage.write(
            key: 'fastapi_user_${user.uid}',
            value: jsonEncode({
              'email': email,
              'name': name,
              'registeredAt': DateTime.now().toIso8601String(),
            }),
          );

          // Set as current user
          _currentUser = user;
          await _secureStorage.write(key: 'current_user_id', value: user.uid);

          return user;
        }

        // For 200 OK, parse response normally
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        if (responseData['status'] == 'success') {
          final userData = responseData['user'] ?? responseData;

          final user = User(
            uid: userData['id'].toString(),
            email: userData['email'],
            displayName: userData['name'],
            isGuest: false,
          );

          await _createUserProfile(user, name: name);

          await _secureStorage.write(
            key: 'fastapi_user_${user.uid}',
            value: jsonEncode({
              'email': email,
              'name': name,
              'registeredAt': DateTime.now().toIso8601String(),
            }),
          );

          _currentUser = user;
          await _secureStorage.write(key: 'current_user_id', value: user.uid);

          return user;
        } else {
          throw responseData['detail'] ?? 'Registration failed';
        }
      } else if (response.statusCode == 400) {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        throw errorData['detail'] ?? 'Registration failed';
      } else {
        throw 'Server error: ${response.statusCode}';
      }
    } catch (e) {
      if (kDebugMode) {
        print('Registration error: $e');
      }
      rethrow;
    }
  }

  // ========== FASTAPI LOGIN ==========

  Future<bool> loginWithBackend({
    required String email,
    required String password,
  }) async {
    try {
      const url = '$_baseUrl/login';

      if (kDebugMode) {
        print('Logging in at: $url');
      }

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'username': email, // Can use email as username
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        print('Response status: ${response.statusCode}');
      }
      if (kDebugMode) {
        print('Response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        if (responseData['status'] == 'success') {
          final userData = responseData['user'];
          final token = responseData['access_token'];

          // Create user object with eco stats from backend
          final user = User(
            uid: userData['id'].toString(),
            email: userData['email'],
            displayName: userData['name'],
            isGuest: false,
            token: token,
            ecoPoints: (userData['eco_points'] ?? 0).toDouble(),
            totalTrips: userData['total_trips'] ?? 0,
            totalKm: (userData['total_km'] ?? 0).toDouble(),
            totalCo2Saved: (userData['total_co2_saved'] ?? 0).toDouble(),
          );

          // Create or update local profile
          if (!await _userExists(user.uid)) {
            await _createUserProfile(user);
          } else {
            await _updateLastLogin(user.uid);
          }

          // Store FastAPI user info INCLUDING THE JWT TOKEN
          await _secureStorage.write(
            key: 'fastapi_user_${user.uid}',
            value: jsonEncode({
              'email': userData['email'],
              'name': userData['name'],
              'token': token,
              'lastLogin': DateTime.now().toIso8601String(),
            }),
          );

          // Also store the token separately for easy access
          await _secureStorage.write(key: 'jwt_token', value: token);

          // Set as current user
          _currentUser = user;
          await _secureStorage.write(key: 'current_user_id', value: user.uid);

          return true;
        }
        return false;
      } else if (response.statusCode == 401) {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        throw errorData['detail'] ?? 'Invalid credentials';
      } else {
        throw 'Server error: ${response.statusCode}';
      }
    } catch (e) {
      if (kDebugMode) {
        print('Backend login error: $e');
      }
      rethrow;
    }
  }

  // ========== EXISTING METHODS (keep these) ==========

  // Check if user exists in local storage
  Future<bool> _userExists(String userId) async {
    final userData = await _secureStorage.read(key: 'user_$userId');
    return userData != null;
  }

  // Create user profile in local storage
  Future<void> _createUserProfile(User user, {String? name}) async {
    final userData = {
      'uid': user.uid,
      'email': user.email,
      'displayName': name ?? user.displayName ?? 'Traveler',
      'photoURL': user.photoURL,
      'createdAt': DateTime.now().toIso8601String(),
      'lastLogin': DateTime.now().toIso8601String(),
      'isGuest': false,
      'carbonSaved': 0.0,
      'tripsCompleted': 0,
      'ecoScore': 0,
      'preferences': {
        'transportMode': 'balanced',
        'notifications': true,
        'darkMode': true,
      },
    };

    await _secureStorage.write(
      key: 'user_${user.uid}',
      value: jsonEncode(userData),
    );

    // Store current user ID
    await _secureStorage.write(key: 'current_user_id', value: user.uid);
  }

  // Update user profile
  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    final user = _currentUser;
    if (user != null) {
      final userData = await _getUserData(user.uid);
      if (userData != null) {
        userData.addAll(data);
        userData['lastLogin'] = DateTime.now().toIso8601String();
        await _secureStorage.write(
          key: 'user_${user.uid}',
          value: jsonEncode(userData),
        );
      }
    }
  }

  // Get user data
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    return await _getUserData(userId);
  }

  // ========== SOCIAL AUTH ==========

  Future<User?> signInWithGoogle() async {
    try {
      // Simulate Google sign-in flow
      await Future.delayed(const Duration(seconds: 1));

      final userId = _generateUserId();
      final user = User(
        uid: userId,
        email: 'google_user_${_random.nextInt(1000)}@example.com',
        displayName: 'Google User ${_random.nextInt(1000)}',
        photoURL: 'https://ui-avatars.com/api/?name=Google+User',
      );

      if (!await _userExists(userId)) {
        await _createUserProfile(user);
      } else {
        await _updateLastLogin(userId);
      }

      _currentUser = user;
      await _secureStorage.write(key: 'current_user_id', value: userId);

      return user;
    } catch (e) {
      if (kDebugMode) {
        print('Google sign in error: $e');
      }
      throw 'Google sign in failed: $e';
    }
  }

  Future<User?> signInWithFacebook() async {
    try {
      // Simulate Facebook sign-in flow
      await Future.delayed(const Duration(seconds: 1));

      final userId = _generateUserId();
      final user = User(
        uid: userId,
        email: 'facebook_user_${_random.nextInt(1000)}@example.com',
        displayName: 'Facebook User ${_random.nextInt(1000)}',
        photoURL: 'https://ui-avatars.com/api/?name=Facebook+User',
      );

      if (!await _userExists(userId)) {
        await _createUserProfile(user);
      } else {
        await _updateLastLogin(userId);
      }

      _currentUser = user;
      await _secureStorage.write(key: 'current_user_id', value: userId);

      return user;
    } catch (e) {
      if (kDebugMode) {
        print('Facebook sign in error: $e');
      }
      throw 'Facebook sign in failed: $e';
    }
  }

  // ========== GUEST LOGIN ==========

  Future<User?> loginAsGuest() async {
    try {
      // Simulate guest login
      await Future.delayed(const Duration(milliseconds: 500));

      final userId = _generateUserId();
      final user = User(
        uid: userId,
        displayName: 'Eco Traveler',
        isGuest: true,
      );

      // Create guest profile
      final guestData = {
        'uid': userId,
        'isGuest': true,
        'createdAt': DateTime.now().toIso8601String(),
        'lastLogin': DateTime.now().toIso8601String(),
        'displayName': 'Eco Traveler',
        'carbonSaved': 0.0,
        'tripsCompleted': 0,
        'ecoScore': 0,
        'preferences': {
          'transportMode': 'balanced',
          'notifications': false,
          'darkMode': true,
        },
      };

      await _secureStorage.write(
        key: 'user_$userId',
        value: jsonEncode(guestData),
      );

      _currentUser = user;
      await _secureStorage.write(key: 'current_user_id', value: userId);

      return user;
    } catch (e) {
      if (kDebugMode) {
        print('Guest login error: $e');
      }
      throw 'Guest login failed: $e';
    }
  }

  // ========== HELPER METHODS ==========

  Future<void> _updateLastLogin(String userId) async {
    final userData = await _getUserData(userId);
    if (userData != null) {
      userData['lastLogin'] = DateTime.now().toIso8601String();
      await _secureStorage.write(
        key: 'user_$userId',
        value: jsonEncode(userData),
      );
    }
  }

  Future<Map<String, dynamic>?> _getUserData(String userId) async {
    final data = await _secureStorage.read(key: 'user_$userId');
    if (data != null) {
      return jsonDecode(data) as Map<String, dynamic>;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _getAllUsers() async {
    final allKeys = await _secureStorage.readAll();
    final users = <Map<String, dynamic>>[];

    for (final entry in allKeys.entries) {
      if (entry.key.startsWith('user_')) {
        final data = entry.value;
        final userData = jsonDecode(data) as Map<String, dynamic>;
        users.add(userData);
      }
    }

    return users;
  }

  String _generateUserId() {
    return 'user_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(10000)}';
  }

  Stream<User?> _createAuthStream() async* {
    yield _currentUser;
    final controller = StreamController<User?>();
    controller.close();
    yield* controller.stream;
  }

  // ========== PASSWORD RESET ==========

  Future<void> resetPassword(String email) async {
    try {
      const url = '$_baseUrl/forgot-password';

      if (kDebugMode) {
        print('Sending password reset request to: $url');
      }

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        print('Response status: ${response.statusCode}');
        print('Response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        if (responseData['status'] == 'success') {
          // Success - backend handled the request
          if (kDebugMode) {
            print('Password reset request successful for: $email');
          }
          return;
        } else {
          throw responseData['detail'] ?? 'Password reset failed';
        }
      } else if (response.statusCode == 400) {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        throw errorData['detail'] ?? 'Invalid request';
      } else {
        throw 'Server error: ${response.statusCode}';
      }
    } catch (e) {
      if (kDebugMode) {
        print('Password reset error: $e');
      }
      rethrow;
    }
  }

  // ========== SIGN OUT ==========

  Future<void> signOut() async {
    try {
      _currentUser = null;
      await _secureStorage.delete(key: 'current_user_id');
    } catch (e) {
      if (kDebugMode) {
        print('Sign out error: $e');
      }
      rethrow;
    }
  }

  // ========== DELETE ACCOUNT ==========

  Future<void> deleteAccount() async {
    try {
      final user = _currentUser;
      if (user != null) {
        // Delete user data
        await _secureStorage.delete(key: 'user_${user.uid}');
        await _secureStorage.delete(key: 'password_${user.uid}');
        await _secureStorage.delete(key: 'fastapi_user_${user.uid}');
        await _secureStorage.delete(key: 'current_user_id');

        _currentUser = null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Delete account error: $e');
      }
      throw 'Failed to delete account: $e';
    }
  }

  // ========== INITIALIZATION ==========

  Future<void> initialize() async {
    try {
      // Check for existing session
      final userId = await _secureStorage.read(key: 'current_user_id');
      if (userId != null) {
        final userData = await _getUserData(userId);
        if (userData != null) {
          _currentUser = User(
            uid: userData['uid'] as String? ?? '',
            email: userData['email'] as String?,
            displayName: userData['displayName'] as String?,
            photoURL: userData['photoURL'] as String?,
            isGuest: (userData['isGuest'] as bool?) ?? false,
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Initialization error: $e');
      }
    }
  }

  static Future<void> testConnection() async {}
}
