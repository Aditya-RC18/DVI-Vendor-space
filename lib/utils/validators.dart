/// Password strength levels
enum PasswordStrength { weak, medium, strong }

/// Form validation utilities
class Validators {
  /// Validate email address
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email is required *';
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) return 'Enter a valid email address';
    return null;
  }

  /// Validate password with flexible rules
  /// Requires: 8+ characters AND at least 3 out of 4 character types
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required *';
    if (value.length < 8) return 'Min 8 characters required';

    // Count how many character type requirements are met
    int requirementsMet = 0;
    if (value.contains(RegExp(r'[A-Z]'))) requirementsMet++;
    if (value.contains(RegExp(r'[a-z]'))) requirementsMet++;
    if (value.contains(RegExp(r'[0-9]'))) requirementsMet++;
    if (value.contains(RegExp(r'[!@#\$&*~]'))) requirementsMet++;

    if (requirementsMet < 3) {
      return 'Must have 3 of: uppercase, lowercase, digit, special char';
    }

    return null;
  }

  /// Validate Full Name (at least 2 words)
  static String? validateFullName(String? value) {
    if (value == null || value.isEmpty) return 'Full Name is required *';
    if (value.trim().split(' ').length < 2) {
      return 'Enter full name (First & Last)';
    }
    return null;
  }

  /// Validate Phone Number
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) return 'Phone is required *';
    if (!RegExp(r'^\d{10}$').hasMatch(value)) {
      return 'Enter valid 10-digit number';
    }
    return null;
  }

  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }

    if (value != password) {
      return 'Passwords do not match';
    }

    return null;
  }

  /// Generic required field validator
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Calculate password strength based on requirements met
  /// Weak: < 8 chars OR < 3 requirements
  /// Medium: 8+ chars AND 3 requirements
  /// Strong: 8+ chars AND all 4 requirements
  static PasswordStrength getPasswordStrength(String password) {
    if (password.isEmpty || password.length < 8) return PasswordStrength.weak;

    final requirements = getPasswordRequirements(password);
    final metCount = requirements.values
        .where((met) => met)
        .skip(1)
        .where((met) => met)
        .length; // Skip minLength, count character types

    if (metCount < 3) return PasswordStrength.weak;
    if (metCount == 3) return PasswordStrength.medium;
    return PasswordStrength.strong; // All 4 character types
  }

  /// Get individual password requirements and their met status
  static Map<String, bool> getPasswordRequirements(String password) {
    return {
      'minLength': password.length >= 8,
      'hasUppercase': password.contains(RegExp(r'[A-Z]')),
      'hasLowercase': password.contains(RegExp(r'[a-z]')),
      'hasDigit': password.contains(RegExp(r'[0-9]')),
      'hasSpecialChar': password.contains(RegExp(r'[!@#\$&*~]')),
    };
  }

  /// Get human-readable requirement description
  static String getRequirementDescription(String key) {
    switch (key) {
      case 'minLength':
        return 'At least 8 characters';
      case 'hasUppercase':
        return 'Contains uppercase letter (A-Z)';
      case 'hasLowercase':
        return 'Contains lowercase letter (a-z)';
      case 'hasDigit':
        return 'Contains number (0-9)';
      case 'hasSpecialChar':
        return 'Contains special character (!@#\$&*~)';
      default:
        return '';
    }
  }
}
