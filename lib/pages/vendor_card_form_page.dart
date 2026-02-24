import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../models/vendor_card.dart';
import '../services/vendor_card_service.dart';

class VendorCardFormPage extends StatefulWidget {
  final VendorCard? existingCard;

  const VendorCardFormPage({super.key, this.existingCard});

  @override
  State<VendorCardFormPage> createState() => _VendorCardFormPageState();
}

class _VendorCardFormPageState extends State<VendorCardFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _service = VendorCardService();
  final _picker = ImagePicker();

  // Form controllers
  final _studioNameController = TextEditingController();
  final _originalPriceController = TextEditingController();
  final _discountedPriceController = TextEditingController();

  // Form state
  int? _selectedCategoryId;
  String? _selectedCity;
  File? _selectedImage;
  String? _existingImagePath;
  final Set<String> _selectedServiceTags = {};
  final Set<String> _selectedQualityTags = {};
  bool _isSubmitting = false;

  // Available options
  List<String> _availableServiceTags = [];

  @override
  void initState() {
    super.initState();
    if (widget.existingCard != null) {
      _loadExistingCard();
    }
  }

  void _loadExistingCard() {
    final card = widget.existingCard!;
    _studioNameController.text = card.studioName;
    _selectedCategoryId = card.categoryId;
    _selectedCity = card.city;
    _existingImagePath = card.imagePath;
    _selectedServiceTags.addAll(card.serviceTags);
    _selectedQualityTags.addAll(card.qualityTags);
    _originalPriceController.text = card.originalPrice.toStringAsFixed(0);
    _discountedPriceController.text = card.discountedPrice.toStringAsFixed(0);
    _availableServiceTags = VendorCardTags.getServiceTagsForCategory(
      card.categoryId,
    );
  }

  @override
  void dispose() {
    _studioNameController.dispose();
    _originalPriceController.dispose();
    _discountedPriceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    PermissionStatus status;
    if (Platform.isAndroid) {
      if (await Permission.photos.isGranted ||
          await Permission.storage.isGranted) {
        status = PermissionStatus.granted;
      } else {
        status = await Permission.photos.request();
        if (status.isDenied) {
          status = await Permission.storage.request();
        }
      }
    } else {
      status = await Permission.photos.request();
    }

    if (status.isGranted) {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() => _selectedImage = File(image.path));
      }
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please grant photo access in app settings'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo permission is required')),
        );
      }
    }
  }

  void _onCategoryChanged(int? categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
      _selectedServiceTags.clear();
      _availableServiceTags = categoryId != null
          ? VendorCardTags.getServiceTagsForCategory(categoryId)
          : [];
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    // Additional validations
    if (_selectedCategoryId == null) {
      _showError('Please select a category');
      return;
    }
    if (_selectedCity == null) {
      _showError('Please select a city');
      return;
    }
    if (_selectedImage == null && _existingImagePath == null) {
      _showError('Please select an image');
      return;
    }
    if (_selectedServiceTags.isEmpty) {
      _showError('Please select at least one service tag');
      return;
    }
    if (_selectedServiceTags.length > 2) {
      _showError('Maximum 2 service tags allowed');
      return;
    }
    if (_selectedQualityTags.isEmpty) {
      _showError('Please select at least one quality tag');
      return;
    }
    if (_selectedQualityTags.length > 2) {
      _showError('Maximum 2 quality tags allowed');
      return;
    }

    final originalPrice = double.tryParse(_originalPriceController.text) ?? 0;
    final discountedPrice =
        double.tryParse(_discountedPriceController.text) ?? 0;

    if (discountedPrice >= originalPrice) {
      _showError('Discounted price must be less than original price');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String imagePath;

      // Upload new image if selected, otherwise use existing
      if (_selectedImage != null) {
        imagePath = await _service.uploadImage(
          _selectedImage!,
          _selectedCategoryId!,
          _studioNameController.text,
        );

        // Delete old image if updating
        if (widget.existingCard != null && _existingImagePath != null) {
          await _service.deleteImage(_existingImagePath!);
        }
      } else {
        imagePath = _existingImagePath!;
      }

      // Create vendor card object
      final card = VendorCard(
        id: widget.existingCard?.id,
        vendorId: _service.currentVendorId!,
        categoryId: _selectedCategoryId!,
        studioName: _studioNameController.text.trim(),
        city: _selectedCity!,
        imagePath: imagePath,
        serviceTags: _selectedServiceTags.toList(),
        qualityTags: _selectedQualityTags.toList(),
        originalPrice: originalPrice,
        discountedPrice: discountedPrice,
      );

      // Validate
      final validationError = _service.validateCard(card);
      if (validationError != null) {
        _showError(validationError);
        setState(() => _isSubmitting = false);
        return;
      }

      // Submit to database
      if (widget.existingCard == null) {
        await _service.createVendorCard(card);
      } else {
        await _service.updateVendorCard(card);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingCard == null
                  ? 'Vendor card created successfully!'
                  : 'Vendor card updated successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.existingCard == null ? 'Add Vendor Card' : 'Edit Vendor Card',
          style: GoogleFonts.urbanist(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xff0c1c2c),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Category Dropdown
            _buildSectionTitle('Category *'),
            DropdownButtonFormField<int>(
              initialValue: _selectedCategoryId,
              decoration: _inputDecoration('Select category'),
              items: VendorCategory.all.map((cat) {
                return DropdownMenuItem(
                  value: cat.id,
                  child: Text(cat.name, style: GoogleFonts.urbanist()),
                );
              }).toList(),
              onChanged: widget.existingCard == null
                  ? _onCategoryChanged
                  : null,
              validator: (value) =>
                  value == null ? 'Please select a category' : null,
            ),
            const SizedBox(height: 20),

            // Studio Name
            _buildSectionTitle('Studio/Business Name *'),
            TextFormField(
              controller: _studioNameController,
              decoration: _inputDecoration('Enter studio name'),
              style: GoogleFonts.urbanist(),
              validator: (value) => value?.trim().isEmpty ?? true
                  ? 'Studio name is required'
                  : null,
            ),
            const SizedBox(height: 20),

            // City Dropdown
            _buildSectionTitle('City *'),
            DropdownButtonFormField<String>(
              initialValue: _selectedCity,
              decoration: _inputDecoration('Select city'),
              isExpanded: true,
              items: IndianCities.cities.map((city) {
                return DropdownMenuItem(
                  value: city,
                  child: Text(city, style: GoogleFonts.urbanist()),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedCity = value),
              validator: (value) =>
                  value == null ? 'Please select a city' : null,
            ),
            const SizedBox(height: 20),

            // Image Picker
            _buildSectionTitle('Card Image *'),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade50,
                ),
                child: _buildImagePreview(),
              ),
            ),
            const SizedBox(height: 20),

            // Service Tags
            if (_selectedCategoryId != null) ...[
              _buildSectionTitle('Service Tags * (Select up to 2)'),
              _buildTagSection(_availableServiceTags, _selectedServiceTags, 2),
              const SizedBox(height: 20),
            ],

            // Quality Tags
            _buildSectionTitle('Quality Tags * (Select up to 2)'),
            _buildTagSection(
              VendorCardTags.qualityTags,
              _selectedQualityTags,
              2,
            ),
            const SizedBox(height: 20),

            // Prices
            _buildSectionTitle('Original Price (₹) *'),
            TextFormField(
              controller: _originalPriceController,
              decoration: _inputDecoration('Enter original price'),
              style: GoogleFonts.urbanist(),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (value?.trim().isEmpty ?? true) {
                  return 'Original price is required';
                }
                final price = double.tryParse(value!);
                if (price == null || price <= 0) return 'Enter a valid price';
                return null;
              },
            ),
            const SizedBox(height: 15),

            _buildSectionTitle('Discounted Price (₹) *'),
            TextFormField(
              controller: _discountedPriceController,
              decoration: _inputDecoration('Enter discounted price'),
              style: GoogleFonts.urbanist(),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (value?.trim().isEmpty ?? true) {
                  return 'Discounted price is required';
                }
                final price = double.tryParse(value!);
                if (price == null || price <= 0) return 'Enter a valid price';
                return null;
              },
            ),
            const SizedBox(height: 30),

            // Submit Button
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff0c1c2c),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      widget.existingCard == null
                          ? 'Create Card'
                          : 'Update Card',
                      style: GoogleFonts.urbanist(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.urbanist(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.urbanist(color: Colors.grey),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xff0c1c2c), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  Widget _buildImagePreview() {
    if (_selectedImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(_selectedImage!, fit: BoxFit.cover),
            Positioned(
              top: 8,
              right: 8,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                  onPressed: _pickImage,
                ),
              ),
            ),
          ],
        ),
      );
    } else if (_existingImagePath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              _service.getImageUrl(_existingImagePath!),
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const Center(child: CircularProgressIndicator());
              },
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Icon(Icons.error, color: Colors.red, size: 50),
                );
              },
            ),
            Positioned(
              top: 8,
              right: 8,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                  onPressed: _pickImage,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.add_photo_alternate, size: 60, color: Colors.grey),
        const SizedBox(height: 12),
        Text(
          'Tap to select image',
          style: GoogleFonts.urbanist(color: Colors.grey, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildTagSection(
    List<String> availableTags,
    Set<String> selectedTags,
    int maxSelection,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: availableTags.map((tag) {
        final isSelected = selectedTags.contains(tag);
        final canSelect = selectedTags.length < maxSelection || isSelected;

        return FilterChip(
          label: Text(
            tag,
            style: GoogleFonts.urbanist(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          selected: isSelected,
          onSelected: canSelect
              ? (selected) {
                  setState(() {
                    if (selected) {
                      selectedTags.add(tag);
                    } else {
                      selectedTags.remove(tag);
                    }
                  });
                }
              : null,
          backgroundColor: Colors.grey.shade200,
          selectedColor: const Color(0xff0c1c2c),
          checkmarkColor: Colors.white,
          disabledColor: Colors.grey.shade100,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isSelected
                  ? const Color(0xff0c1c2c)
                  : Colors.grey.shade300,
            ),
          ),
        );
      }).toList(),
    );
  }
}
