import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'venue_list_widget.dart';
import 'category_list_widget.dart';
import '../models/vendor_profile.dart';

class UploadsPage extends StatefulWidget {
  const UploadsPage({super.key});

  @override
  State<UploadsPage> createState() => _UploadsPageState();
}

class _UploadsPageState extends State<UploadsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  VendorProfile? _vendorProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchVendorProfile();
  }

  Future<void> _fetchVendorProfile() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final response = await Supabase.instance.client
          .from('vendors')
          .select()
          .eq('id', userId)
          .single();

      _vendorProfile = VendorProfile.fromJson(response);

      // Initialize tab controller based on role
      final tabCount = _getTabCount();
      _tabController = TabController(length: tabCount, vsync: this);

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error fetching vendor profile: $e');
      setState(() => _isLoading = false);
    }
  }

  int _getTabCount() {
    if (_vendorProfile == null) return 0;

    final canManageVenues = _vendorProfile!.canManageVenues;
    final canManageVendorServices = _vendorProfile!.canManageVendorServices;

    if (canManageVenues && canManageVendorServices) {
      return 2; // Both tabs
    } else if (canManageVenues || canManageVendorServices) {
      return 1; // One tab
    }
    return 0;
  }

  List<Widget> _getTabs() {
    if (_vendorProfile == null) return [];

    final tabs = <Widget>[];

    if (_vendorProfile!.canManageVenues) {
      tabs.add(const Tab(text: 'Venues'));
    }

    if (_vendorProfile!.canManageVendorServices) {
      tabs.add(const Tab(text: 'Categories'));
    }

    return tabs;
  }

  List<Widget> _getTabViews() {
    if (_vendorProfile == null) return [];

    final views = <Widget>[];

    if (_vendorProfile!.canManageVenues) {
      views.add(const VenueListWidget());
    }

    if (_vendorProfile!.canManageVendorServices) {
      views.add(const CategoryListWidget());
    }

    return views;
  }

  @override
  void dispose() {
    if (!_isLoading && _getTabCount() > 0) {
      _tabController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_vendorProfile == null) {
      return Center(
        child: Text(
          'Unable to load profile',
          style: GoogleFonts.urbanist(fontSize: 18),
        ),
      );
    }

    final tabCount = _getTabCount();

    if (tabCount == 0) {
      return Center(
        child: Text(
          'No upload permissions',
          style: GoogleFonts.urbanist(fontSize: 18),
        ),
      );
    }

    if (tabCount == 1) {
      // Single tab, no need for TabBar
      return _getTabViews().first;
    }

    // Multiple tabs
    return Column(
      children: [
        Container(
          color: const Color(0xff0c1c2c),
          child: TabBar(
            controller: _tabController,
            labelColor: const Color.fromARGB(255, 212, 175, 55),
            unselectedLabelColor: Colors.white,
            indicatorColor: const Color.fromARGB(255, 212, 175, 55),
            tabs: _getTabs(),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: _getTabViews(),
          ),
        ),
      ],
    );
  }
}
