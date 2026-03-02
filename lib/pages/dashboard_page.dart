import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vendor/pages/add_product_page.dart';
import 'package:vendor/pages/sales_list_page.dart';
import 'package:vendor/pages/product_list_page.dart';
import 'package:vendor/pages/vendor_profile_view.dart';
import 'uploads_page.dart';
import 'report_issue_page.dart';
import 'extras_page.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentIndex = 0;
  final _supabase = Supabase.instance.client;
  String _userName = "Vendor";

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      setState(() {
        _userName =
            user.userMetadata?['full_name'] ??
            user.email?.split('@')[0] ??
            "Vendor";
      });
    }
  }

  late final List<Widget> _pages = [
    const VendorHome(),
    const UploadsPage(),
    const ExtrasPage(),
    const Center(child: Text("Settings")),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Welcome, $_userName",
          style: GoogleFonts.urbanist(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xff0c1c2c),
        actions: [
          IconButton(
            icon: const Icon(Icons.report_problem, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ReportIssuePage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
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
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xff0c1c2c),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.upload_file),
            label: 'Uploads',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.star), label: 'Extras'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class VendorHome extends StatefulWidget {
  const VendorHome({super.key});

  @override
  State<VendorHome> createState() => _VendorHomeState();
}

class _VendorHomeState extends State<VendorHome> {
  // Key to force FutureBuilder to refresh
  Key _refreshKey = UniqueKey();

  Future<Map<String, dynamic>> getSalesMetrics() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null)
      return {
        'totalProducts': 0,
        'lowStockAlerts': 0,
        'totalSales': 0,
        'totalOrders': 0,
        'totalRevenue': 0.0,
        'pendingOrders': 0,
        'notifications': 0,
      };

    try {
      // Fetch product counts (used for inventory/low stock)
      final allProducts = await supabase
          .from('products')
          .select('id')
          .eq('vendor_id', user.id);

      final lowStockProducts = await supabase
          .from('products')
          .select('id')
          .eq('vendor_id', user.id)
          .lt('quantity', 5);

      // NOTE: The following sales-related fields are placeholders.
      // Replace with real `orders` table queries when ready.
      final totalSales = 0;
      final totalOrders = 0;
      final totalRevenue = 0.0;
      final pendingOrders = 0;
      final notifications = 0;

      return {
        'totalProducts': allProducts.length,
        'lowStockAlerts': lowStockProducts.length,
        'totalSales': totalSales,
        'totalOrders': totalOrders,
        'totalRevenue': totalRevenue,
        'pendingOrders': pendingOrders,
        'notifications': notifications,
      };
    } catch (e) {
      debugPrint("Error fetching metrics: $e");
      return {
        'totalProducts': 0,
        'lowStockAlerts': 0,
        'totalSales': 0,
        'totalOrders': 0,
        'totalRevenue': 0.0,
        'pendingOrders': 0,
        'notifications': 0,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _refreshKey = UniqueKey();
        });
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () async {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) =>
                      const Center(child: CircularProgressIndicator()),
                );

                try {
                  final authService = AuthService();
                  final profile = await authService.getVendorProfile();

                  if (context.mounted) Navigator.pop(context);

                  if (profile != null && context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            VendorProfileView(profile: profile),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) Navigator.pop(context);
                  debugPrint("Navigation error: $e");
                }
              },
              child: const VendorProfileCard(),
            ),
            const SizedBox(height: 24),
            Text(
              "Overview",
              style: GoogleFonts.urbanist(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xff0c1c2c),
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<Map<String, dynamic>>(
              key: _refreshKey,
              future: getSalesMetrics(),
              builder: (context, snapshot) {
                // Show a small loader inside the card area while loading
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }

                final data =
                    snapshot.data ??
                    {
                      'totalProducts': 0,
                      'lowStockAlerts': 0,
                      'totalSales': 0,
                      'totalOrders': 0,
                      'totalRevenue': 0.0,
                      'pendingOrders': 0,
                      'notifications': 0,
                    };

                return Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SalesListPage(metrics: data),
                          ),
                        ),
                        child: _buildStatCard(
                          title: "Sales Info",
                          accentColor: Colors.blue.shade700,
                          icon: Icons.insights,
                          items: [
                            _statRow("Total Sales", "${data['totalSales']}"),
                            _statRow("Sales Details", "View All"),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Inside VendorHome's build method
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProductListPage(),
                          ), // New View Page
                        ),
                        child: _buildStatCard(
                          title: "Product Info",
                          accentColor: Colors.red.shade700,
                          icon: Icons.inventory_2_outlined,
                          items: [
                            _statRow(
                              "Low Stock",
                              "${data['lowStockAlerts']} Items",
                              isAlert: (data['lowStockAlerts'] ?? 0) > 0,
                            ),
                            _statRow("Inventory", "View All"),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required Color accentColor,
    required IconData icon,
    required List<Widget> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accentColor, size: 22),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.blueGrey,
            ),
          ),
          const Divider(height: 20),
          ...items,
        ],
      ),
    );
  }

  Widget _statRow(String label, String value, {bool isAlert = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          Text(
            value,
            style: GoogleFonts.urbanist(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isAlert ? Colors.red : const Color(0xff0c1c2c),
            ),
          ),
        ],
      ),
    );
  }
}

class FetchOptions {
  const FetchOptions({required this.count});
  final CountOption count;
}

class VendorProfileCard extends StatelessWidget {
  const VendorProfileCard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Color(0xff0c1c2c),
            child: Icon(Icons.store, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.userMetadata?['full_name'] ?? "Business Name",
                  style: GoogleFonts.urbanist(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  "GST: Pending Verification",
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
