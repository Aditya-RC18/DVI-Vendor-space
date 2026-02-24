import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/venue_data.dart';

/// Service for managing venue data in Supabase
class VenueDataService {
  final _supabase = Supabase.instance.client;

  // Storage bucket name for venue images
  static const String _storageBucket = 'venue_images';

  /// Get current vendor's ID
  String? get _currentVendorId => _supabase.auth.currentUser?.id;

  /// Fetch all venues for the current vendor
  Future<List<VenueData>> getVendorVenues() async {
    if (_currentVendorId == null) return [];

    try {
      final response = await _supabase
          .from('venue_data')
          .select()
          .eq('vendor_id', _currentVendorId!)
          .order('created_at', ascending: false);

      final venues = (response as List)
          .map((e) => VenueData.fromJson(e))
          .toList();

      // Load services and gallery for each venue
      for (var i = 0; i < venues.length; i++) {
        venues[i] = venues[i].copyWith(
          services: await getVenueServices(venues[i].id!),
          galleryImages: await getVenueGallery(venues[i].id!),
        );
      }

      return venues;
    } catch (e) {
      debugPrint('Error fetching venues: $e');
      return [];
    }
  }

  /// Get a single venue by ID with all related data
  Future<VenueData?> getVenueById(String venueId) async {
    try {
      final response = await _supabase
          .from('venue_data')
          .select()
          .eq('id', venueId)
          .single();

      final venue = VenueData.fromJson(response);
      return venue.copyWith(
        services: await getVenueServices(venueId),
        galleryImages: await getVenueGallery(venueId),
      );
    } catch (e) {
      debugPrint('Error fetching venue: $e');
      return null;
    }
  }

  /// Create a new venue
  Future<VenueData?> createVenue(VenueData venue) async {
    if (_currentVendorId == null) return null;

    try {
      final data = venue.toJson();
      data['vendor_id'] = _currentVendorId;

      final response = await _supabase
          .from('venue_data')
          .insert(data)
          .select()
          .single();

      return VenueData.fromJson(response);
    } catch (e) {
      debugPrint('Error creating venue: $e');
      rethrow;
    }
  }

  /// Update an existing venue
  Future<VenueData?> updateVenue(VenueData venue) async {
    if (venue.id == null) return null;

    try {
      final data = venue.toJson();
      data['updated_at'] = DateTime.now().toIso8601String();

      // Remove empty string UUIDs to prevent validation errors
      if (data['vendor_id'] == null || data['vendor_id'] == '') {
        data.remove('vendor_id');
      }

      final response = await _supabase
          .from('venue_data')
          .update(data)
          .eq('id', venue.id!)
          .select()
          .single();

      return VenueData.fromJson(response);
    } catch (e) {
      debugPrint('Error updating venue: $e');
      rethrow;
    }
  }

  /// Delete a venue and all related data
  Future<bool> deleteVenue(String venueId) async {
    try {
      // Delete gallery images from storage first
      final gallery = await getVenueGallery(venueId);
      for (final image in gallery) {
        await _supabase.storage.from(_storageBucket).remove([
          image.imageFilename,
        ]);
      }

      // Delete venue (cascade will handle services and gallery records)
      await _supabase.from('venue_data').delete().eq('id', venueId);
      return true;
    } catch (e) {
      debugPrint('Error deleting venue: $e');
      return false;
    }
  }

  // ==================== Services ====================

  /// Get all services for a venue
  Future<List<VenueService>> getVenueServices(String venueId) async {
    try {
      final response = await _supabase
          .from('venue_services')
          .select()
          .eq('venue_id', venueId)
          .order('created_at');

      return (response as List).map((e) => VenueService.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error fetching venue services: $e');
      return [];
    }
  }

  /// Add a service to a venue
  Future<VenueService?> addVenueService(
    String venueId,
    VenueService service,
  ) async {
    try {
      final data = service.toJson();
      data['venue_id'] = venueId;

      final response = await _supabase
          .from('venue_services')
          .insert(data)
          .select()
          .single();

      return VenueService.fromJson(response);
    } catch (e) {
      debugPrint('Error adding venue service: $e');
      rethrow;
    }
  }

  /// Update a service
  Future<VenueService?> updateVenueService(VenueService service) async {
    if (service.id == null) return null;

    try {
      final response = await _supabase
          .from('venue_services')
          .update(service.toJson())
          .eq('id', service.id!)
          .select()
          .single();

      return VenueService.fromJson(response);
    } catch (e) {
      debugPrint('Error updating venue service: $e');
      rethrow;
    }
  }

  /// Delete a service
  Future<bool> deleteVenueService(String serviceId) async {
    try {
      await _supabase.from('venue_services').delete().eq('id', serviceId);
      return true;
    } catch (e) {
      debugPrint('Error deleting venue service: $e');
      return false;
    }
  }

  /// Replace all services for a venue (delete existing, add new)
  Future<List<VenueService>> replaceVenueServices(
    String venueId,
    List<VenueService> services,
  ) async {
    try {
      // Delete existing services
      await _supabase.from('venue_services').delete().eq('venue_id', venueId);

      // Add new services
      final List<VenueService> result = [];
      for (final service in services) {
        final added = await addVenueService(venueId, service);
        if (added != null) result.add(added);
      }

      return result;
    } catch (e) {
      debugPrint('Error replacing venue services: $e');
      rethrow;
    }
  }

  // ==================== Gallery ====================

  /// Get gallery images for a venue
  Future<List<VenueGalleryImage>> getVenueGallery(String venueId) async {
    try {
      final response = await _supabase
          .from('venue_gallery')
          .select()
          .eq('venue_id', venueId)
          .order('display_order');

      return (response as List)
          .map((e) => VenueGalleryImage.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('Error fetching venue gallery: $e');
      return [];
    }
  }

  /// Upload an image to venue gallery
  Future<VenueGalleryImage?> uploadGalleryImage(
    String venueId,
    File imageFile,
    int displayOrder,
  ) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = imageFile.path.split('.').last;
      final filename = '${venueId}_${timestamp}.$extension';

      // Upload to storage
      await _supabase.storage
          .from(_storageBucket)
          .uploadBinary(filename, bytes);

      // Create gallery record
      final response = await _supabase
          .from('venue_gallery')
          .insert({
            'venue_id': venueId,
            'image_filename': filename,
            'display_order': displayOrder,
          })
          .select()
          .single();

      return VenueGalleryImage.fromJson(response);
    } catch (e) {
      debugPrint('Error uploading gallery image: $e');
      rethrow;
    }
  }

  /// Delete a gallery image
  Future<bool> deleteGalleryImage(VenueGalleryImage image) async {
    try {
      // Delete from storage
      await _supabase.storage.from(_storageBucket).remove([
        image.imageFilename,
      ]);

      // Delete record
      if (image.id != null) {
        await _supabase.from('venue_gallery').delete().eq('id', image.id!);
      }

      return true;
    } catch (e) {
      debugPrint('Error deleting gallery image: $e');
      return false;
    }
  }

  /// Get public URL for a gallery image
  String getGalleryImageUrl(String filename) {
    return _supabase.storage.from(_storageBucket).getPublicUrl(filename);
  }
}
