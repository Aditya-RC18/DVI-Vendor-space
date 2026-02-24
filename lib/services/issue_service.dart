import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/reported_issue.dart';

class IssueService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  /// Submit a new issue report
  Future<ReportedIssue?> submitIssue(ReportedIssue issue) async {
    try {
      final response = await _supabase
          .from('reported_issues')
          .insert(issue.toJson())
          .select()
          .single();

      debugPrint('✅ Issue reported: ${response['id']}');
      return ReportedIssue.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error submitting issue: $e');
      rethrow;
    }
  }

  /// Get all issues for a specific vendor (vendor can view their own issues)
  Future<List<ReportedIssue>> getIssuesForVendor(String vendorId) async {
    try {
      final response = await _supabase
          .from('reported_issues')
          .select()
          .eq('reporter_id', vendorId)
          .order('created_at', ascending: false);

      return (response as List).map((e) => ReportedIssue.fromJson(e)).toList();
    } catch (e) {
      debugPrint('❌ Error fetching vendor issues: $e');
      rethrow;
    }
  }

  /// Get all issues with reporter details (admin only)
  Future<List<ReportedIssue>> getAllIssues({String? statusFilter}) async {
    try {
      // Build base query
      final baseQuery = _supabase.from('reported_issues').select('''
        *,
        vendors!reporter_id (
          full_name,
          email
        )
      ''');

      // Apply filter and ordering based on whether we have a status filter
      final response = statusFilter != null && statusFilter.isNotEmpty
          ? await baseQuery
                .eq('status', statusFilter)
                .order('created_at', ascending: false)
          : await baseQuery.order('created_at', ascending: false);

      return (response as List).map((e) {
        final issue = ReportedIssue.fromJson(e);
        // Extract reporter info from joined data
        if (e['vendors'] != null) {
          issue.reporterName = e['vendors']['full_name'];
          issue.reporterEmail = e['vendors']['email'];
        }
        return issue;
      }).toList();
    } catch (e) {
      debugPrint('❌ Error fetching all issues: $e');
      rethrow;
    }
  }

  /// Update issue status (admin only)
  Future<void> updateIssueStatus(String issueId, String status) async {
    try {
      await _supabase
          .from('reported_issues')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .match({'id': issueId});

      debugPrint('✅ Issue status updated: $issueId -> $status');
    } catch (e) {
      debugPrint('❌ Error updating issue status: $e');
      rethrow;
    }
  }

  /// Delete an issue (admin only)
  Future<void> deleteIssue(String issueId) async {
    try {
      await _supabase.from('reported_issues').delete().eq('id', issueId);
      debugPrint('✅ Issue deleted: $issueId');
    } catch (e) {
      debugPrint('❌ Error deleting issue: $e');
      rethrow;
    }
  }
}
