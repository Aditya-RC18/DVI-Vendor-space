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
import '../models/order.dart';

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
  Set<String> _dismissedOrderIds = {};

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

        orders = (ordersData as List)
            .map((o) => Order.fromJson(o))
            .toList();
        
        totalSales = orders.fold(0, (sum, o) => sum + o.quantity);
        totalRevenue = orders.fold(0.0, (sum, o) => sum + o.totalPrice);
        totalOrders = orders.length;
        pendingOrders = orders.where((o) => o.status == 'pending').length;
      } catch (e) {
        debugPrint("Error fetching orders: $e");
      }

      return {
        'totalProducts': allProducts.length,
        'lowStockAlerts': lowStockProducts.length,
        'totalSales': totalSales,
        'totalOrders': totalOrders,
        'totalRevenue': totalRevenue,
        'pendingOrders': pendingOrders,
        'notifications': 0,
        'orders': orders,
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
                          child: _buildInteractiveSalesCard(
                            context: context,
                            data: data,
                            onTotalSalesTap: () => _showSalesAnalyticsModal(context, data),
                            onTotalOrdersTap: () => _showOrdersAnalyticsModal(context, data),
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

  Widget _buildInteractiveSalesCard({
    required BuildContext context,
    required Map<String, dynamic> data,
    required VoidCallback onTotalSalesTap,
    required VoidCallback onTotalOrdersTap,
  }) {
    final orders = (data['orders'] ?? []) as List<Order>;
    final visibleOrders = orders.where((o) => !_dismissedOrderIds.contains(o.id)).toList();

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
          Row(
            children: [
              Icon(Icons.insights, color: Colors.blue.shade700, size: 22),
              const SizedBox(width: 8),
              Text(
                "Sales Info",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.blueGrey,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          // Total Sales Button
          GestureDetector(
            onTap: onTotalSalesTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.blue.shade200, width: 2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Total Sales",
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${data['totalSales'] ?? 0}",
                        style: GoogleFonts.urbanist(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xff0c1c2c),
                        ),
                      ),
                      Icon(Icons.arrow_forward, size: 14, color: Colors.blue.shade700),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Total Orders Button
          GestureDetector(
            onTap: onTotalOrdersTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.blue.shade200, width: 2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Total Orders",
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${data['totalOrders'] ?? 0}",
                        style: GoogleFonts.urbanist(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xff0c1c2c),
                        ),
                      ),
                      Icon(Icons.arrow_forward, size: 14, color: Colors.blue.shade700),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Recent Orders Notifications
          Text(
            "Recent Orders",
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey,
            ),
          ),
          const SizedBox(height: 8),
          if (visibleOrders.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                "No recent orders",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            )
          else
            Column(
              children: visibleOrders.take(3).map((order) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.customerName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                "${order.productName} (Qty: ${order.quantity})",
                                style: const TextStyle(fontSize: 9, color: Colors.grey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                "From: ${order.region}",
                                style: const TextStyle(fontSize: 9, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () {
                            setState(() {
                              _dismissedOrderIds.add(order.id);
                            });
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  void _showSalesAnalyticsModal(BuildContext context, Map<String, dynamic> data) {
    final orders = (data['orders'] ?? []) as List<Order>;
    
    Map<String, int> regionWiseSales = {};
    Map<String, int> productWiseSales = {};
    
    for (var order in orders) {
      regionWiseSales[order.region] = (regionWiseSales[order.region] ?? 0) + order.quantity;
      productWiseSales[order.productName] = (productWiseSales[order.productName] ?? 0) + order.quantity;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Sales Analytics"),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  "Region-wise Sales",
                  style: GoogleFonts.urbanist(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (regionWiseSales.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text("No sales data available"),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text("Region")),
                        DataColumn(label: Text("Qty Sold")),
                      ],
                      rows: regionWiseSales.entries.map((e) {
                        return DataRow(cells: [
                          DataCell(Text(e.key)),
                          DataCell(Text("${e.value}")),
                        ]);
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  "Product-wise Sales",
                  style: GoogleFonts.urbanist(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (productWiseSales.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text("No sales data available"),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text("Product")),
                        DataColumn(label: Text("Qty Sold")),
                      ],
                      rows: productWiseSales.entries.map((e) {
                        return DataRow(cells: [
                          DataCell(Text(e.key, overflow: TextOverflow.ellipsis)),
                          DataCell(Text("${e.value}")),
                        ]);
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void _showOrdersAnalyticsModal(BuildContext context, Map<String, dynamic> data) {
    final orders = (data['orders'] ?? []) as List<Order>;
    String selectedPeriod = 'all';
    
    Map<String, int> getOrdersByPeriod(String period) {
      Map<String, int> periodOrders = {};
      
      for (var order in orders) {
        String key;
        if (period == 'monthly') {
          key = "${order.createdAt.year}-${order.createdAt.month.toString().padLeft(2, '0')}";
        } else if (period == 'yearly') {
          key = "${order.createdAt.year}";
        } else {
          key = order.productName;
        }
        periodOrders[key] = (periodOrders[key] ?? 0) + order.quantity;
      }
      
      return periodOrders;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final orderData = getOrdersByPeriod(selectedPeriod);
          
          return AlertDialog(
            title: const Text("Orders Analytics"),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      "View by:",
                      style: GoogleFonts.urbanist(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(label: Text("Product"), value: 'all'),
                              ButtonSegment(label: Text("Month"), value: 'monthly'),
                              ButtonSegment(label: Text("Year"), value: 'yearly'),
                            ],
                            selected: {selectedPeriod},
                            onSelectionChanged: (value) {
                              setState(() {
                                selectedPeriod = value.first;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (orderData.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text("No orders data available"),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DataTable(
                          columns: [
                            DataColumn(
                              label: Text(selectedPeriod == 'all' ? "Product" : selectedPeriod == 'monthly' ? "Month" : "Year"),
                            ),
                            const DataColumn(label: Text("Qty Sold")),
                            const DataColumn(label: Text("Revenue")),
                          ],
                          rows: orderData.entries.map((e) {
                            double revenue = orders
                                .where((o) {
                                  if (selectedPeriod == 'monthly') {
                                    String key = "${o.createdAt.year}-${o.createdAt.month.toString().padLeft(2, '0')}";
                                    return key == e.key;
                                  } else if (selectedPeriod == 'yearly') {
                                    return "${o.createdAt.year}" == e.key;
                                  } else {
                                    return o.productName == e.key;
                                  }
                                })
                                .fold(0.0, (sum, o) => sum + o.totalPrice);
                            
                            return DataRow(cells: [
                              DataCell(Text(e.key, overflow: TextOverflow.ellipsis)),
                              DataCell(Text("${e.value}")),
                              DataCell(Text("₹${revenue.toStringAsFixed(2)}")),
                            ]);
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
            ],
          );
        },
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
