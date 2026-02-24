import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vendor_profile.dart';
import '../utils/constants.dart';
import '../services/auth_service.dart';
import 'reported_issues_list_page.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  List<VendorProfile> _pendingVendors = [];
  List<VendorProfile> _allVendors = [];
  bool _isLoading = true;
  bool _isLoadingVendors = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _fetchPendingVendors();
  }

  void _onTabChanged() {
    if (_tabController.index == 2 && _allVendors.isEmpty) {
      _fetchAllVendors();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllVendors() async {
    setState(() => _isLoadingVendors = true);
    try {
      final response = await _supabase
          .from('vendors')
          .select()
          .order('created_at', ascending: false);

      final vendors = (response as List)
          .map((e) => VendorProfile.fromJson(e))
          .toList();

      setState(() {
        _allVendors = vendors;
        _isLoadingVendors = false;
      });
    } catch (e) {
      debugPrint('Error fetching vendors: $e');
      if (mounted) {
        setState(() => _isLoadingVendors = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading vendors: $e')));
      }
    }
  }

  Future<void> _deleteVendor(String vendorId) async {
    try {
      // Delete from database
      final response = await _supabase
          .from('vendors')
          .delete()
          .eq('id', vendorId)
          .select();

      debugPrint('Delete response: $response');

      // Update local state only after successful deletion
      setState(() {
        _allVendors.removeWhere((v) => v.id == vendorId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vendor deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on PostgrestException catch (e) {
      debugPrint('PostgrestException deleting vendor: ${e.message}');
      debugPrint('Error code: ${e.code}');
      debugPrint('Error details: ${e.details}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Database error: ${e.message}\n${e.details ?? ""}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting vendor: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting vendor: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _changeVendorRole(String vendorId, String newRole) async {
    try {
      await _supabase
          .from('vendors')
          .update({'role': newRole})
          .eq('id', vendorId);
      setState(() {
        final index = _allVendors.indexWhere((v) => v.id == vendorId);
        if (index != -1) {
          _allVendors[index] = _allVendors[index].copyWith(role: newRole);
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Role updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating role: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating role: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _fetchPendingVendors() async {
    try {
      final response = await _supabase
          .from('vendors')
          .select()
          .eq('verification_status', 'pending');

      final vendors = (response as List)
          .map((e) => VendorProfile.fromJson(e))
          .toList();

      setState(() {
        _pendingVendors = vendors;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching vendors: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(
    String vendorId,
    String status, {
    String? reason,
  }) async {
    try {
      await _supabase
          .from('vendors')
          .update({'verification_status': status, 'rejection_reason': reason})
          .eq('id', vendorId);

      await _fetchPendingVendors();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Vendor ${status == 'verified' ? 'Approved' : 'Rejected'}",
            ),
            backgroundColor: status == 'verified' ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _showRejectDialog(String vendorId) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Reject Application",
          style: GoogleFonts.urbanist(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            hintText: "Reason for rejection",
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.isNotEmpty) {
                Navigator.pop(context);
                _updateStatus(
                  vendorId,
                  'rejected',
                  reason: reasonController.text,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Reject"),
          ),
        ],
      ),
    );
  }

  void _showDocument(String? path) {
    if (path == null) return;

    final url = _supabase.storage.from('vendor_docs').getPublicUrl(path);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  url,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 200,
                      width: 200,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    padding: const EdgeInsets.all(20),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 40),
                        Text("Could not load document"),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Admin Dashboard",
          style: GoogleFonts.urbanist(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xff0c1c2c),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelStyle: GoogleFonts.urbanist(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(
              icon: Icon(Icons.pending_actions),
              text: "Vendor Verifications",
            ),
            Tab(icon: Icon(Icons.report_problem), text: "Reported Issues"),
            Tab(icon: Icon(Icons.manage_accounts), text: "Manage Vendors"),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(
                  context,
                  AppConstants.loginRoute,
                );
              }
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Vendor Verifications Tab
          _buildVendorVerificationsTab(),
          // Reported Issues Tab
          const ReportedIssuesListPage(),
          // Manage Vendors Tab
          _buildManageVendorsTab(),
        ],
      ),
    );
  }

  Widget _buildVendorVerificationsTab() {
    return RefreshIndicator(
      onRefresh: _fetchPendingVendors,
      color: const Color(0xff0c1c2c),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingVendors.isEmpty
          ? ListView(
              // Using ListView to allow pull-to-refresh even when empty
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 200),
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: Colors.green[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "No pending applications",
                        style: GoogleFonts.urbanist(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Pull down to refresh",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: _pendingVendors.length,
              itemBuilder: (context, index) {
                final vendor = _pendingVendors[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(0xff0c1c2c),
                              child: Text(
                                vendor.fullName[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    vendor.fullName,
                                    style: GoogleFonts.urbanist(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    vendor.email,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  _buildRoleBadge(vendor.role),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        _buildInfoRow(Icons.phone, vendor.phone),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          Icons.location_on,
                          "${vendor.address}, ${vendor.city}, ${vendor.state} - ${vendor.pincode}",
                        ),
                        if (vendor.identificationUrl != null) ...[
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: () =>
                                _showDocument(vendor.identificationUrl),
                            icon: const Icon(Icons.file_present),
                            label: const Text("View ID Document"),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xff0c1c2c),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => _showRejectDialog(vendor.id),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: const Text("Reject"),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () =>
                                  _updateStatus(vendor.id, 'verified'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text("Verify"),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey[700], fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleBadge(String role) {
    final Map<String, Map<String, dynamic>> roleConfig = {
      'admin': {
        'label': 'Admin Account',
        'color': Colors.red,
        'icon': Icons.admin_panel_settings,
      },
      'venue_distributor': {
        'label': 'Venue Distributor',
        'color': Colors.blue,
        'icon': Icons.business,
      },
      'vendor_distributor': {
        'label': 'Vendor Services',
        'color': Colors.green,
        'icon': Icons.store,
      },
      'venue_vendor_distributor': {
        'label': 'Venue & Services',
        'color': Colors.purple,
        'icon': Icons.business_center,
      },
    };

    final config = roleConfig[role] ?? roleConfig['venue_distributor']!;
    final isAdmin = role == 'admin';

    return Container(
      decoration: BoxDecoration(
        color: (config['color'] as Color).withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: config['color'] as Color, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            config['icon'] as IconData,
            size: 14,
            color: config['color'] as Color,
          ),
          const SizedBox(width: 4),
          Text(
            config['label'] as String,
            style: TextStyle(
              color: config['color'] as Color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (isAdmin) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text(
                'REQUIRES ADMIN APPROVAL',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildManageVendorsTab() {
    return RefreshIndicator(
      onRefresh: _fetchAllVendors,
      color: const Color(0xff0c1c2c),
      child: _isLoadingVendors
          ? const Center(child: CircularProgressIndicator())
          : _allVendors.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 200),
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 64,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "No vendors found",
                        style: GoogleFonts.urbanist(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Pull down to refresh",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: _allVendors.length,
              itemBuilder: (context, index) {
                final vendor = _allVendors[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(0xff0c1c2c),
                              child: Text(
                                vendor.fullName[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    vendor.fullName,
                                    style: GoogleFonts.urbanist(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    vendor.email,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  _buildRoleBadge(vendor.role),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getVerificationColor(
                                  vendor.verificationStatus,
                                ).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _getVerificationColor(
                                    vendor.verificationStatus,
                                  ),
                                ),
                              ),
                              child: Text(
                                vendor.verificationStatus.toUpperCase(),
                                style: TextStyle(
                                  color: _getVerificationColor(
                                    vendor.verificationStatus,
                                  ),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _showRoleChangeDialog(vendor),
                                icon: const Icon(Icons.swap_horiz, size: 18),
                                label: const Text('Change Role'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xff0c1c2c),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _confirmDeleteVendor(vendor),
                                icon: const Icon(Icons.delete, size: 18),
                                label: const Text('Delete'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Color _getVerificationColor(String status) {
    switch (status) {
      case 'verified':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showRoleChangeDialog(VendorProfile vendor) {
    String selectedRole = vendor.role;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Change Role for ${vendor.fullName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildRoleRadio('Admin', 'admin', selectedRole, (value) {
                setState(() => selectedRole = value!);
              }),
              _buildRoleRadio(
                'Venue Distributor',
                'venue_distributor',
                selectedRole,
                (value) {
                  setState(() => selectedRole = value!);
                },
              ),
              _buildRoleRadio(
                'Vendor Services',
                'vendor_distributor',
                selectedRole,
                (value) {
                  setState(() => selectedRole = value!);
                },
              ),
              _buildRoleRadio(
                'Both',
                'venue_vendor_distributor',
                selectedRole,
                (value) {
                  setState(() => selectedRole = value!);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _changeVendorRole(vendor.id, selectedRole);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff0c1c2c),
              ),
              child: const Text('Update Role'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleRadio(
    String title,
    String value,
    String groupValue,
    ValueChanged<String?> onChanged,
  ) {
    return RadioListTile<String>(
      title: Text(title),
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      activeColor: const Color(0xff0c1c2c),
    );
  }

  void _confirmDeleteVendor(VendorProfile vendor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vendor'),
        content: Text(
          'Are you sure you want to delete ${vendor.fullName}? This action cannot be undone and will remove all associated data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteVendor(vendor.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
