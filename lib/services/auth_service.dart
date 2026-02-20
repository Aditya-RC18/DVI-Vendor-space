import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/vendor_profile.dart';
import '../utils/constants.dart';

class AuthService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> vendorData,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user != null) {
        debugPrint('✅ User signed up: ${response.user!.id}');

        // Add ID to vendor data
        vendorData['id'] = response.user!.id;

        await _createVendorProfile(vendorData);
      }

      return response;
    } catch (e) {
      debugPrint('❌ Signup error: $e');
      rethrow;
    }
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        debugPrint('✅ User signed in: ${response.user!.id}');
        // Optionally cache user data
      }

      return response;
    } catch (e) {
      debugPrint('❌ Login error: $e');
      rethrow;
    }
  }

  Future<bool> signInWithGoogle() async {
    try {
      return await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.flutter://signin-callback/',
      );
    } catch (e) {
      debugPrint('❌ Google sign-in error: $e');
      rethrow;
    }
  }

  Future<bool> signInWithFacebook() async {
    try {
      return await _supabase.auth.signInWithOAuth(
        OAuthProvider.facebook,
        redirectTo: 'io.supabase.flutter://signin-callback/',
      );
    } catch (e) {
      debugPrint('❌ Facebook sign-in error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.userCacheKey);
  }

  Future<void> _createVendorProfile(Map<String, dynamic> data) async {
    try {
      await _supabase.from('vendors').insert(data);
      debugPrint('✅ Vendor profile created');
    } catch (e) {
      debugPrint('⚠️ Profile creation error: $e');
      rethrow; // Important to fail if profile creation fails
    }
  }

  Future<VendorProfile?> getVendorProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final response = await _supabase
          .from('vendors')
          .select()
          .eq('id', user.id)
          .maybeSingle(); // Use maybeSingle() to avoid confusing exceptions

      if (response == null) {
        debugPrint('⚠️ No vendor profile found for user ${user.id}');
        return null;
      }

      return VendorProfile.fromJson(response);
    } catch (e) {
      debugPrint('⚠️ Failed to get vendor profile: $e');
      return null;
    }
  }

  /// Check if current user is admin
  Future<bool> isAdmin() async {
    final profile = await getVendorProfile();
    return profile?.isAdmin ?? false;
  }

  /// Get current user's role
  Future<String?> getUserRole() async {
    final profile = await getVendorProfile();
    return profile?.role;
  }

  /// Get current user ID
  String? getCurrentUserId() {
    return _supabase.auth.currentUser?.id;
  }
}
