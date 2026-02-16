import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:country_picker/country_picker.dart';
import '../utils/constants.dart';
import '../utils/validators.dart';

class CompleteVendorProfilePage extends StatefulWidget {
  const CompleteVendorProfilePage({super.key});

  @override
  State<CompleteVendorProfilePage> createState() =>
      _CompleteVendorProfilePageState();
}

class _CompleteVendorProfilePageState extends State<CompleteVendorProfilePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();

  String _selectedCountryCode = '91';
  File? _idDocument;
  String _userRole = 'venue_distributor'; // Default role

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  void _fetchUserData() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      // Autofill email
      _emailController.text = user.email ?? '';

      // Autofill name from metadata
      final metaName = user.userMetadata?['full_name'];
      if (metaName != null) {
        _nameController.text = metaName.toString();
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _idDocument = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw "User not authenticated";

      String? docPath;
      if (_idDocument != null) {
        // Upload to a folder named with the user's ID to satisfy RLS: (storage.foldername(name))[1]
        final fileName =
            '${user.id}/id_proof_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await Supabase.instance.client.storage
            .from('vendor_docs')
            .upload(fileName, _idDocument!);
        docPath = fileName;
      }

      final data = {
        'id': user.id,
        'email': user.email,
        'full_name': _nameController.text.trim(), // Use edited name
        'phone': '+$_selectedCountryCode ${_phoneController.text}',
        'address': _addressController.text,
        'city': _cityController.text,
        'state': _stateController.text,
        'pincode': _pincodeController.text,
        'role': _userRole, // Save role from signup
        'verification_status': 'pending',
      };

      if (docPath != null) {
        data['identification_url'] = docPath;
      }

      await Supabase.instance.client.from('vendors').insert(data);

      // Explicitly verify the row exists now
      final check = await Supabase.instance.client
          .from('vendors')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (check == null) {
        throw "Profile creation verification failed. Please try again.";
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Profile Completed!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      debugPrint("Profile Submit Error: $e");
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              // Force replacement to avoid "setState after dispose" if AuthWrapper triggers
              if (context.mounted)
                Navigator.of(context).pushNamedAndRemoveUntil(
                  AppConstants.loginRoute,
                  (r) => false,
                );
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
            // Background Elements
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
                      Colors.amber.withOpacity(0.15),
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
                        Text(
                          "Complete Profile",
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Colors.amber[400],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Tell us more about your business",
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 48),

                        // Personal Details Section
                        Text(
                          "Personal Details",
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        _buildTextField(
                          label: "Full Name",
                          hint: "John Doe",
                          prefixIcon: Icons.person_outline,
                          controller: _nameController,
                          validator: Validators.validateFullName,
                        ),
                        const SizedBox(height: 16),

                        // Read-only Email
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Email Address",
                              style: TextStyle(
                                color: Colors.grey[300],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildTextFieldRaw(
                              controller: _emailController,
                              hint: "email@example.com",
                              icon: Icons.email_outlined,
                              validator: null,
                              isReadOnly: true,
                            ),
                            const Padding(
                              padding: EdgeInsets.only(top: 4, left: 4),
                              child: Text(
                                "Email cannot be changed.",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Phone with Country Code
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Phone Number",
                              style: TextStyle(
                                color: Colors.grey[300],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    showCountryPicker(
                                      context: context,
                                      showPhoneCode: true,
                                      onSelect: (c) => setState(
                                        () =>
                                            _selectedCountryCode = c.phoneCode,
                                      ),
                                      countryListTheme: CountryListThemeData(
                                        bottomSheetHeight: 500,
                                        backgroundColor: const Color(
                                          0xFF121212,
                                        ),
                                        textStyle: const TextStyle(
                                          color: Colors.white,
                                        ),
                                        searchTextStyle: const TextStyle(
                                          color: Colors.white,
                                        ),
                                        inputDecoration: InputDecoration(
                                          hintStyle: TextStyle(
                                            color: Colors.grey[500],
                                          ),
                                          prefixIcon: const Icon(
                                            Icons.search,
                                            color: Colors.grey,
                                          ),
                                          filled: true,
                                          fillColor: Colors.white.withOpacity(
                                            0.1,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide.none,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.1),
                                      ),
                                    ),
                                    child: Text(
                                      "+$_selectedCountryCode",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildTextFieldRaw(
                                    controller: _phoneController,
                                    hint: "9876543210",
                                    icon: Icons.phone_outlined,
                                    validator: Validators.validatePhone,
                                    keyboardType: TextInputType.phone,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // Account Type Selection
                        Text(
                          "Account Type",
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildRoleDropdown(),
                        const SizedBox(height: 32),

                        // Address Section
                        Text(
                          "Business Address",
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        _buildTextField(
                          label: "Address",
                          hint: "Shop 12, Main Market",
                          prefixIcon: Icons.home_outlined,
                          controller: _addressController,
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          label: "City",
                          hint: "Mumbai",
                          prefixIcon: Icons.location_city_outlined,
                          controller: _cityController,
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                label: "State",
                                hint: "Maharashtra",
                                prefixIcon: Icons.map_outlined,
                                controller: _stateController,
                                validator: (v) =>
                                    v!.isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                label: "Pincode",
                                hint: "400001",
                                prefixIcon: Icons.pin_drop_outlined,
                                controller: _pincodeController,
                                validator: (v) =>
                                    v!.length < 6 ? 'Invalid' : null,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),
                        Text(
                          "Identification Document",
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _pickImage,
                          child: Container(
                            height: 150,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: _idDocument != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(
                                      _idDocument!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.cloud_upload_outlined,
                                        size: 40,
                                        color: Colors.amber.withOpacity(0.7),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "Tap to Upload ID",
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        if (_idDocument != null)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () =>
                                  setState(() => _idDocument = null),
                              child: Text(
                                "Clear",
                                style: TextStyle(color: Colors.red[300]),
                              ),
                            ),
                          ),

                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _submitProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator()
                              : const Text(
                                  "Complete Registration",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
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
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[300],
            fontWeight: FontWeight.w500,
          ),
        ),
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
            ? Colors.white.withOpacity(0.02)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
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
            color: isReadOnly ? Colors.grey : Colors.amber.withOpacity(0.7),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  // Account Type Dropdown
  Widget _buildRoleDropdown() {
    const amberColor = Color(0xFFFFC107);
    const amberIconColor = Color(0xB3FFC107);
    const fieldBgColor = Color(0x0DFFFFFF);
    const fieldBorderColor = Color(0x1AFFFFFF);

    return Container(
      decoration: BoxDecoration(
        color: fieldBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fieldBorderColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonFormField<String>(
        value: _userRole,
        dropdownColor: const Color(0xFF1A1A1A),
        icon: const Icon(Icons.arrow_drop_down, color: amberColor),
        decoration: const InputDecoration(
          border: InputBorder.none,
          prefixIcon: Icon(Icons.badge, color: amberIconColor),
        ),
        style: const TextStyle(color: Colors.white, fontSize: 15),
        items: [
          DropdownMenuItem(
            value: 'venue_distributor',
            child: _buildDropdownItem(
              icon: Icons.business,
              title: 'Venue Distributor',
              subtitle: 'Manage wedding venues',
            ),
          ),
          DropdownMenuItem(
            value: 'vendor_distributor',
            child: _buildDropdownItem(
              icon: Icons.store,
              title: 'Vendor Services',
              subtitle: 'Catering, photography, etc.',
            ),
          ),
          DropdownMenuItem(
            value: 'venue_vendor_distributor',
            child: _buildDropdownItem(
              icon: Icons.business_center,
              title: 'Both (Venue & Services)',
              subtitle: 'Combined access',
            ),
          ),
          DropdownMenuItem(
            value: 'admin',
            child: _buildDropdownItem(
              icon: Icons.admin_panel_settings,
              title: 'Admin Account',
              subtitle: 'Requires approval',
              isSpecial: true,
            ),
          ),
        ],
        onChanged: (value) {
          if (value != null) {
            setState(() => _userRole = value);
          }
        },
      ),
    );
  }

  Widget _buildDropdownItem({
    required IconData icon,
    required String title,
    required String subtitle,
    bool isSpecial = false,
  }) {
    const amberColor = Color(0xFFFFC107);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: amberColor, size: 20),
        const SizedBox(width: 8),
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
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSpecial) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
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
                subtitle,
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
}
