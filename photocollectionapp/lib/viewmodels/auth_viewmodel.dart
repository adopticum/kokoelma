import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthService auth;

  AuthViewModel(this.auth);

  // The viewmodel will handle the state to keep the UI stateless.
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _otpSent = false;
  bool get otpSent => _otpSent;

  String? _message;

  // This should only be read by session wrapper, never polled from services or viewmodels during session.
  //String? get userId => auth.userId;

  /// Reset local UI state
  void _resetState() {
    _otpSent = false;
    _message = null;
  }

  // Let UI fetch the message and clear it to prevent repeat.
  String? fetchMessage() {
    final msg = _message;
    _message = null;
    return msg;
  }

  Future<bool> sendOtp({required String email}) async {
    _isLoading = true;
    _message = null;
    notifyListeners();

    final result = await auth.signInWithEmailOtp(email);

    _otpSent = result.success;
    _message = result.message;

    _isLoading = false;
    notifyListeners();

    return result.success;
  }

  Future<void> verifyOtp(String email, String token) async {
    _isLoading = true;
    _message = null;
    notifyListeners();

    final result = await auth.verifyOtp(email: email, token: token);

    _message = result.message;

    if (result.success) {
      _resetState();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    await auth.signOut();

    _resetState();
    notifyListeners();
  }
}
