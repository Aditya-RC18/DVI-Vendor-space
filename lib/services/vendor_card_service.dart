import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vendor_card.dart';

/// Service for managing vendor card operations
class VendorCardService {
  final _supabase = Supabase.instance.client;
  static const String _bucketName = 'vendor_card';
  static const String _tableName = 'vendor_cards';

  /// Get current vendor ID from auth session
  String? get currentVendorId {
    return _supabase.auth.currentUser?.id;
  }

  /// Get all vendor cards for the current vendor
  Future<List<VendorCard>> getVendorCards() async {
    final vendorId = currentVendorId;
    if (vendorId == null) {
      throw Exception('User not authenticated');
    }

    final response = await _supabase
        .from(_tableName)
        .select()
        .eq('vendor_id', vendorId)
        .order('created_at', ascending: false);

    return (response as List).map((json) => VendorCard.fromJson(json)).toList();
  }

  /// Get vendor cards by category
  Future<List<VendorCard>> getVendorCardsByCategory(int categoryId) async {
    final vendorId = currentVendorId;
    if (vendorId == null) {
      throw Exception('User not authenticated');
    }

    final response = await _supabase
        .from(_tableName)
        .select()
        .eq('vendor_id', vendorId)
        .eq('category_id', categoryId)
        .order('created_at', ascending: false);

    return (response as List).map((json) => VendorCard.fromJson(json)).toList();
  }

  /// Upload image to Supabase storage
  /// Returns the image path in format: "foldername/filename.jpg"
  Future<String> uploadImage(
    File imageFile,
    int categoryId,
    String studioName,
  ) async {
    final vendorId = currentVendorId;
    if (vendorId == null) {
      throw Exception('User not authenticated');
    }

    // Get folder name based on category
    final folderName = VendorCard.getFolderName(categoryId);

    // Generate unique filename
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final sanitizedStudioName = studioName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final fileName = '${sanitizedStudioName}_$timestamp.jpg';

    // Full path in storage
    final storagePath = '$folderName/$fileName';

    // Read file as bytes
    final bytes = await imageFile.readAsBytes();

    // Upload to Supabase storage
    await _supabase.storage.from(_bucketName).uploadBinary(storagePath, bytes);

    // Return the path (not full URL, just path)
    return storagePath;
  }

  /// Get public URL for an image
  String getImageUrl(String imagePath) {
    return _supabase.storage.from(_bucketName).getPublicUrl(imagePath);
  }

  /// Create a new vendor card
  Future<VendorCard> createVendorCard(VendorCard card) async {
    final vendorId = currentVendorId;
    if (vendorId == null) {
      throw Exception('User not authenticated');
    }

    // Ensure vendor_id matches current user
    final cardData = card.copyWith(vendorId: vendorId).toJson();

    final response = await _supabase
        .from(_tableName)
        .insert(cardData)
        .select()
        .single();

    return VendorCard.fromJson(response);
  }

  /// Update an existing vendor card
  Future<VendorCard> updateVendorCard(VendorCard card) async {
    if (card.id == null) {
      throw Exception('Card ID is required for update');
    }

    final vendorId = currentVendorId;
    if (vendorId == null) {
      throw Exception('User not authenticated');
    }

    // Ensure vendor owns this card (will throw if not found)
    await _supabase
        .from(_tableName)
        .select()
        .eq('id', card.id!)
        .eq('vendor_id', vendorId)
        .single();

    final response = await _supabase
        .from(_tableName)
        .update(card.toJson())
        .eq('id', card.id!)
        .select()
        .single();

    return VendorCard.fromJson(response);
  }

  /// Delete a vendor card
  Future<bool> deleteVendorCard(int cardId) async {
    final vendorId = currentVendorId;
    if (vendorId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Get card details to delete image
      final cardData = await _supabase
          .from(_tableName)
          .select()
          .eq('id', cardId)
          .eq('vendor_id', vendorId)
          .single();

      final card = VendorCard.fromJson(cardData);

      // Delete from database
      await _supabase
          .from(_tableName)
          .delete()
          .eq('id', cardId)
          .eq('vendor_id', vendorId);

      // Try to delete image from storage (non-blocking)
      try {
        await _supabase.storage.from(_bucketName).remove([card.imagePath]);
      } catch (e) {
        // Image deletion failed, but card is already deleted from DB
        debugPrint('Warning: Could not delete image: $e');
      }

      return true;
    } catch (e) {
      debugPrint('Error deleting vendor card: $e');
      return false;
    }
  }

  /// Delete old image when updating
  Future<void> deleteImage(String imagePath) async {
    try {
      await _supabase.storage.from(_bucketName).remove([imagePath]);
    } catch (e) {
      debugPrint('Warning: Could not delete old image: $e');
    }
  }

  /// Validate card data before submission
  String? validateCard(VendorCard card) {
    if (card.studioName.trim().isEmpty) {
      return 'Studio name is required';
    }
    if (card.city.trim().isEmpty) {
      return 'City is required';
    }
    if (card.imagePath.trim().isEmpty) {
      return 'Image is required';
    }
    if (card.serviceTags.isEmpty) {
      return 'Please select at least one service tag';
    }
    if (card.serviceTags.length > 2) {
      return 'Maximum 2 service tags allowed';
    }
    if (card.qualityTags.isEmpty) {
      return 'Please select at least one quality tag';
    }
    if (card.qualityTags.length > 2) {
      return 'Maximum 2 quality tags allowed';
    }
    if (card.originalPrice <= 0) {
      return 'Original price must be greater than 0';
    }
    if (card.discountedPrice <= 0) {
      return 'Discounted price must be greater than 0';
    }
    if (card.discountedPrice >= card.originalPrice) {
      return 'Discounted price must be less than original price';
    }
    return null; // Valid
  }
}
