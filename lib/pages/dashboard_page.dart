import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'sales_list_page.dart';
import 'vendor_profile_view.dart';
import 'report_issue_page.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import '../models/order.dart';
import 'product_details_page.dart';
import 'orders_page.dart';
import 'alerts_page.dart';

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
      // Changed terminology: products -> services
      final allServices = await supabase
          .from('products')
          .select('id')
          .eq('vendor_id', user.id);

      // Fetch orders data
      List<Order> orders = [];
      int totalSales = 0;
      double totalRevenue = 0.0;
      int totalOrders = 0;
      int pendingOrders = 0;

      try {
        final ordersData = await supabase
            .from('orders')
            .select()
            .eq('vendor_id', user.id)
            .order('created_at', ascending: false);

        orders = (ordersData as List).map((o) => Order.fromJson(o)).toList();

        totalSales = orders.fold(0, (sum, o) => sum + o.quantity);
        totalRevenue = orders.fold(0.0, (sum, o) => sum + o.totalPrice);
        totalOrders = orders.length;

        pendingOrders = orders
            .where(
              (o) => [
                'accepted',
                'pending',
                'shipped',
              ].contains(o.status.toLowerCase()),
            )
            .length;

        int requestsCount = orders
            .where((o) => o.status.toLowerCase() == 'request')
            .length;

        return {
          'totalServices': allServices.length,
          'totalSales': totalSales,
          'totalOrders': totalOrders,
          'totalRevenue': totalRevenue,
          'pendingOrders': pendingOrders,
          'notifications': requestsCount,
          'orders': orders,
        };
      } catch (e) {
        debugPrint("Error fetching orders: $e");
      }
      return _emptyMetrics();
    } catch (e) {
      debugPrint("Error fetching metrics: $e");
      return _emptyMetrics();
    }
  }

  Map<String, dynamic> _emptyMetrics() => {
    'totalServices': 0,
    'totalSales': 0,
    'totalOrders': 0,
    'totalRevenue': 0.0,
    'pendingOrders': 0,
    'notifications': 0,
    'orders': [],
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
              "Business Overview",
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
                    // ROW 1: Earnings & Services
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
                            title: "Earnings Info",
                            accentColor: Colors.blue.shade700,
                            icon: Icons.payments_outlined,
                            items: [
                              _statRow(
                                "Total Revenue",
                                "₹${data['totalRevenue']}",
                              ),
                              _statRow(
                                "Total Bookings",
                                "${data['totalSales']}",
                              ),
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
                            title: "Service Info",
                            accentColor: Colors.orange.shade800,
                            icon: Icons.design_services_outlined,
                            items: [
                              _statRow(
                                "Active Services",
                                "${data['totalServices']}",
                              ),
                              _statRow("Catalog", "View All"),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // ROW 2: Bookings & Notifications
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const OrdersPage(),
                              ),
                            ),
                            title: "Bookings",
                            accentColor: Colors.purple.shade700,
                            icon: Icons.event_note_outlined,
                            items: [
                              _statRow("Upcoming", "${data['pendingOrders']}"),
                              _statRow("History", "View Log"),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AlertsPage(),
                              ),
                            ),
                            title: "Action Alerts",
                            accentColor: Colors.teal.shade700,
                            icon: Icons.notification_important_outlined,
                            items: [
                              _statRow("User Requests", "Confirm/Decline"),
                              _statRow(
                                "New Alerts",
                                "${data['notifications']}",
                                isAlert: (data['notifications'] ?? 0) > 0,
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
    VoidCallback? onTap,
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
            child: Icon(Icons.business_center, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.userMetadata?['full_name'] ?? "Service Provider",
                  style: GoogleFonts.urbanist(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  "Verification Status: Pending",
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
