import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/business_details_page.dart' show UpperCaseTextFormatter;
import '../models/vendor_profile.dart';

/// Page 2 of the rejected-vendor edit flow.
/// Lets the vendor update banking info and re-upload documents.
/// On submit sets verification_status back to 'pending'.
class EditBusinessDetailsPage extends StatefulWidget {
  final VendorProfile profile;
  const EditBusinessDetailsPage({super.key, required this.profile});

  @override
  State<EditBusinessDetailsPage> createState() =>
      _EditBusinessDetailsPageState();
}

class _EditBusinessDetailsPageState extends State<EditBusinessDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscureAccount = true;

  late TextEditingController _accountHolderController;
  late TextEditingController _accountNumberController;
  late TextEditingController _ifscController;
  late TextEditingController _idNumberController;

  // New files (null = keep existing)
  File? _bankProof;
  File? _idProof;
  File? _businessProof;

  static const _maxBytes = 1024 * 1024;
  static const _bg = Color(0xFF0E0E0E);
  static const _fieldBg = Color(0x0DFFFFFF);
  static const _fieldBorder = Color(0x1AFFFFFF);
  static const _amber = Color(0xFFFFC107);
  static const _amberIcon = Color(0xB3FFC107);

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _accountHolderController = TextEditingController(
      text: p.accountHolderName ?? '',
    );
    _accountNumberController = TextEditingController(
      text: p.accountNumber ?? '',
    );
    _ifscController = TextEditingController(text: p.ifscCode ?? '');
    _idNumberController = TextEditingController(text: p.idNumber ?? '');
  }

  @override
  void dispose() {
    _accountHolderController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    _idNumberController.dispose();
    super.dispose();
  }

  // ── Image picker with auto-compress ──────────────────────────────────────
  Future<File?> _pick(String label) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return null;

    File file = File(picked.path);
    if (await file.length() <= _maxBytes) return file;

    const qualities = [80, 60, 40, 20];
    for (final q in qualities) {
      final tmpPath =
          '${file.parent.path}/${DateTime.now().millisecondsSinceEpoch}_c.jpg';
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        tmpPath,
        quality: q,
        format: CompressFormat.jpeg,
      );
      if (result == null) break;
      final compressed = File(result.path);
      if (await compressed.length() <= _maxBytes) return compressed;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$label is too large even after compression. '
            'Please crop or choose a smaller image.',
          ),
          backgroundColor: Colors.red[700],
        ),
      );
    }
    return null;
  }

  // ── Upload helper ─────────────────────────────────────────────────────────
  Future<String?> _upload(File file, String uid, String name) async {
    final path = '$uid/${name}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await Supabase.instance.client.storage
        .from('vendor_docs')
        .upload(path, file);
    return path;
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;

      // Upload only newly selected docs; fall back to existing URLs
      final bankUrl = _bankProof != null
          ? await _upload(_bankProof!, uid, 'bank_proof')
          : widget.profile.bankProofUrl;
      final idUrl = _idProof != null
          ? await _upload(_idProof!, uid, 'id_proof')
          : widget.profile.identificationUrl;
      final bizUrl = _businessProof != null
          ? await _upload(_businessProof!, uid, 'business_proof')
          : widget.profile.businessProofUrl;

      await Supabase.instance.client
          .from('vendors')
          .update({
            'account_holder_name': _accountHolderController.text.trim(),
            'account_number': _accountNumberController.text.trim(),
            'ifsc_code': _ifscController.text.trim().toUpperCase(),
            'id_number': _idNumberController.text.trim(),
            if (bankUrl != null) 'bank_proof_url': bankUrl,
            if (idUrl != null) 'identification_url': idUrl,
            if (bizUrl != null) 'business_proof_url': bizUrl,
            'verification_status': 'pending',
            'business_submitted': true,
          })
          .eq('id', uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application re-submitted for review.'),
            backgroundColor: Colors.green,
          ),
        );
        // Pop twice (back through EditVendorProfilePage) and signal refresh
        Navigator.of(context)
          ..pop(true) // close EditBusinessDetailsPage
          ..pop(
            true,
          ); // close EditVendorProfilePage → back to VerificationStatusPage
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
          'Business Details',
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
                  // Step indicator
                  Row(
                    children: [
                      _stepChip('1', 'Profile Info', done: true),
                      const Expanded(
                        child: Divider(color: Colors.amber, thickness: 1),
                      ),
                      _stepChip('2', 'Business Details', active: true),
                    ],
                  ),
                  const SizedBox(height: 32),

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
                  _label('Account Number'),
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
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
                      LengthLimitingTextInputFormatter(11),
                    ],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (!RegExp(
                        r'^[A-Z]{4}0[A-Z0-9]{6}$',
                      ).hasMatch(v.trim())) {
                        return 'Invalid IFSC (e.g. HDFC0001234)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 40),

                  _sectionHeader(
                    Icons.upload_file_outlined,
                    'Document Uploads',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Re-upload only the documents that caused rejection. '
                    'Unchanged documents will be kept automatically.',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  const SizedBox(height: 20),

                  // ID number
                  _buildTextField(
                    label: 'ID Number',
                    hint: 'Aadhaar / PAN / Passport number',
                    icon: Icons.badge_outlined,
                    controller: _idNumberController,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 20),

                  _buildDocPicker(
                    label: 'Bank Verification Proof',
                    subtitle: 'Passbook front page or cancelled cheque',
                    icon: Icons.account_balance_outlined,
                    file: _bankProof,
                    existingUrl: widget.profile.bankProofUrl,
                    onPick: () async {
                      final f = await _pick('Bank proof');
                      if (f != null) setState(() => _bankProof = f);
                    },
                    onClear: () => setState(() => _bankProof = null),
                  ),
                  const SizedBox(height: 20),

                  _buildDocPicker(
                    label: 'ID Proof',
                    subtitle: 'Aadhaar / PAN / Passport scan',
                    icon: Icons.perm_identity_outlined,
                    file: _idProof,
                    existingUrl: widget.profile.identificationUrl,
                    onPick: () async {
                      final f = await _pick('ID proof');
                      if (f != null) setState(() => _idProof = f);
                    },
                    onClear: () => setState(() => _idProof = null),
                  ),
                  const SizedBox(height: 20),

                  _buildDocPicker(
                    label: 'Business Proof',
                    subtitle: 'GST certificate, trade licence, etc.',
                    icon: Icons.business_outlined,
                    file: _businessProof,
                    existingUrl: widget.profile.businessProofUrl,
                    onPick: () async {
                      final f = await _pick('Business proof');
                      if (f != null) setState(() => _businessProof = f);
                    },
                    onClear: () => setState(() => _businessProof = null),
                  ),

                  const SizedBox(height: 48),

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
                        : const Icon(Icons.send_outlined),
                    label: const Text(
                      'Re-submit for Review',
                      style: TextStyle(
                        fontSize: 16,
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

  // ── Small widgets ─────────────────────────────────────────────────────────

  Widget _stepChip(
    String number,
    String text, {
    bool done = false,
    bool active = false,
  }) {
    final color = done || active ? _amber : Colors.grey;
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: done
                ? _amber
                : (active
                      ? Colors.amber.withValues(alpha: 0.15)
                      : Colors.transparent),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check, size: 14, color: Colors.black)
                : Text(
                    number,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
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
          letterSpacing: 0.5,
        ),
      ),
    ],
  );

  Widget _label(String text) => Text(
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

  Widget _buildDocPicker({
    required String label,
    required String subtitle,
    required IconData icon,
    required File? file,
    required String? existingUrl,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    final hasExisting = existingUrl != null && existingUrl.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: file == null ? onPick : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 110,
            width: double.infinity,
            decoration: BoxDecoration(
              color: file != null
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.04),
              border: Border.all(
                color: file != null
                    ? Colors.green.withValues(alpha: 0.5)
                    : (hasExisting
                          ? Colors.amber.withValues(alpha: 0.35)
                          : Colors.white.withValues(alpha: 0.12)),
                width: 1.5,
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
                        top: 6,
                        right: 6,
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
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: GestureDetector(
                          onTap: onPick,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
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
                                  size: 12,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Replace',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
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
                        hasExisting ? Icons.check_circle_outline : icon,
                        size: 28,
                        color: hasExisting
                            ? Colors.amber.withValues(alpha: 0.8)
                            : Colors.amber.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        hasExisting
                            ? 'Existing doc on file — tap to replace'
                            : 'Tap to upload',
                        style: TextStyle(
                          color: hasExisting
                              ? Colors.amber[300]
                              : Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                      if (!hasExisting)
                        Text(
                          'Max 1 MB',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
