import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/services/firebase_auth_service.dart';

enum AuthScreen { splash, login, register, forgotPassword, verifyEmail, home }

final authProvider = ChangeNotifierProvider<AuthProvider>((ref) => AuthProvider());

class AuthProvider extends ChangeNotifier {
  final FirebaseAuthService _authService = FirebaseAuthService.instance;

  AuthScreen _currentScreen = AuthScreen.splash;
  AuthScreen get currentScreen => _currentScreen;

  void goTo(AuthScreen screen) {
    _currentScreen = screen;
    _error = null;
    notifyListeners();
  }

  User? get user => _authService.currentUser;
  bool get isLoggedIn => _authService.isLoggedIn;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get emailVerified => _emailVerified;

  bool _isLoading = false;
  String? _error;
  bool _emailVerified = false;

  String _fullName = '';
  String _email = '';
  String _password = '';

  void setFullName(String v) => _fullName = v;
  void setEmail(String v) => _email = v;
  void setPassword(String v) => _password = v;

  Future<bool> login() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _authService.signIn(email: _email, password: _password);

    _isLoading = false;
    if (!result.success) {
      _error = result.error;
      notifyListeners();
      return false;
    }

    _currentScreen = AuthScreen.home;
    notifyListeners();
    return true;
  }

  Future<bool> register() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _authService.signUp(
      email: _email,
      password: _password,
      displayName: _fullName,
    );

    _isLoading = false;
    if (!result.success) {
      _error = result.error;
      notifyListeners();
      return false;
    }

    _currentScreen = AuthScreen.home;
    notifyListeners();
    return true;
  }

  Future<bool> sendPasswordReset() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _authService.sendPasswordReset(_email);

    _isLoading = false;
    if (!result.success) {
      _error = result.error;
      notifyListeners();
      return false;
    }
    notifyListeners();
    return true;
  }

  Future<bool> resendVerification() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _authService.sendEmailVerification();

    _isLoading = false;
    if (!result.success) {
      _error = result.error;
      notifyListeners();
      return false;
    }
    notifyListeners();
    return true;
  }

  Future<bool> checkEmailVerified() async {
    _isLoading = true;
    notifyListeners();

    final verified = await _authService.isEmailVerified();
    _emailVerified = verified;

    _isLoading = false;
    if (verified) {
      _currentScreen = AuthScreen.home;
    }
    notifyListeners();
    return verified;
  }

  Future<void> logout() async {
    await _authService.signOut();
    _currentScreen = AuthScreen.login;
    _emailVerified = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final regex = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,}$');
    if (!regex.hasMatch(value.trim())) return 'Enter a valid email address';
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Name is required';
    if (value.trim().length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  String? validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != _password) return 'Passwords do not match';
    return null;
  }
}
