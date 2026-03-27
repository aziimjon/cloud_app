import 'package:flutter/material.dart';
import '../data/auth_repository.dart';
import '../../../core/errors/app_exception.dart';
import 'login_page.dart';

class ResetPasswordPage extends StatefulWidget {
  final String otpKey;
  final int otpCode;

  const ResetPasswordPage({
    super.key,
    required this.otpKey,
    required this.otpCode,
  });

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authRepo = AuthRepository();

  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;
  String? _success;

  bool _passwordTouched = false;
  bool _confirmTouched = false;

  bool get _isPasswordValid => _passwordController.text.length >= 8;
  bool get _isConfirmValid =>
      _confirmPasswordController.text == _passwordController.text &&
      _confirmPasswordController.text.isNotEmpty;
  bool get _isFormValid => _isPasswordValid && _isConfirmValid;

  @override
  void initState() {
    super.initState();
    _passwordFocus.addListener(() {
      if (!_passwordFocus.hasFocus && !_passwordTouched) {
        setState(() => _passwordTouched = true);
      }
    });
    _confirmFocus.addListener(() {
      if (!_confirmFocus.hasFocus && !_confirmTouched) {
        setState(() => _confirmTouched = true);
      }
    });
  }

  Future<void> _resetPassword() async {
    setState(() {
      _passwordTouched = true;
      _confirmTouched = true;
    });
    if (!_isFormValid) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _success = null;
    });

    try {
      await _authRepo.resetPassword(
        otpKey: widget.otpKey,
        otpCode: widget.otpCode,
        password: _passwordController.text,
        confirmPassword: _confirmPasswordController.text,
      );
      setState(() => _success = 'Password reset successfully!');
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
        );
      }
    } on AppException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A73E8).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.lock_rounded,
                    color: Color(0xFF1A73E8), size: 28),
              ),

              const SizedBox(height: 24),

              const Text(
                'Set New Password',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create a strong password with at least 8 characters.',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),

              const SizedBox(height: 40),

              // Password
              const Text(
                'New Password',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                focusNode: _passwordFocus,
                obscureText: _obscurePassword,
                style: const TextStyle(fontSize: 15),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Enter new password',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: const Color(0xFFF5F7FA),
                  prefixIcon: Container(
                    margin: const EdgeInsets.all(10),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A73E8).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.lock_rounded,
                        color: Color(0xFF1A73E8), size: 18),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: Colors.grey[400],
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFF1A73E8),
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
              if (_passwordTouched && !_isPasswordValid) ...[
                const SizedBox(height: 6),
                const Text(
                  'Минимум 8 символов',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],

              const SizedBox(height: 16),

              // Confirm Password
              const Text(
                'Confirm Password',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmPasswordController,
                focusNode: _confirmFocus,
                obscureText: _obscureConfirm,
                style: const TextStyle(fontSize: 15),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _resetPassword(),
                decoration: InputDecoration(
                  hintText: 'Confirm new password',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: const Color(0xFFF5F7FA),
                  prefixIcon: Container(
                    margin: const EdgeInsets.all(10),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A73E8).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.lock_outline_rounded,
                        color: Color(0xFF1A73E8), size: 18),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: Colors.grey[400],
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFF1A73E8),
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
              if (_confirmTouched && !_isConfirmValid) ...[
                const SizedBox(height: 6),
                const Text(
                  'Пароли не совпадают',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                              color: Colors.red, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_success != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          color: Colors.green, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _success!,
                          style: const TextStyle(
                              color: Colors.green, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading || !_isFormValid
                      ? null
                      : _resetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A73E8),
                    disabledBackgroundColor:
                        const Color(0xFF1A73E8).withValues(alpha: 0.4),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Reset Password',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
