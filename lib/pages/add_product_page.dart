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

  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _discountController = TextEditingController();
  final _qtyController = TextEditingController();
  final _dimsController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  // ── New: store bytes instead of XFile paths ──
  final List<Uint8List> _selectedImageBytes = [];
  final List<String> _selectedImageNames = [];
  List<String> _existingImageUrls = [];

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

      final imageUrlData = p['image_url'];
      if (imageUrlData != null && imageUrlData.isNotEmpty) {
        try {
          if (imageUrlData is String) {
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

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _discountController.dispose();
    _qtyController.dispose();
    _dimsController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    final data = await _supabase
        .from('vendor_categories')
        .select('name')
        .eq('is_active', true);
    setState(() => _supabaseCategories = List<Map<String, dynamic>>.from(data));
  }

  // ── Read bytes immediately after picking ──
  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      for (final image in images) {
        try {
          final bytes = await image.readAsBytes();
          setState(() {
            _selectedImageBytes.add(bytes);
            _selectedImageNames.add(image.name);
          });
        } catch (e) {
          debugPrint('Error reading image: $e');
        }
      }
    }
  }

  // ── Upload using bytes, not file path ──
  Future<List<String>> _uploadImages(String productId) async {
    List<String> imageUrls = [];
    final userId = _supabase.auth.currentUser!.id;

    for (int i = 0; i < _selectedImageBytes.length; i++) {
      final bytes = _selectedImageBytes[i];
      final name = _selectedImageNames[i];
      final fileExt = name.split('.').last.toLowerCase();
      final filePath =
          '$userId/$productId/img_${DateTime.now().millisecondsSinceEpoch}_$i.$fileExt';

      try {
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

        final url = _supabase.storage
            .from('vendor_assets')
            .getPublicUrl(filePath);
        imageUrls.add(url);
        debugPrint('✅ Image $i uploaded: $url');
      } catch (e) {
        debugPrint('❌ Upload failed for image $i: $e');
      }
    }
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

      // ── Use _selectedImageBytes instead of _selectedImages ──
      if (_selectedImageBytes.isNotEmpty) {
        final newUrls = await _uploadImages(productId);
        final allUrls = [..._existingImageUrls, ...newUrls];
        final imageUrlJson = jsonEncode(allUrls);
        await _supabase
            .from('products')
            .update({'image_url': imageUrlJson})
            .eq('id', productId);
        debugPrint('✅ Images saved: $imageUrlJson');
      } else if (_existingImageUrls.isNotEmpty) {
        final imageUrlJson = jsonEncode(_existingImageUrls);
        await _supabase
            .from('products')
            .update({'image_url': imageUrlJson})
            .eq('id', productId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _nameController.clear();
        _descController.clear();
        _priceController.clear();
        _discountController.clear();
        _qtyController.clear();
        _dimsController.clear();
        setState(() {
          _selectedImageBytes.clear();
          _selectedImageNames.clear();
          _existingImageUrls.clear();
          _selectedCategory = null;
        });
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving product: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
              // ── Image Picker Section ──
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  // ── Use _selectedImageBytes.length ──
                  itemCount:
                      _existingImageUrls.length +
                      _selectedImageBytes.length +
                      1,
                  itemBuilder: (context, index) {
                    // Add button at end
                    if (index ==
                        _existingImageUrls.length +
                            _selectedImageBytes.length) {
                      return GestureDetector(
                        onTap: _pickImages,
                        child: Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 8),
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

                    // Existing images from DB
                    if (index < _existingImageUrls.length) {
                      return Container(
                        width: 100,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                _existingImageUrls[index],
                                width: 100,
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      width: 100,
                                      height: 120,
                                      color: Colors.grey.shade200,
                                      child: const Icon(Icons.broken_image),
                                    ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () {
                                  setState(
                                    () => _existingImageUrls.removeAt(index),
                                  );
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

                    // ── Newly selected images using bytes ──
                    final selectedIndex = index - _existingImageUrls.length;
                    return Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              _selectedImageBytes[selectedIndex],
                              width: 100,
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedImageBytes.removeAt(selectedIndex);
                                  _selectedImageNames.removeAt(selectedIndex);
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

              // ── Form Fields ──
              TextFormField(
                controller: _nameController,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Name is required' : null,
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
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Price is required' : null,
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
                validator: (v) =>
                    v == null || v.isEmpty ? 'Quantity is required' : null,
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
