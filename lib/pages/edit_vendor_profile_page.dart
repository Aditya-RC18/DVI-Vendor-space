import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:country_picker/country_picker.dart';
import '../models/vendor_profile.dart';
import '../utils/validators.dart';
import 'edit_business_details_page.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class EditVendorProfilePage extends StatefulWidget {
  final VendorProfile profile;
  const EditVendorProfilePage({super.key, required this.profile});

  @override
  State<EditVendorProfilePage> createState() => _EditVendorProfilePageState();
}

class _EditVendorProfilePageState extends State<EditVendorProfilePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // ── Editable Controllers ──────────────────────────────────────────────────
  late TextEditingController _nameController;
  late TextEditingController _businessNameController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _pincodeController;
  final List<_EditContact> _businessContacts = [];

  // ── Style constants ───────────────────────────────────────────────────────
  static const _bg = Color(0xFF0E0E0E);
  static const _fieldBg = Color(0x0DFFFFFF);
  static const _fieldBorder = Color(0x1AFFFFFF);
  static const _amber = Color(0xFFFFC107);
  static const _amberIcon = Color(0xB3FFC107);

  // ── Image Selection State ─────────────────────────────────────────────────
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameController = TextEditingController(text: p.fullName);
    _businessNameController = TextEditingController(text: p.businessName ?? '');
    _addressController = TextEditingController(text: p.address);
    _cityController = TextEditingController(text: p.city);
    _stateController = TextEditingController(text: p.state);
    _pincodeController = TextEditingController(text: p.pincode);

    for (final raw in p.businessContacts) {
      final ec = _EditContact();
      if (raw.startsWith('+')) {
        final spaceIdx = raw.indexOf(' ');
        if (spaceIdx != -1) {
          ec.countryCode = raw.substring(1, spaceIdx);
          ec.controller.text = raw.substring(spaceIdx + 1);
        } else {
          ec.controller.text = raw;
        }
      } else {
        ec.controller.text = raw;
      }
      ec.isMobile = !ec.controller.text.contains('-');
      _businessContacts.add(ec);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
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

  // ── Image Logic ───────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<String?> _uploadProfileImage(String vendorId) async {
    if (_selectedImage == null) return null;

    try {
      final fileName = '$vendorId/profile_pic.jpg';
      final storage = Supabase.instance.client.storage.from('vendor_assets');

      await storage.upload(
        fileName,
        _selectedImage!,
        fileOptions: const FileOptions(upsert: true),
      );

      return storage.getPublicUrl(fileName);
    } catch (e) {
      debugPrint("Upload Error: $e");
      return null;
    }
  }

  // ── Submit Logic ──────────────────────────────────────────────────────────
  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;

      // Upload image first if a new one was selected
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await _uploadProfileImage(uid);
      }

      final contacts = _businessContacts
          .where((c) => c.controller.text.trim().isNotEmpty)
          .map((c) => '+${c.countryCode} ${c.controller.text.trim()}')
          .toList();

      final Map<String, dynamic> updateData = {
        'full_name': _nameController.text.trim(),
        'business_name': _businessNameController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'pincode': _pincodeController.text.trim(),
        'business_contacts': contacts,
        'business_submitted': true,
      };

      if (imageUrl != null) {
        updateData['profile_image_url'] = imageUrl;
      }

      if (widget.profile.verificationStatus != 'rejected') {
        updateData['verification_status'] = widget.profile.verificationStatus;
      }

      await Supabase.instance.client
          .from('vendors')
          .update(updateData)
          .eq('id', uid);

      if (mounted) {
        if (widget.profile.verificationStatus == 'rejected') {
          final updatedProfile = widget.profile.copyWith(
            fullName: _nameController.text.trim(),
            businessName: _businessNameController.text.trim(),
            address: _addressController.text.trim(),
            city: _cityController.text.trim(),
            state: _stateController.text.trim(),
            pincode: _pincodeController.text.trim(),
            businessContacts: contacts,
            profileImageUrl: imageUrl ?? widget.profile.profileImageUrl,
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditBusinessDetailsPage(profile: updatedProfile),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Application updated successfully.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
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

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Edit Application',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- PROFILE PHOTO SECTION ---
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.white.withOpacity(0.1),
                          backgroundImage: _selectedImage != null
                              ? FileImage(_selectedImage!)
                              : (widget.profile.profileImageUrl != null
                                        ? NetworkImage(
                                            widget.profile.profileImageUrl!,
                                          )
                                        : null)
                                    as ImageProvider?,
                          child:
                              (_selectedImage == null &&
                                  widget.profile.profileImageUrl == null)
                              ? Icon(
                                  Icons.person_outline,
                                  size: 60,
                                  color: Colors.grey[600],
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            backgroundColor: _amber,
                            radius: 18,
                            child: IconButton(
                              icon: const Icon(
                                Icons.camera_alt,
                                size: 18,
                                color: Colors.black,
                              ),
                              onPressed: _pickImage,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  if (widget.profile.verificationStatus == 'rejected') ...[
                    _buildStepIndicator(),
                    const SizedBox(height: 20),
                  ],

                  // Note banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: _amber, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Email, phone, date of birth and account type cannot '
                            'be changed. Contact support if needed.',
                            style: TextStyle(color: _amber, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── READ-ONLY DISPLAY ─────────────────────────────────────
                  _sectionHeader(Icons.lock_outline, 'Locked Fields'),
                  const SizedBox(height: 16),
                  _readOnlyTile(
                    Icons.email_outlined,
                    'Email',
                    widget.profile.email,
                  ),
                  const SizedBox(height: 10),
                  _readOnlyTile(
                    Icons.phone_outlined,
                    'Personal Phone',
                    widget.profile.phone,
                  ),
                  const SizedBox(height: 10),
                  _readOnlyTile(
                    Icons.cake_outlined,
                    'Date of Birth',
                    widget.profile.dateOfBirth ?? '—',
                  ),
                  const SizedBox(height: 10),
                  _readOnlyTile(
                    Icons.badge_outlined,
                    'Account Type',
                    _roleLabel(widget.profile.role),
                  ),
                  const SizedBox(height: 32),

                  // ── EDITABLE FIELDS ───────────────────────────────────────
                  _sectionHeader(Icons.edit_outlined, 'About Yourself'),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: 'Full Name',
                    hint: 'As per ID proof',
                    icon: Icons.person_outline,
                    controller: _nameController,
                    validator: Validators.validateFullName,
                  ),
                  const SizedBox(height: 32),

                  _sectionHeader(Icons.business_outlined, 'About Business'),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: 'Business Name',
                    hint: 'Registered brand name',
                    icon: Icons.storefront_outlined,
                    controller: _businessNameController,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: 'Address',
                    hint: 'Street / locality',
                    icon: Icons.home_outlined,
                    controller: _addressController,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: 'City',
                    hint: 'City',
                    icon: Icons.location_city_outlined,
                    controller: _cityController,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          label: 'State',
                          hint: 'State',
                          icon: Icons.map_outlined,
                          controller: _stateController,
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Reqd' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          label: 'Pincode',
                          hint: '400001',
                          icon: Icons.pin_outlined,
                          controller: _pincodeController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          validator: (v) => (v == null || v.trim().length < 6)
                              ? 'Invalid'
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Business contacts ─────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _label('Business Contact Numbers'),
                      IconButton(
                        onPressed: () => setState(
                          () => _businessContacts.add(_EditContact()),
                        ),
                        icon: const Icon(Icons.add_circle, color: _amber),
                      ),
                    ],
                  ),
                  for (int i = 0; i < _businessContacts.length; i++) ...[
                    const SizedBox(height: 10),
                    _buildContactRow(_businessContacts[i], i),
                  ],
                  const SizedBox(height: 48),

                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _updateProfile,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Icon(
                            widget.profile.verificationStatus == 'rejected'
                                ? Icons.arrow_forward_outlined
                                : Icons.save_outlined,
                          ),
                    label: Text(
                      widget.profile.verificationStatus == 'rejected'
                          ? 'Save & Continue →'
                          : 'Save Changes',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _amber,
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
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: _amber),
              ),
            ),
        ],
      ),
    );
  }

  // ── Helper Widgets ────────────────────────────────────────────────────────
  Widget _buildStepIndicator() {
    return Row(
      children: [
        _stepChip('1', 'Profile Info', active: true),
        const Expanded(child: Divider(color: Colors.grey, thickness: 1)),
        _stepChip('2', 'Business Details'),
      ],
    );
  }

  Widget _stepChip(
    String number,
    String label, {
    bool active = false,
    bool done = false,
  }) {
    final color = done || active ? _amber : Colors.grey;
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: done
                ? _amber
                : (active
                      ? Colors.amber.withOpacity(0.15)
                      : Colors.transparent),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check, size: 13, color: Colors.black)
                : Text(
                    number,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }

  Widget _sectionHeader(IconData icon, String text) => Row(
    children: [
      Icon(icon, color: _amber, size: 16),
      const SizedBox(width: 8),
      Text(
        text,
        style: const TextStyle(
          color: _amber,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    ],
  );

  Widget _readOnlyTile(IconData icon, String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.03),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withOpacity(0.08)),
    ),
    child: Row(
      children: [
        Icon(icon, color: Colors.grey[600], size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
              ),
              Text(
                value,
                style: const TextStyle(color: Colors.white54, fontSize: 15),
              ),
            ],
          ),
        ),
        const Icon(Icons.lock_outline, color: Colors.grey, size: 14),
      ],
    ),
  );

  Widget _label(String text) =>
      Text(text, style: TextStyle(color: Colors.grey[300]));

  Widget _buildTextField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    required String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _fieldBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _fieldBorder),
          ),
          child: TextFormField(
            controller: controller,
            validator: validator,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[500]),
              border: InputBorder.none,
              prefixIcon: Icon(icon, color: _amberIcon),
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

  Widget _buildContactRow(_EditContact contact, int index) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => setState(() => contact.isMobile = !contact.isMobile),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _fieldBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _fieldBorder),
            ),
            child: Icon(
              contact.isMobile ? Icons.phone_android : Icons.phone_outlined,
              color: _amber,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => showCountryPicker(
            context: context,
            onSelect: (c) => setState(() => contact.countryCode = c.phoneCode),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _fieldBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _fieldBorder),
            ),
            child: Text(
              '+${contact.countryCode}',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: _fieldBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _fieldBorder),
            ),
            child: TextFormField(
              controller: contact.controller,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: contact.isMobile ? '9876543210' : 'Number',
                hintStyle: TextStyle(color: Colors.grey[500]),
                border: InputBorder.none,
                prefixIcon: Icon(
                  contact.isMobile
                      ? Icons.smartphone_outlined
                      : Icons.call_outlined,
                  color: _amberIcon,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
          ),
        ),
        IconButton(
          onPressed: () => setState(() => _businessContacts.removeAt(index)),
          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
        ),
      ],
    );
  }
}

String _roleLabel(String role) {
  switch (role) {
    case 'venue_distributor':
      return 'Venue Distributor';
    case 'vendor_distributor':
      return 'Vendor Services';
    case 'venue_vendor_distributor':
      return 'Both (Venue & Services)';
    case 'admin':
      return 'Admin Account';
    default:
      return role;
  }
}

class _EditContact {
  final TextEditingController controller = TextEditingController();
  bool isMobile = true;
  String countryCode = '91';
}
