import 'package:flutter/foundation.dart';
import 'package:sustainable_travel_app/auth/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    // Initialize and listen for auth state changes
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Initialize the auth service (loads stored user session)
      await _authService.initialize();

      // Get the current user from auth service
      _user = _authService.currentUser;
      notifyListeners();
    } catch (e) {
      _setError('Failed to initialize auth: $e');
    }
  }

  // ========== REGISTRATION WITH FASTAPI ==========

  Future<void> registerWithEmail({
    required String email,
    required String password,
    required String name,
    String? username,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final newUser = await _authService.registerWithEmail(
        email: email,
        password: password,
        name: name,
        username: username,
      );

      if (newUser != null) {
        _user = newUser;
        notifyListeners();
      } else {
        _setError("Registration failed. Please try again.");
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // ========== LOGIN WITH FASTAPI ==========

  Future<void> loginWithEmail({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final success = await _authService.loginWithBackend(
        email: email,
        password: password,
      );

      if (success) {
        // Get the updated user from auth service
        _user = _authService.currentUser;
        notifyListeners();
      } else {
        _setError("Invalid email or password");
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // ========== SOCIAL LOGIN METHODS ==========

  Future<void> signInWithGoogle() async {
    _setLoading(true);
    _clearError();

    try {
      final googleUser = await _authService.signInWithGoogle();
      _user = googleUser;
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signInWithFacebook() async {
    _setLoading(true);
    _clearError();

    try {
      final facebookUser = await _authService.signInWithFacebook();
      _user = facebookUser;
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // ========== GUEST LOGIN ==========

  Future<void> loginAsGuest() async {
    _setLoading(true);
    _clearError();

    try {
      final guestUser = await _authService.loginAsGuest();
      _user = guestUser;
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // ========== PASSWORD MANAGEMENT ==========

  Future<void> resetPassword(String email) async {
    _setLoading(true);
    _clearError();

    try {
      await _authService.resetPassword(email);
      // Show success message
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // ========== PROFILE MANAGEMENT ==========

  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    _setLoading(true);
    _clearError();

    try {
      await _authService.updateUserProfile(data);

      // Update local user if needed
      if (_user != null && data.containsKey('displayName')) {
        final updatedUser = User(
          uid: _user!.uid,
          email: _user!.email,
          displayName: data['displayName'] as String?,
          photoURL: data['photoURL'] as String? ?? _user!.photoURL,
          isGuest: _user!.isGuest,
        );
        _user = updatedUser;
      }

      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // ========== SESSION MANAGEMENT ==========

  Future<void> signOut() async {
    _setLoading(true);
    _clearError();

    try {
      await _authService.signOut();
      _user = null;
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteAccount() async {
    _setLoading(true);
    _clearError();

    try {
      await _authService.deleteAccount();
      _user = null;
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // ========== USER DATA ==========

  Future<Map<String, dynamic>?> getUserData() async {
    if (_user == null) return null;

    try {
      return await _authService.getUserData(_user!.uid);
    } catch (e) {
      _setError('Failed to get user data: $e');
      return null;
    }
  }

  // ========== HELPER GETTERS ==========

  bool get isGuest => _user?.isGuest ?? false;

  String get displayName {
    if (_user == null) return 'Guest';
    return _user!.displayName ?? _user!.email?.split('@').first ?? 'Traveler';
  }

  String? get userEmail => _user?.email;

  String? get photoURL => _user?.photoURL;

  // ========== PRIVATE HELPERS ==========

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }
}
