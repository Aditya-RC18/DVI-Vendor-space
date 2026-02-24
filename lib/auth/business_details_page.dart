import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vendor_profile.dart';
import '../pages/verification_status_page.dart';
import '../utils/constants.dart';
import 'complete_profile_page.dart';

/// Page 3 of signup: banking info + document uploads.
/// On submit, sets business_submitted = true and routes to VerificationStatusPage.
class BusinessDetailsPage extends StatefulWidget {
  const BusinessDetailsPage({super.key});

  @override
  State<BusinessDetailsPage> createState() => _BusinessDetailsPageState();
}

class _BusinessDetailsPageState extends State<BusinessDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscureAccount = true;

  // ── Banking fields ──────────────────────────────────────────────────────
  final _accountHolderController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _ifscController = TextEditingController();

  // ── ID details ───────────────────────────────────────────────────────────
  final _idNumberController = TextEditingController();

  // ── Document images ──────────────────────────────────────────────────────
  File? _bankProof;
  File? _idProof;
  File? _businessProof;

  static const _maxBytes = 1024 * 1024; // 1 MB
  static const _fieldBg = Color(0x0DFFFFFF);
  static const _fieldBorder = Color(0x1AFFFFFF);
  static const _amber = Color(0xFFFFC107);
  static const _amberIcon = Color(0xB3FFC107);

  @override
  void dispose() {
    _accountHolderController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    _idNumberController.dispose();
    super.dispose();
  }

  // ── Image picker with auto-compress ─────────────────────────────────────
  Future<File?> _pick(String label) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return null;

    File file = File(picked.path);
    int size = await file.length();

    // Already within limit — use as-is
    if (size <= _maxBytes) return file;

    // Try to compress iteratively: 80 → 60 → 40 → 20 %
    final tmpDir = file.parent.path;
    const qualities = [80, 60, 40, 20];
    for (final q in qualities) {
      final tmpPath =
          '$tmpDir/${DateTime.now().millisecondsSinceEpoch}_compressed.jpg';
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        tmpPath,
        quality: q,
        format: CompressFormat.jpeg,
      );
      if (result == null) break;
      final compressed = File(result.path);
      if (await compressed.length() <= _maxBytes) {
        return compressed; // ✅ fits
      }
    }

    // Still too large after all compression attempts
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$label is too large even after compression. '
            'Please crop the image or choose a smaller file.',
          ),
          backgroundColor: Colors.red[700],
        ),
      );
    }
    return null;
  }

  // ── Upload helper ────────────────────────────────────────────────────────
  Future<String?> _upload(File file, String userId, String name) async {
    final path = '$userId/${name}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await Supabase.instance.client.storage
        .from('vendor_docs')
        .upload(path, file);
    return path;
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_bankProof == null || _idProof == null || _businessProof == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload all three documents.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw 'User not authenticated';
      final uid = user.id;

      // Upload all three docs in parallel
      final results = await Future.wait([
        _upload(_bankProof!, uid, 'bank_proof'),
        _upload(_idProof!, uid, 'id_proof'),
        _upload(_businessProof!, uid, 'business_proof'),
      ]);

      await Supabase.instance.client
          .from('vendors')
          .update({
            'account_holder_name': _accountHolderController.text.trim(),
            'account_number': _accountNumberController.text.trim(),
            'ifsc_code': _ifscController.text.trim().toUpperCase(),
            'id_number': _idNumberController.text.trim(),
            'bank_proof_url': results[0],
            'identification_url': results[1],
            'business_proof_url': results[2],
            'business_submitted': true,
          })
          .eq('id', uid);

      // Re-fetch the updated profile to pass to VerificationStatusPage
      final raw = await Supabase.instance.client
          .from('vendors')
          .select()
          .eq('id', uid)
          .single();
      final updatedProfile = VendorProfile.fromJson(raw);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Details submitted! Your profile is under review.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => VerificationStatusPage(profile: updatedProfile),
          ),
          (r) => false,
        );
      }
    } catch (e) {
      debugPrint('BusinessDetails Submit Error: $e');
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
        // Back to page 2 — works whether arrived via push (new accounts)
        // or via AuthWrapper direct placement (pre-existing accounts).
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          tooltip: 'Back to Profile',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const CompleteVendorProfilePage(),
                ),
              );
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
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
              right: -size.width * 0.2,
              child: Container(
                width: size.width * 0.7,
                height: size.width * 0.7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.amber.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Header ─────────────────────────────────────────
                      Text(
                        'Business Details',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.amber[400],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Banking & verification documents',
                        style: TextStyle(color: Colors.grey[400], fontSize: 15),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),

                      // ════════════════════════════════════════════════════
                      // BANKING INFORMATION
                      // ════════════════════════════════════════════════════
                      _sectionHeader(
                        Icons.account_balance_outlined,
                        'Banking Information',
                      ),
                      const SizedBox(height: 16),

                      _buildTextField(
                        label: 'Account Holder Name',
                        hint: 'As on bank passbook',
                        icon: Icons.person_outline,
                        controller: _accountHolderController,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Account number with obscure toggle
                      _buildLabel('Account Number'),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: _fieldBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _fieldBorder),
                        ),
                        child: TextFormField(
                          controller: _accountNumberController,
                          obscureText: _obscureAccount,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          validator: (v) => (v == null || v.trim().length < 8)
                              ? 'Enter a valid account number'
                              : null,
                          decoration: InputDecoration(
                            hintText: 'XXXXXXXXXXXX',
                            hintStyle: TextStyle(color: Colors.grey[500]),
                            border: InputBorder.none,
                            prefixIcon: const Icon(
                              Icons.credit_card_outlined,
                              color: _amberIcon,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureAccount
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: Colors.grey,
                                size: 20,
                              ),
                              onPressed: () => setState(
                                () => _obscureAccount = !_obscureAccount,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildTextField(
                        label: 'IFSC Code',
                        hint: 'e.g. HDFC0001234',
                        icon: Icons.code_outlined,
                        controller: _ifscController,
                        inputFormatters: [
                          UpperCaseTextFormatter(),
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[A-Z0-9]'),
                          ),
                          LengthLimitingTextInputFormatter(11),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (!RegExp(
                            r'^[A-Z]{4}0[A-Z0-9]{6}$',
                          ).hasMatch(v.trim())) {
                            return 'Invalid IFSC format (e.g. HDFC0001234)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 40),

                      // ════════════════════════════════════════════════════
                      // DOCUMENT UPLOADS
                      // ════════════════════════════════════════════════════
                      _sectionHeader(
                        Icons.upload_file_outlined,
                        'Document Uploads',
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'All files must be under 1 MB.',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      const SizedBox(height: 20),

                      // Bank Proof
                      _buildDocPicker(
                        label: 'Bank Verification Proof',
                        subtitle: 'Passbook front page or cancelled cheque',
                        icon: Icons.account_balance_outlined,
                        file: _bankProof,
                        onPick: () async {
                          final f = await _pick('Bank proof');
                          if (f != null) setState(() => _bankProof = f);
                        },
                        onClear: () => setState(() => _bankProof = null),
                      ),
                      const SizedBox(height: 20),

                      // ID Proof: number + image
                      _buildLabel('ID Proof'),
                      const SizedBox(height: 8),
                      _buildTextFieldRaw(
                        controller: _idNumberController,
                        hint: 'Aadhaar / PAN / Passport number',
                        icon: Icons.badge_outlined,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter your ID number'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      // Warning
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: _amber,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Ensure the document is clearly visible '
                                'and all details are legible. Blurry or '
                                'cropped images will be rejected.',
                                style: TextStyle(
                                  color: Colors.amber[300],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildDocPicker(
                        label: 'Upload ID Proof Image',
                        subtitle: 'Aadhaar / PAN / Passport scan',
                        icon: Icons.perm_identity_outlined,
                        file: _idProof,
                        onPick: () async {
                          final f = await _pick('ID proof');
                          if (f != null) setState(() => _idProof = f);
                        },
                        onClear: () => setState(() => _idProof = null),
                      ),
                      const SizedBox(height: 20),

                      // Business Proof
                      _buildDocPicker(
                        label: 'Business Proof',
                        subtitle: 'GST certificate, trade licence, etc.',
                        icon: Icons.business_outlined,
                        file: _businessProof,
                        onPick: () async {
                          final f = await _pick('Business proof');
                          if (f != null) setState(() => _businessProof = f);
                        },
                        onClear: () => setState(() => _businessProof = null),
                      ),

                      const SizedBox(height: 48),

                      // ── Submit ─────────────────────────────────────────
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _submit,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: const Text(
                          'Submit for Review',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
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
                      const SizedBox(height: 8),
                      Text(
                        'Your profile will be reviewed within 2–3 business days.',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _sectionHeader(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: _amber, size: 18),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: _amber,
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) => Text(
    text,
    style: TextStyle(color: Colors.grey[300], fontWeight: FontWeight.w500),
  );

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
        _buildLabel(label),
        const SizedBox(height: 8),
        _buildTextFieldRaw(
          controller: controller,
          hint: hint,
          icon: icon,
          validator: validator,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
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
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
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
    );
  }

  Widget _buildDocPicker({
    required String label,
    required String subtitle,
    required IconData icon,
    required File? file,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 6),
        Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: file == null ? onPick : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 130,
            width: double.infinity,
            decoration: BoxDecoration(
              color: file != null
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.04),
              border: Border.all(
                color: file != null
                    ? Colors.green.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.12),
                width: file != null ? 1.5 : 1,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: file != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(file, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: onClear,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: onPick,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.refresh,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Replace',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 32,
                        color: Colors.amber.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to upload',
                        style: TextStyle(color: Colors.grey[400], fontSize: 13),
                      ),
                      Text(
                        'Max 1 MB',
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

// ── Formatter helpers ─────────────────────────────────────────────────────────
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
