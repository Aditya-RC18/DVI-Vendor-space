import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/validators.dart';
import '../widgets/password_strength_indicator.dart';
import '../widgets/oauth_button.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  // Real-time validation tracking
  String _currentPassword = '';
  String _currentConfirmPassword = '';
  String _currentName = '';
  String _currentEmail = '';

  // Pre-calculated colors to avoid rebuilding on every keystroke
  static const _fieldBgColor = Color(0x0DFFFFFF); // white with 0.05 opacity
  static const _fieldBorderColor = Color(0x1AFFFFFF); // white with 0.1 opacity
  static const _amberColor = Color(0xFFFFC107);
  static const _amberIconColor = Color(0xB3FFC107); // amber with 0.7 opacity
  static const _amberGlowColor = Color(0x26FFC107); // amber with 0.15 opacity

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Validation getters
  bool get _isPasswordStrong {
    final strength = Validators.getPasswordStrength(_currentPassword);
    return strength == PasswordStrength.medium ||
        strength == PasswordStrength.strong;
  }

  bool get _passwordsMatch {
    return _currentPassword.isNotEmpty &&
        _currentConfirmPassword.isNotEmpty &&
        _currentPassword == _currentConfirmPassword;
  }

  bool get _isNameValid {
    return Validators.validateFullName(_currentName) == null;
  }

  bool get _isEmailValid {
    return Validators.validateEmail(_currentEmail) == null;
  }

  bool get _canSubmit {
    return _isNameValid &&
        _isEmailValid &&
        _isPasswordStrong &&
        _passwordsMatch;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: {'full_name': _nameController.text.trim()},
      );

      if (response.user == null) throw "Signup failed";

      // Auto-login after signup
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/',
        ); // Main wrapper will route to CompleteProfilePage
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;

          return Container(
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0A0A0A), Color(0xFF121212), Colors.black],
              ),
            ),
            child: Stack(
              children: [
                // Background Elements - const to avoid rebuilding
                Positioned(
                  top: -size.height * 0.15,
                  right: -size.width * 0.2,
                  child: Container(
                    width: size.width * 0.7,
                    height: size.width * 0.7,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [_amberGlowColor, Colors.transparent],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              "Create Account",
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: _amberColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Join DreamVentz as a Vendor",
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),

                            // OAuth Buttons (Placeholders)
                            OAuthButton(
                              provider: 'google',
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Google Sign-In coming soon! Configure OAuth in Supabase first.',
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            OAuthButton(
                              provider: 'facebook',
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Facebook Sign-In coming soon! Configure OAuth in Supabase first.',
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 24),

                            // Divider
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(color: Colors.grey[700]),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Text(
                                    'OR',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(color: Colors.grey[700]),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            _buildTextField(
                              label: "Full Name",
                              hint: "John Doe",
                              prefixIcon: Icons.person_outline,
                              controller: _nameController,
                              validator: Validators.validateFullName,
                              onChanged: (value) {
                                setState(() => _currentName = value);
                              },
                            ),
                            if (_currentName.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8, left: 4),
                                child: Row(
                                  children: [
                                    Icon(
                                      _isNameValid
                                          ? Icons.check_circle
                                          : Icons.info_outline,
                                      color: _isNameValid
                                          ? Colors.green
                                          : Colors.orange,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _isNameValid
                                          ? 'Valid name'
                                          : 'Please enter your full name',
                                      style: TextStyle(
                                        color: _isNameValid
                                            ? Colors.green
                                            : Colors.orange,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              label: "Email Address",
                              hint: "vendor@example.com",
                              prefixIcon: Icons.email_outlined,
                              controller: _emailController,
                              validator: Validators.validateEmail,
                              keyboardType: TextInputType.emailAddress,
                              onChanged: (value) {
                                setState(() => _currentEmail = value);
                              },
                            ),
                            if (_currentEmail.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8, left: 4),
                                child: Row(
                                  children: [
                                    Icon(
                                      _isEmailValid
                                          ? Icons.check_circle
                                          : Icons.info_outline,
                                      color: _isEmailValid
                                          ? Colors.green
                                          : Colors.orange,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _isEmailValid
                                          ? 'Valid email'
                                          : 'Please enter a valid email',
                                      style: TextStyle(
                                        color: _isEmailValid
                                            ? Colors.green
                                            : Colors.orange,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 16),
                            _buildPasswordField(
                              controller: _passwordController,
                              label: "Password",
                              isVisible: _isPasswordVisible,
                              onVisibilityChanged: () => setState(
                                () => _isPasswordVisible = !_isPasswordVisible,
                              ),
                              validator: Validators.validatePassword,
                              onChanged: (value) {
                                setState(() => _currentPassword = value);
                              },
                            ),
                            // Password strength indicator
                            PasswordStrengthIndicator(
                              password: _currentPassword,
                            ),
                            const SizedBox(height: 16),
                            _buildPasswordField(
                              controller: _confirmPasswordController,
                              label: "Confirm Password",
                              isVisible: _isConfirmPasswordVisible,
                              onVisibilityChanged: () => setState(
                                () => _isConfirmPasswordVisible =
                                    !_isConfirmPasswordVisible,
                              ),
                              validator: (val) =>
                                  val != _passwordController.text
                                  ? "Passwords do not match"
                                  : null,
                              onChanged: (value) {
                                setState(() => _currentConfirmPassword = value);
                              },
                            ),
                            // Password match indicator
                            if (_currentConfirmPassword.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8, left: 4),
                                child: Row(
                                  children: [
                                    Icon(
                                      _passwordsMatch
                                          ? Icons.check_circle
                                          : Icons.cancel,
                                      color: _passwordsMatch
                                          ? Colors.green
                                          : Colors.red,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _passwordsMatch
                                          ? 'Passwords match'
                                          : 'Passwords do not match',
                                      style: TextStyle(
                                        color: _passwordsMatch
                                            ? Colors.green
                                            : Colors.red,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            const SizedBox(height: 32),
                            ElevatedButton(
                              onPressed: (_isLoading || !_canSubmit)
                                  ? null
                                  : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _amberColor,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator()
                                  : const Text(
                                      "Continue",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 24),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                "Already have an account? Login",
                                style: TextStyle(color: _amberColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required IconData prefixIcon,
    required TextEditingController controller,
    required String? Function(String?)? validator,
    TextInputType? keyboardType,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[300],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: const BoxDecoration(
            color: _fieldBgColor,
            borderRadius: BorderRadius.all(Radius.circular(12)),
            border: Border.fromBorderSide(BorderSide(color: _fieldBorderColor)),
          ),
          child: TextFormField(
            controller: controller,
            validator: validator,
            keyboardType: keyboardType,
            onChanged: onChanged,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[500]),
              border: InputBorder.none,
              prefixIcon: Icon(prefixIcon, color: _amberIconColor),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool isVisible,
    required VoidCallback onVisibilityChanged,
    required String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[300],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: const BoxDecoration(
            color: _fieldBgColor,
            borderRadius: BorderRadius.all(Radius.circular(12)),
            border: Border.fromBorderSide(BorderSide(color: _fieldBorderColor)),
          ),
          child: TextFormField(
            controller: controller,
            validator: validator,
            obscureText: !isVisible,
            onChanged: onChanged,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "••••••••",
              hintStyle: TextStyle(color: Colors.grey[500]),
              border: InputBorder.none,
              prefixIcon: const Icon(
                Icons.lock_outline,
                color: _amberIconColor,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  isVisible ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey[500],
                ),
                onPressed: onVisibilityChanged,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
