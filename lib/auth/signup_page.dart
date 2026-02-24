import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
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

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  // Account type — null means "none selected"
  String? _selectedRole;

  // Real-time validation tracking
  String _currentPassword = '';
  String _currentConfirmPassword = '';
  String _currentEmail = '';

  // Pre-calculated colors
  static const _fieldBgColor = Color(0x0DFFFFFF);
  static const _fieldBorderColor = Color(0x1AFFFFFF);
  static const _amberColor = Color(0xFFFFC107);
  static const _amberIconColor = Color(0xB3FFC107);
  static const _amberGlowColor = Color(0x26FFC107);

  // Role options
  static const _roleOptions = [
    _RoleOption(
      value: 'venue_distributor',
      label: 'Venue Distributor',
      subtitle: 'Manage wedding venues',
      icon: Icons.business,
    ),
    _RoleOption(
      value: 'vendor_distributor',
      label: 'Vendor Services',
      subtitle: 'Catering, photography, etc.',
      icon: Icons.store,
    ),
    _RoleOption(
      value: 'venue_vendor_distributor',
      label: 'Both (Venue & Services)',
      subtitle: 'Combined access',
      icon: Icons.business_center,
    ),
    _RoleOption(
      value: 'admin',
      label: 'Admin Account',
      subtitle: 'Requires approval',
      icon: Icons.admin_panel_settings,
      isSpecial: true,
    ),
  ];

  @override
  void dispose() {
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

  bool get _isEmailValid {
    return Validators.validateEmail(_currentEmail) == null;
  }

  bool get _isRoleSelected => _selectedRole != null;

  bool get _canSubmit {
    return _isRoleSelected &&
        _isEmailValid &&
        _isPasswordStrong &&
        _passwordsMatch;
  }

  void _showRoleRequiredSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please select an account type first'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_isRoleSelected) {
      _showRoleRequiredSnackBar();
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: {'role': _selectedRole},
      );

      if (response.user == null) throw 'Signup failed';

      // Main wrapper will route to CompleteProfilePage or AdminSetupPage
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (!_isRoleSelected) {
      _showRoleRequiredSnackBar();
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      setState(() => _isLoading = true);
      await AuthService().signInWithGoogle();
      // After OAuth, stamp the role onto user metadata
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'role': _selectedRole}),
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Google Sign-In failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleFacebookSignIn() async {
    if (!_isRoleSelected) {
      _showRoleRequiredSnackBar();
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      setState(() => _isLoading = true);
      await AuthService().signInWithFacebook();
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'role': _selectedRole}),
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Facebook Sign-In failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
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
                // Ambient glow
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
                            // Header
                            const Text(
                              'Create Account',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: _amberColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Join DreamVentz as a Vendor',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),

                            // ── Account Type ──────────────────────────────
                            _buildSectionLabel('Account Type'),
                            const SizedBox(height: 12),
                            _buildRoleSelector(),
                            const SizedBox(height: 24),

                            // ── Email ─────────────────────────────────────
                            _buildTextField(
                              label: 'Email Address',
                              hint: 'vendor@example.com',
                              prefixIcon: Icons.email_outlined,
                              controller: _emailController,
                              validator: Validators.validateEmail,
                              keyboardType: TextInputType.emailAddress,
                              onChanged: (v) =>
                                  setState(() => _currentEmail = v),
                            ),
                            if (_currentEmail.isNotEmpty)
                              _buildInlineIndicator(
                                valid: _isEmailValid,
                                validText: 'Valid email',
                                invalidText: 'Please enter a valid email',
                              ),
                            const SizedBox(height: 16),

                            // ── Password ──────────────────────────────────
                            _buildPasswordField(
                              controller: _passwordController,
                              label: 'Password',
                              isVisible: _isPasswordVisible,
                              onVisibilityChanged: () => setState(
                                () => _isPasswordVisible = !_isPasswordVisible,
                              ),
                              validator: Validators.validatePassword,
                              onChanged: (v) =>
                                  setState(() => _currentPassword = v),
                            ),
                            PasswordStrengthIndicator(
                              password: _currentPassword,
                            ),
                            const SizedBox(height: 16),

                            // ── Confirm Password ──────────────────────────
                            _buildPasswordField(
                              controller: _confirmPasswordController,
                              label: 'Confirm Password',
                              isVisible: _isConfirmPasswordVisible,
                              onVisibilityChanged: () => setState(
                                () => _isConfirmPasswordVisible =
                                    !_isConfirmPasswordVisible,
                              ),
                              validator: (val) =>
                                  val != _passwordController.text
                                  ? 'Passwords do not match'
                                  : null,
                              onChanged: (v) =>
                                  setState(() => _currentConfirmPassword = v),
                            ),
                            if (_currentConfirmPassword.isNotEmpty)
                              _buildInlineIndicator(
                                valid: _passwordsMatch,
                                validText: 'Passwords match',
                                invalidText: 'Passwords do not match',
                                invalidColor: Colors.red,
                                invalidIcon: Icons.cancel,
                              ),

                            const SizedBox(height: 32),

                            // ── Submit ────────────────────────────────────
                            ElevatedButton(
                              onPressed: (_isLoading || !_canSubmit)
                                  ? null
                                  : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _amberColor,
                                foregroundColor: Colors.black,
                                disabledBackgroundColor: _amberColor.withValues(
                                  alpha: 0.4,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : const Text(
                                      'Continue',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),

                            const SizedBox(height: 24),

                            // ── OR Divider ────────────────────────────────
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

                            const SizedBox(height: 16),

                            // ── OAuth Buttons (bottom) ─────────────────────
                            OAuthButton(
                              provider: 'google',
                              isLoading: _isLoading,
                              onPressed: _handleGoogleSignIn,
                            ),
                            const SizedBox(height: 12),
                            OAuthButton(
                              provider: 'facebook',
                              isLoading: _isLoading,
                              onPressed: _handleFacebookSignIn,
                            ),

                            const SizedBox(height: 24),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                'Already have an account? Login',
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

  // ── Role Selector ──────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.grey[300],
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Container(
      decoration: BoxDecoration(
        color: _fieldBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isRoleSelected ? _amberColor : _fieldBorderColor,
          width: _isRoleSelected ? 1.5 : 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedRole,
          dropdownColor: const Color(0xFF1A1A1A),
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: _amberColor),
          hint: Row(
            children: [
              const Icon(Icons.badge_outlined, color: Colors.grey, size: 20),
              const SizedBox(width: 12),
              Text(
                'Select account type',
                style: TextStyle(color: Colors.grey[500], fontSize: 15),
              ),
            ],
          ),
          style: const TextStyle(color: Colors.white, fontSize: 15),
          items: _roleOptions
              .map(
                (opt) => DropdownMenuItem<String>(
                  value: opt.value,
                  child: _buildRoleItem(opt),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _selectedRole = v),
        ),
      ),
    );
  }

  Widget _buildRoleItem(_RoleOption opt) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(opt.icon, color: _amberColor, size: 20),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      opt.label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (opt.isSpecial) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: const Text(
                        'APPROVAL',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 7,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                opt.subtitle,
                style: TextStyle(color: Colors.grey[500], fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _buildInlineIndicator({
    required bool valid,
    required String validText,
    required String invalidText,
    Color invalidColor = Colors.orange,
    IconData invalidIcon = Icons.info_outline,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4),
      child: Row(
        children: [
          Icon(
            valid ? Icons.check_circle : invalidIcon,
            color: valid ? Colors.green : invalidColor,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            valid ? validText : invalidText,
            style: TextStyle(
              color: valid ? Colors.green : invalidColor,
              fontSize: 12,
            ),
          ),
        ],
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
              hintText: '••••••••',
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

// ── Data class ──────────────────────────────────────────────────────────────

class _RoleOption {
  final String value;
  final String label;
  final String subtitle;
  final IconData icon;
  final bool isSpecial;

  const _RoleOption({
    required this.value,
    required this.label,
    required this.subtitle,
    required this.icon,
    this.isSpecial = false,
  });
}
