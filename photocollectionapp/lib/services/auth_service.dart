import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';

class AuthResult {
  final bool success;
  final String? message;

  AuthResult({required this.success, this.message});
}

class AuthService extends ChangeNotifier {
  final SupabaseClient client;

  late final StreamSubscription<AuthState> _authSub;

  AuthService(this.client) {
    _user = client.auth.currentUser;

    // Subscribe to auth state changes to let the app react.
    // + UI reacts automatically
    // + ViewModels get updates without polling
    // + Login/logout propagates instantly
    _authSub = client.auth.onAuthStateChange.listen((data) {
      logger.i('Auth state changed: ${data.event}');
      _updateAuthState(data.event, data.session?.user);
    });
  }

  @override
  void dispose() {
    // Subscription cleanup (important for memory safety)
    _authSub.cancel();
    super.dispose();
  }

  User? _user;

  User? get user => _user;

  void _updateAuthState(AuthChangeEvent event, User? newUser) {
    final userChanged = newUser?.id != _user?.id;
    _user = newUser;

    // Token refresh must notify listeners even when user id stays the same.
    final shouldNotify =
        userChanged ||
        event == AuthChangeEvent.initialSession ||
        event == AuthChangeEvent.tokenRefreshed;

    if (shouldNotify) {
      notifyListeners();
    }
  }

  Future<AuthResult> signInWithEmailOtp(String email) async {
    try {
      await client.auth.signInWithOtp(email: email);
      logger.i('OTP sent to $email');
      return AuthResult(success: true, message: 'OTP sent to $email');
    } on AuthException catch (e) {
      logger.e('Failed to send OTP: ${e.message}');
      return AuthResult(success: false, message: e.message);
    } catch (e) {
      logger.e('An unexpected error occurred: $e');
      return AuthResult(
        success: false,
        message: 'An unexpected error occurred',
      );
    }
  }

  Future<AuthResult> verifyOtp({
    required String email,
    required String token,
  }) async {
    try {
      final response = await client.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.email,
      );

      if (response.session == null || response.user == null) {
        logger.e('Invalid or expired OTP.');
        return AuthResult(success: false, message: 'Invalid or expired OTP.');
      }
      logger.i('Signed in successfully');
      return AuthResult(success: true, message: 'Signed in successfully');
    } on AuthException catch (e) {
      logger.e('OTP verification failed: ${e.message}');
      return AuthResult(success: false, message: e.message);
    } catch (e) {
      logger.e('Unexpected error: $e');
      return AuthResult(
        success: false,
        message: 'An unexpected error occurred',
      );
    }
  }

  Future<void> signOut() async {
    logger.d("Before logout: ${client.auth.currentUser?.id}");
    await client.auth.signOut(scope: SignOutScope.local);
    logger.d("After logout: ${client.auth.currentUser?.id}");
  }
}
