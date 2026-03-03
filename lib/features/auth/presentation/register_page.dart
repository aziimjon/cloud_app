import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/auth_repository.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/uzbek_phone_formatter.dart';
import 'otp_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController(text: '+998 ');
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authRepo = AuthRepository();

  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _error;

  bool _phoneTouched = false;
  bool _passwordTouched = false;
  bool _confirmPasswordTouched = false;

  String _rawPhone() => _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');

  bool get _isPhoneValid => _rawPhone().length == 12;
  bool get _isPasswordValid => _passwordController.text.length >= 8;
  bool get _isConfirmValid =>
      _confirmPasswordController.text == _passwordController.text &&
      _confirmPasswordController.text.isNotEmpty;
  bool get _isFormValid =>
      _nameController.text.trim().isNotEmpty &&
      _isPhoneValid &&
      _isPasswordValid &&
      _isConfirmValid;

  @override
  void initState() {
    super.initState();
    _phoneFocus.addListener(() {
      if (!_phoneFocus.hasFocus && !_phoneTouched) {
        setState(() => _phoneTouched = true);
      }
    });
    _passwordFocus.addListener(() {
      if (!_passwordFocus.hasFocus && !_passwordTouched) {
        setState(() => _passwordTouched = true);
      }
    });
    _confirmPasswordFocus.addListener(() {
      if (!_confirmPasswordFocus.hasFocus && !_confirmPasswordTouched) {
        setState(() => _confirmPasswordTouched = true);
      }
    });
  }

  Future<void> _register() async {
    setState(() {
      _phoneTouched = true;
      _passwordTouched = true;
      _confirmPasswordTouched = true;
    });

    if (!_isFormValid) return;

    final name = _nameController.text.trim();
    final phone = '+${_rawPhone()}';
    final password = _passwordController.text;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final otpKey = await _authRepo.register(
        fullName: name,
        phoneNumber: phone,
        password: password,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpPage(phoneNumber: phone, otpKey: otpKey),
          ),
        );
      }
    } on AppException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
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
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
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
              const Text(
                'Create Account',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Register a new user with phone number.',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
              const SizedBox(height: 32),

              // Full Name
              _buildField(
                label: 'Full Name',
                hint: 'John Doe',
                controller: _nameController,
                icon: Icons.person_rounded,
              ),
              const SizedBox(height: 16),

              // Phone Number
              _buildField(
                label: 'Phone Number',
                hint: '+998 XX XXX XX XX',
                controller: _phoneController,
                icon: Icons.phone_rounded,
                keyboardType: TextInputType.phone,
                focusNode: _phoneFocus,
                inputFormatters: [UzbekPhoneFormatter()],
              ),
              if (_phoneTouched && !_isPhoneValid) ...[
                const SizedBox(height: 6),
                const Text(
                  'Неверный номер телефона',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
              const SizedBox(height: 16),

              // Password
              _buildField(
                label: 'Password',
                hint: 'Enter your password',
                controller: _passwordController,
                icon: Icons.lock_rounded,
                obscure: _obscurePassword,
                focusNode: _passwordFocus,
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
              _buildField(
                label: 'Confirm Password',
                hint: 'Повторите пароль',
                controller: _confirmPasswordController,
                icon: Icons.lock_outline_rounded,
                obscure: _obscureConfirmPassword,
                focusNode: _confirmPasswordFocus,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: Colors.grey[400],
                    size: 20,
                  ),
                  onPressed: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  ),
                ),
              ),
              if (_confirmPasswordTouched && !_isConfirmValid) ...[
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
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                          ),
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
                  onPressed: _isLoading || !_isFormValid ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A73E8),
                    disabledBackgroundColor: const Color(
                      0xFF1A73E8,
                    ).withValues(alpha: 0.4),
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
                          'Send OTP Code',
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

  Widget _buildField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    FocusNode? focusNode,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          focusNode: focusNode,
          inputFormatters: inputFormatters,
          style: const TextStyle(fontSize: 15),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: hint,
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
              child: Icon(icon, color: const Color(0xFF1A73E8), size: 18),
            ),
            suffixIcon: suffixIcon,
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
      ],
    );
  }
}
