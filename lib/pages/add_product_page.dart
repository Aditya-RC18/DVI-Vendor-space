import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class AddProductPage extends StatefulWidget {
  final Map<String, dynamic>? existingProduct;
  const AddProductPage({super.key, this.existingProduct});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;

  // Restored all form controllers
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _discountController = TextEditingController();
  final _qtyController = TextEditingController();
  final _dimsController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedImages = []; // Newly selected images
  List<String> _existingImageUrls = []; // Existing images from database
  String? _selectedCategory;
  List<Map<String, dynamic>> _supabaseCategories = [];

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    if (widget.existingProduct != null) {
      final p = widget.existingProduct!;
      _nameController.text = p['name'] ?? '';
      _descController.text = p['description'] ?? '';
      _selectedCategory = p['category'];
      _priceController.text = p['price']?.toString() ?? '';
      _discountController.text = p['discount_price']?.toString() ?? '';
      _qtyController.text = p['quantity']?.toString() ?? '';
      _dimsController.text = p['dimensions'] ?? '';

      // Load existing images
      final imageUrlData = p['image_url'];
      if (imageUrlData != null && imageUrlData.isNotEmpty) {
        try {
          if (imageUrlData is String) {
            // Parse JSON string
            final List<dynamic> parsed = jsonDecode(imageUrlData);
            _existingImageUrls = parsed.map((url) => url.toString()).toList();
          } else if (imageUrlData is List) {
            _existingImageUrls = imageUrlData
                .map((url) => url.toString())
                .toList();
          }
        } catch (e) {
          debugPrint('Error parsing image URL: $e');
          _existingImageUrls = [];
        }
      }
    }
  }

  Future<void> _fetchCategories() async {
    final data = await _supabase
        .from('vendor_categories')
        .select('name')
        .eq('is_active', true);
    setState(() => _supabaseCategories = List<Map<String, dynamic>>.from(data));
  }

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) setState(() => _selectedImages.addAll(images));
  }

  Future<List<String>> _uploadImages(String productId) async {
    List<String> imageUrls = [];
    debugPrint('Starting image upload for product: $productId');
    debugPrint('Number of images to upload: ${_selectedImages.length}');

    for (int i = 0; i < _selectedImages.length; i++) {
      final image = _selectedImages[i];
      final Uint8List bytes = await image.readAsBytes();
      final fileExt = image.name.split('.').last;
      final filePath =
          'product_images/$productId/img_${DateTime.now().millisecondsSinceEpoch}_$i.$fileExt';

      try {
        debugPrint('Uploading image $i to: $filePath');
        await _supabase.storage
            .from('vendor_assets')
            .uploadBinary(
              filePath,
              bytes,
              fileOptions: FileOptions(
                contentType: 'image/$fileExt',
                upsert: true,
              ),
            );
        debugPrint('Image $i uploaded successfully');

        final publicUrl = _supabase.storage
            .from('vendor_assets')
            .getPublicUrl(filePath);
        debugPrint('Image $i public URL: $publicUrl');
        imageUrls.add(publicUrl);
      } catch (e) {
        debugPrint('Error uploading image $i: $e');
        // Continue with other images even if one fails
        continue;
      }
    }
    debugPrint('Total uploaded images: ${imageUrls.length}');
    debugPrint('Image URLs: $imageUrls');
    return imageUrls;
  }

  Future<void> _submitProduct() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final userId = _supabase.auth.currentUser!.id;
      final productData = {
        'vendor_id': userId,
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'category': _selectedCategory,
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'discount_price': double.tryParse(_discountController.text),
        'quantity': int.tryParse(_qtyController.text) ?? 0,
        'dimensions': _dimsController.text.trim(),
      };

      String productId;
      if (widget.existingProduct != null) {
        productId = widget.existingProduct!['id'].toString();
        await _supabase
            .from('products')
            .update(productData)
            .eq('id', productId);
      } else {
        final res = await _supabase
            .from('products')
            .insert(productData)
            .select()
            .single();
        productId = res['id'].toString();
      }

      debugPrint('Selected images count: ${_selectedImages.length}');
      debugPrint('Existing images count: ${_existingImageUrls.length}');

      if (_selectedImages.isNotEmpty) {
        debugPrint('Uploading new images...');
        final newUrls = await _uploadImages(productId);
        debugPrint('New URLs received: $newUrls');
        final allUrls = [..._existingImageUrls, ...newUrls];
        debugPrint('All URLs combined: $allUrls');
        final imageUrlJson = jsonEncode(allUrls);
        debugPrint('JSON to save: $imageUrlJson');
        await _supabase
            .from('products')
            .update({'image_url': imageUrlJson})
            .eq('id', productId);
        debugPrint('Images saved to database');
      } else if (_existingImageUrls.isNotEmpty) {
        // Update with existing images only (in case some were removed)
        debugPrint('Saving existing images only...');
        final imageUrlJson = jsonEncode(_existingImageUrls);
        await _supabase
            .from('products')
            .update({'image_url': imageUrlJson})
            .eq('id', productId);
        debugPrint('Existing images saved to database');
      } else {
        debugPrint('No images to save');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product saved successfully!')),
        );
        // Clear form and images
        _nameController.clear();
        _descController.clear();
        _priceController.clear();
        _discountController.clear();
        _qtyController.clear();
        _dimsController.clear();
        setState(() {
          _selectedImages.clear();
          _existingImageUrls.clear();
          _selectedCategory = null;
        });
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Error saving product';
        if (e.toString().contains('Bucket not found')) {
          errorMessage =
              'Storage bucket not found. Please check your Supabase storage configuration.';
        } else if (e.toString().contains('permission')) {
          errorMessage =
              'Permission denied. Please check your storage bucket policies.';
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$errorMessage: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingProduct != null ? "Edit Product" : "Add Product",
          style: GoogleFonts.urbanist(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xff0c1c2c),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Picker Section
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount:
                      _existingImageUrls.length + _selectedImages.length + 1,
                  itemBuilder: (context, index) {
                    // Add button at the end
                    if (index ==
                        _existingImageUrls.length + _selectedImages.length) {
                      return GestureDetector(
                        onTap: _pickImages,
                        child: Container(
                          width: 100,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.add_a_photo,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    }

                    // Show existing images first
                    if (index < _existingImageUrls.length) {
                      return Container(
                        width: 100,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: NetworkImage(_existingImageUrls[index]),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _existingImageUrls.removeAt(index);
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.8),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Show newly selected images
                    final selectedIndex = index - _existingImageUrls.length;
                    return Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: FileImage(
                            File(_selectedImages[selectedIndex].path),
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedImages.removeAt(selectedIndex);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.8),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 25),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Product Name",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Description",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                items: _supabaseCategories
                    .map(
                      (c) => DropdownMenuItem(
                        value: c['name'] as String,
                        child: Text(c['name']),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedCategory = v),
                decoration: const InputDecoration(
                  labelText: "Category",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Actual Price (₹)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _discountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Discount Price (₹)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Quantity",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dimsController,
                decoration: const InputDecoration(
                  labelText: "Weight & Dimensions (e.g. 2kg, 30x20x10cm)",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff0c1c2c),
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Save Product",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
