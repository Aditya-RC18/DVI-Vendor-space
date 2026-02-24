import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:country_picker/country_picker.dart';
import '../utils/constants.dart';
import '../utils/validators.dart';
import 'business_details_page.dart';

class CompleteVendorProfilePage extends StatefulWidget {
  const CompleteVendorProfilePage({super.key});

  @override
  State<CompleteVendorProfilePage> createState() =>
      _CompleteVendorProfilePageState();
}

class _CompleteVendorProfilePageState extends State<CompleteVendorProfilePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // ── About Yourself ──────────────────────────────────────────────────────────
  final _nameController = TextEditingController();
  final _dobController = TextEditingController(); // Date of Birth
  final _phoneController = TextEditingController();
  String _selectedCountryCode = '91';

  // ── About Business ──────────────────────────────────────────────────────────
  final _businessNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();

  // Optional business contact numbers (phone or telephone)
  final List<_BusinessContact> _businessContacts = [];

  // Display only — from auth
  String? _displayEmail;

  // ── Pre-calculated constants ─────────────────────────────────────────────
  static const _fieldBgColor = Color(0x0DFFFFFF);
  static const _fieldBorderColor = Color(0x1AFFFFFF);
  static const _amberColor = Color(0xFFFFC107);
  static const _amberIconColor = Color(0xB3FFC107);

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  void _fetchUserData() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    _displayEmail = user.email;

    // Try to load an already-saved row first (back-nav from page 3)
    Supabase.instance.client
        .from('vendors')
        .select()
        .eq('id', user.id)
        .maybeSingle()
        .then((row) {
          if (!mounted) return;
          if (row != null) {
            // Restore all fields from the existing DB row
            setState(() {
              _nameController.text = row['full_name'] ?? '';
              _dobController.text = row['date_of_birth'] ?? '';
              _businessNameController.text = row['business_name'] ?? '';
              _addressController.text = row['address'] ?? '';
              _cityController.text = row['city'] ?? '';
              _stateController.text = row['state'] ?? '';
              _pincodeController.text = row['pincode'] ?? '';

              // Parse stored phone "+CC localNumber"
              final rawPhone = (row['phone'] ?? '') as String;
              if (rawPhone.startsWith('+')) {
                final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
                if (digits.length > 10) {
                  _selectedCountryCode = digits.substring(
                    0,
                    digits.length - 10,
                  );
                  _phoneController.text = digits.substring(digits.length - 10);
                } else {
                  _phoneController.text = rawPhone;
                }
              } else {
                _phoneController.text = rawPhone;
              }

              // Restore business contacts
              final contacts = (row['business_contacts'] as List?) ?? [];
              _businessContacts.clear();
              for (final c in contacts) {
                final bc = _BusinessContact();
                // Format stored: "+CC localNumber" or "+CC xxx-xxxxx"
                final s = c.toString();
                if (s.startsWith('+')) {
                  final spaceIdx = s.indexOf(' ');
                  if (spaceIdx != -1) {
                    bc.countryCode = s.substring(1, spaceIdx);
                    bc.controller.text = s.substring(spaceIdx + 1);
                  } else {
                    bc.controller.text = s;
                  }
                } else {
                  bc.controller.text = s;
                }
                // Heuristic: digits-only means mobile; hyphens mean telephone
                bc.isMobile = !bc.controller.text.contains('-');
                _businessContacts.add(bc);
              }
            });
          } else {
            // No row yet — pre-fill name from OAuth metadata only
            final metaName = user.userMetadata?['full_name'];
            if (metaName != null && metaName.toString().isNotEmpty) {
              _nameController.text = metaName.toString();
            }
          }
        });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    _businessNameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    for (final c in _businessContacts) {
      c.controller.dispose();
    }
    super.dispose();
  }

  // ── Date picker ──────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1940),
      lastDate: DateTime(now.year - 18, now.month, now.day),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _amberColor,
            onPrimary: Colors.black,
            surface: Color(0xFF1A1A1A),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _dobController.text =
            '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      });
    }
  }

  // ── Business contact helpers ─────────────────────────────────────────────
  void _addBusinessContact() {
    setState(() {
      _businessContacts.add(_BusinessContact());
    });
  }

  void _removeBusinessContact(int index) {
    final contact = _businessContacts.removeAt(index);
    contact.controller.dispose();
    setState(() {});
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submitProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw 'User not authenticated';

      final role = user.userMetadata?['role'] as String? ?? 'venue_distributor';

      // Effective contact: first business contact if provided, else personal phone
      final personalPhone =
          '+$_selectedCountryCode ${_phoneController.text.trim()}';
      final businessContactNumbers = _businessContacts
          .map((c) => '+${c.countryCode} ${c.controller.text.trim()}')
          .where((t) => t.trim().isNotEmpty)
          .toList();

      final data = <String, dynamic>{
        'id': user.id,
        'email': user.email,
        'full_name': _nameController.text.trim(),
        'date_of_birth': _dobController.text.trim(),
        'phone': personalPhone,
        'business_name': _businessNameController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'pincode': _pincodeController.text.trim(),
        'role': role,
        'verification_status': 'pending',
      };

      if (businessContactNumbers.isNotEmpty) {
        data['business_contacts'] = businessContactNumbers;
      }

      await Supabase.instance.client.from('vendors').insert(data);

      // Verify row exists
      final check = await Supabase.instance.client
          .from('vendors')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (check == null) {
        throw 'Profile creation verification failed. Please try again.';
      }

      if (mounted) {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const BusinessDetailsPage()));
      }
    } catch (e) {
      debugPrint('Profile Submit Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        // Back → sign out and return to login
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          tooltip: 'Back to Login',
          onPressed: () async {
            await Supabase.instance.client.auth.signOut();
            if (context.mounted) {
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil(AppConstants.loginRoute, (r) => false);
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  AppConstants.loginRoute,
                  (r) => false,
                );
              }
            },
          ),
        ],
      ),
      body: Container(
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
              left: -size.width * 0.2,
              child: Container(
                width: size.width * 0.7,
                height: size.width * 0.7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.amber.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Header ──────────────────────────────────────────
                        Text(
                          'Complete Profile',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Colors.amber[400],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tell us about yourself and your business',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 15,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        if (_displayEmail != null)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.email_outlined,
                                size: 13,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _displayEmail!,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 40),

                        // ════════════════════════════════════════════════════
                        // ABOUT YOURSELF
                        // ════════════════════════════════════════════════════
                        _sectionHeader('About Yourself'),
                        const SizedBox(height: 16),

                        _buildTextField(
                          label: 'Full Name',
                          hint: 'John Doe',
                          prefixIcon: Icons.person_outline,
                          controller: _nameController,
                          validator: Validators.validateFullName,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 13,
                              color: Colors.amber[600],
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Enter your name as per your verification ID proof.',
                              style: TextStyle(
                                color: Colors.amber[700],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Date of Birth
                        _buildLabel('Date of Birth'),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _pickDate,
                          child: AbsorbPointer(
                            child: _buildTextFieldRaw(
                              controller: _dobController,
                              hint: 'DD/MM/YYYY',
                              icon: Icons.cake_outlined,
                              validator: (v) =>
                                  (v == null || v.isEmpty) ? 'Required' : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Personal phone
                        _buildLabel('Personal Phone Number'),
                        const SizedBox(height: 8),
                        _buildPhoneRow(
                          controller: _phoneController,
                          hint: '9876543210',
                          validator: Validators.validatePhone,
                        ),
                        const SizedBox(height: 40),

                        // ════════════════════════════════════════════════════
                        // ABOUT BUSINESS
                        // ════════════════════════════════════════════════════
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: _sectionHeader('About Business')),
                            // + to add business contact
                            _buildAddContactButton(),
                          ],
                        ),
                        const SizedBox(height: 16),

                        _buildTextField(
                          label: 'Business Name',
                          hint: 'e.g., Royal Events & Co.',
                          prefixIcon: Icons.storefront_outlined,
                          controller: _businessNameController,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // Dynamic business contact fields
                        if (_businessContacts.isNotEmpty) ...[
                          _buildLabel('Business Contact Numbers'),
                          const SizedBox(height: 4),
                          Text(
                            'If none added, your personal number will be used.',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 10),
                          for (int i = 0; i < _businessContacts.length; i++)
                            _buildBusinessContactRow(i),
                          const SizedBox(height: 16),
                        ],

                        _buildTextField(
                          label: 'Address',
                          hint: 'Shop 12, Main Market',
                          prefixIcon: Icons.home_outlined,
                          controller: _addressController,
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),

                        _buildTextField(
                          label: 'City',
                          hint: 'Mumbai',
                          prefixIcon: Icons.location_city_outlined,
                          controller: _cityController,
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                label: 'State',
                                hint: 'Maharashtra',
                                prefixIcon: Icons.map_outlined,
                                controller: _stateController,
                                validator: (v) => (v == null || v.isEmpty)
                                    ? 'Required'
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                label: 'Pincode',
                                hint: '400001',
                                prefixIcon: Icons.pin_drop_outlined,
                                controller: _pincodeController,
                                validator: (v) => (v == null || v.length < 6)
                                    ? 'Invalid'
                                    : null,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 40),

                        // ── Button ──────────────────────────────────────────
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _submitProfile,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Icon(Icons.arrow_forward_rounded),
                          label: const Text(
                            'To Business Details',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _amberColor,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section Header ────────────────────────────────────────────────────────
  Widget _sectionHeader(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _amberColor,
        fontWeight: FontWeight.w700,
        fontSize: 15,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(color: Colors.grey[300], fontWeight: FontWeight.w500),
    );
  }

  // ── Add contact button ───────────────────────────────────────────────────
  Widget _buildAddContactButton() {
    return GestureDetector(
      onTap: _addBusinessContact,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _amberColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _amberColor.withValues(alpha: 0.4)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 16, color: _amberColor),
            SizedBox(width: 4),
            Text(
              'Add Contact',
              style: TextStyle(
                color: _amberColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Business contact row ──────────────────────────────────────────────────
  Widget _buildBusinessContactRow(int index) {
    final contact = _businessContacts[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type toggle (mobile / telephone)
          GestureDetector(
            onTap: () => setState(() {
              contact.isMobile = !contact.isMobile;
            }),
            child: Tooltip(
              message: contact.isMobile ? 'Mobile' : 'Telephone',
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: _fieldBgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _fieldBorderColor),
                ),
                child: Icon(
                  contact.isMobile ? Icons.phone_android : Icons.phone_outlined,
                  color: _amberColor,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Country code picker
          GestureDetector(
            onTap: () {
              showCountryPicker(
                context: context,
                showPhoneCode: true,
                onSelect: (c) =>
                    setState(() => contact.countryCode = c.phoneCode),
                countryListTheme: CountryListThemeData(
                  bottomSheetHeight: 500,
                  backgroundColor: const Color(0xFF121212),
                  textStyle: const TextStyle(color: Colors.white),
                  searchTextStyle: const TextStyle(color: Colors.white),
                  inputDecoration: InputDecoration(
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
              decoration: BoxDecoration(
                color: _fieldBgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _fieldBorderColor),
              ),
              child: Text(
                '+${contact.countryCode}',
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildTextFieldRaw(
              controller: contact.controller,
              hint: contact.isMobile ? '9876543210' : '022-12345678',
              icon: contact.isMobile
                  ? Icons.smartphone_outlined
                  : Icons.call_outlined,
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Enter a number or remove this row';
                }
                final stripped = v.trim().replaceAll(RegExp(r'[\s]'), '');
                if (contact.isMobile) {
                  // Mobile: exactly 10 digits
                  if (!RegExp(r'^\d{10}$').hasMatch(stripped)) {
                    return 'Enter exactly 10 digits';
                  }
                } else {
                  // Telephone: digits + hyphens, 5-15 chars
                  if (!RegExp(r'^[\d\-]{5,15}$').hasMatch(stripped)) {
                    return 'Use digits and hyphens only (e.g. 022-12345678)';
                  }
                }
                return null;
              },
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => _removeBusinessContact(index),
            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
            padding: const EdgeInsets.only(top: 8),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // ── Phone row with country picker ────────────────────────────────────────
  Widget _buildPhoneRow({
    required TextEditingController controller,
    required String hint,
    required String? Function(String?)? validator,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            showCountryPicker(
              context: context,
              showPhoneCode: true,
              onSelect: (c) =>
                  setState(() => _selectedCountryCode = c.phoneCode),
              countryListTheme: CountryListThemeData(
                bottomSheetHeight: 500,
                backgroundColor: const Color(0xFF121212),
                textStyle: const TextStyle(color: Colors.white),
                searchTextStyle: const TextStyle(color: Colors.white),
                inputDecoration: InputDecoration(
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Text(
              '+$_selectedCountryCode',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTextFieldRaw(
            controller: controller,
            hint: hint,
            icon: Icons.phone_outlined,
            validator: validator,
            keyboardType: TextInputType.phone,
          ),
        ),
      ],
    );
  }

  // ── Text field helpers ────────────────────────────────────────────────────
  Widget _buildTextField({
    required String label,
    required String hint,
    required IconData prefixIcon,
    required TextEditingController controller,
    required String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 8),
        _buildTextFieldRaw(
          controller: controller,
          hint: hint,
          icon: prefixIcon,
          validator: validator,
          keyboardType: keyboardType,
        ),
      ],
    );
  }

  Widget _buildTextFieldRaw({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool isReadOnly = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isReadOnly
            ? Colors.white.withValues(alpha: 0.02)
            : _fieldBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _fieldBorderColor),
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        readOnly: isReadOnly,
        style: TextStyle(color: isReadOnly ? Colors.grey : Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[500]),
          border: InputBorder.none,
          prefixIcon: Icon(
            icon,
            color: isReadOnly ? Colors.grey : _amberIconColor,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}

// ── Data class for dynamic business contacts ────────────────────────────────
class _BusinessContact {
  final TextEditingController controller = TextEditingController();
  bool isMobile = true;
  String countryCode = '91';
}
