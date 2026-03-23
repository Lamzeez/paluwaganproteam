import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'home_view.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;

  const OtpVerificationScreen({super.key, required this.email});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  static const int _resendCooldownSeconds = 60;

  String? _errorMessage;
  Timer? _resendTimer;
  int _remainingResendSeconds = 0;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authVm = context.read<AuthViewModel>();
      _syncCooldownFromLastSent(authVm.lastVerificationEmailSentAt);
    });
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _resendTimer?.cancel();
    super.dispose();
  }

  bool _isVerifying = false;

  void _onOtpChanged(String value, int index) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    // Check if all fields are filled - but don't auto-verify to avoid race conditions
    // Let the user click the button instead, or add a small delay
  }

  Future<void> _verifyOtp() async {
    if (_isVerifying) return; // Prevent double taps

    final otp = _controllers.map((c) => c.text).join();
    if (otp.length < 6) {
      setState(() => _errorMessage = 'Please enter all 6 digits');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final authVm = context.read<AuthViewModel>();

    try {
      final success = await authVm.verifyEmailOTP(widget.email, otp);

      if (success && mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => DashboardScreen(user: authVm.currentUser!),
          ),
          (route) => false,
        );
      } else {
        setState(() {
          _errorMessage = authVm.errorMessage ?? 'Invalid or expired code';
          _isVerifying = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
        _isVerifying = false;
      });
    }
  }

  void _startResendCooldown([int seconds = _resendCooldownSeconds]) {
    _resendTimer?.cancel();
    setState(() {
      _remainingResendSeconds = seconds;
    });

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_remainingResendSeconds <= 1) {
        timer.cancel();
        setState(() {
          _remainingResendSeconds = 0;
        });
        return;
      }

      setState(() {
        _remainingResendSeconds--;
      });
    });
  }

  void _syncCooldownFromLastSent(DateTime? sentAt) {
    if (sentAt == null) return;

    final elapsed = DateTime.now().difference(sentAt).inSeconds;
    final remaining = _resendCooldownSeconds - elapsed;
    if (remaining > 0) {
      _startResendCooldown(remaining);
    } else {
      _resendTimer?.cancel();
      setState(() {
        _remainingResendSeconds = 0;
      });
    }
  }

  int? _extractRemainingSeconds(String? message) {
    if (message == null) return null;
    final match = RegExp(r'after\s+(\d+)\s+seconds?', caseSensitive: false)
        .firstMatch(message);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  Future<void> _resendCode() async {
    if (_isResending || _remainingResendSeconds > 0) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    final authVm = context.read<AuthViewModel>();
    final success = await authVm.resendEmailOTP(widget.email);

    if (!mounted) return;

    setState(() {
      _isResending = false;
      if (!success) {
        _errorMessage =
            authVm.errorMessage ?? 'Failed to resend verification code';
      }
    });

    if (success) {
      _syncCooldownFromLastSent(authVm.lastVerificationEmailSentAt);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('A new verification code was sent to ${widget.email}'),
        ),
      );
    } else {
      final remaining = _extractRemainingSeconds(authVm.errorMessage);
      if (remaining != null && remaining > 0) {
        _startResendCooldown(remaining);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.mark_email_read_outlined,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),
            const Text(
              'Verification Code',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'We sent a 6-digit code to ${widget.email}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (index) {
                return SizedBox(
                  width: 45,
                  child: TextField(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (value) => _onOtpChanged(value, index),
                  ),
                );
              }),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: authVm.isLoading ? null : _verifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: authVm.isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('VERIFY & REGISTER'),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: (_isResending ||
                      authVm.isLoading ||
                      _remainingResendSeconds > 0)
                  ? null
                  : _resendCode,
              child: Text(
                _isResending
                    ? 'Sending...'
                    : _remainingResendSeconds > 0
                    ? 'Resend Code (${_remainingResendSeconds}s)'
                    : 'Resend Code',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
