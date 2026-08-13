import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/auth_viewmodel.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();

  static const String textEmail ='Email';
  static const String textRequestOTP ='Request password';
  static const String textWaiting = 'Waiting';
  static const String textSentOTP = 'One-time-password was sent to your email inbox';
  static const String textEnterOTP = 'Enter one-time-password';
  static const String textSignIn = 'Sign in';

  //TODO: Add validation to email address text.
  String get _emailText => _emailController.text.trim();

  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() {
      _cooldownSeconds = 60;
    });

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() {
          _cooldownSeconds = 0;
        });
      } else {
        setState(() {
          _cooldownSeconds--;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();

    // Handle messages safely and show in UI.
    final message = vm.fetchMessage();
    if (message != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text(textSignIn)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Email address input.
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: textEmail),
            ),

            const SizedBox(height: 12),

            // Send (and resend) OTP button.
            ElevatedButton(
              onPressed: (vm.isLoading || _cooldownSeconds > 0)
                ? null // Button disabled
                : () async {
                  if (await vm.sendOtp(email: _emailText)) {
                    _startCooldown();
                  }
                },
              child: vm.isLoading //&& !vm.otpSent
                ? const SizedBox(width: 20, height:20, child: CircularProgressIndicator(strokeWidth: 2))
                : (_cooldownSeconds > 0) ? Text("$textWaiting $_cooldownSeconds s") : const Text(textRequestOTP),
            ),

            const SizedBox(height: 12),

            // Helper status text.
            if (vm.otpSent)
              const Text(
                textSentOTP,
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),

            const SizedBox(height: 20),

            // OTP section
            if (vm.otpSent) ...[
              TextField(
                controller: _otpController,
                decoration: const InputDecoration(labelText: textEnterOTP),
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed:
                    vm.isLoading
                        ? null
                        : () async {
                          final token = _otpController.text.trim();
                          await vm.verifyOtp(_emailText, token);

                          // Clear OTP field AFTER successful verification
                          if (!vm.otpSent) {
                            _otpController.clear();
                          }
                        },
                child:
                    vm.isLoading
                        ? const CircularProgressIndicator()
                        : const Text(textSignIn),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
