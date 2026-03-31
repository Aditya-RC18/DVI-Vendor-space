import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Ensure these paths match your project structure exactly
import 'product_details_page.dart';
import 'sales_list_page.dart';
import 'vendor_profile_view.dart';
import 'report_issue_page.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
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
        elevation: 0,
        actions: [
          // Settings Gear Icon
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: 'Settings',
            onPressed: () async {
              final profile = await AuthService().getVendorProfile();
              if (profile != null && context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VendorProfileView(profile: profile),
                  ),
                );
              }
            },
          ),
          // Logout Icon
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
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
          const SizedBox(width: 8),
        ],
      ),

      body: const VendorHome(),

      // Floating Action Button for Support
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ReportIssuePage()),
          );
        },
        backgroundColor: const Color(0xff0c1c2c),
        icon: const Icon(Icons.support_agent, color: Colors.white),
        label: const Text(
          "Report Issue",
          style: TextStyle(color: Colors.white),
        ),
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
  Key _refreshKey = UniqueKey();

  Future<Map<String, dynamic>> getSalesMetrics() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return _emptyMetrics();

    try {
      final allProducts = await supabase
          .from('products')
          .select('id')
          .eq('vendor_id', user.id);

      final lowStockProducts = await supabase
          .from('products')
          .select('id')
          .eq('vendor_id', user.id)
          .lt('quantity', 5);

      // Placeholders for expanded metrics
      return {
        'totalProducts': allProducts.length,
        'lowStockAlerts': lowStockProducts.length,
        'totalSales': 0,
        'totalOrders': 0,
        'totalRevenue': 0.0,
        'pendingOrders': 0,
        'notifications': 0,
      };
    } catch (e) {
      debugPrint("Error fetching metrics: $e");
      return _emptyMetrics();
    }
  }

  Map<String, dynamic> _emptyMetrics() => {
    'totalProducts': 0,
    'lowStockAlerts': 0,
    'totalSales': 0,
    'totalOrders': 0,
    'totalRevenue': 0.0,
    'pendingOrders': 0,
    'notifications': 0,
  };

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
            const VendorProfileCard(),
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
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }

                final data = snapshot.data ?? _emptyMetrics();

                return Column(
                  children: [
                    // ROW 1: Sales & Inventory
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    SalesListPage(metrics: data),
                              ),
                            ),
                            title: "Sales Info",
                            accentColor: Colors.blue.shade700,
                            icon: Icons.insights,
                            items: [
                              _statRow("Total Sales", "${data['totalSales']}"),
                              _statRow("Revenue", "₹${data['totalRevenue']}"),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ProductListPage(),
                              ),
                            ),
                            title: "Product Info",
                            accentColor: Colors.orange.shade800,
                            icon: Icons.inventory_2_outlined,
                            items: [
                              _statRow(
                                "Low Stock",
                                "${data['lowStockAlerts']} Items",
                                isAlert: data['lowStockAlerts'] > 0,
                              ),
                              _statRow("Inventory", "View All"),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // ROW 2: Orders & Notifications
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            onTap: () {
                              /* Future Orders Page */
                            },
                            title: "Orders",
                            accentColor: Colors.purple.shade700,
                            icon: Icons.local_shipping_outlined,
                            items: [
                              _statRow("Pending", "${data['pendingOrders']}"),
                              _statRow("History", "View Orders"),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            onTap: () {
                              /* Future Notifications Page */
                            },
                            title: "Alerts",
                            accentColor: Colors.teal.shade700,
                            icon: Icons.notifications_active_outlined,
                            items: [
                              _statRow("Requests", "Approve/Reject"),
                              _statRow(
                                "Updates",
                                "${data['notifications']} New",
                              ),
                            ],
                          ),
                        ),
                      ],
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
    VoidCallback? onTap, // Added interactivity
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
