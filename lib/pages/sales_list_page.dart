import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order.dart';

class SalesListPage extends StatefulWidget {
  final Map<String, dynamic>? metrics;
  const SalesListPage({super.key, this.metrics});

  @override
  State<SalesListPage> createState() => _SalesListPageState();
}

class _SalesListPageState extends State<SalesListPage> {
  final _supabase = Supabase.instance.client;
  List<Order> _allOrders = [];
  final Set<String> _dismissedOrderIds = {};
  bool _isLoading = true;
  Map<String, dynamic> _currentMetrics = {};

  @override
  void initState() {
    super.initState();
    _currentMetrics = widget.metrics ?? {};
    _fetchSalesData();
  }

  Future<void> _fetchSalesData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final ordersData = await _supabase
          .from('orders')
          .select()
          .eq('vendor_id', user.id)
          .order('created_at', ascending: false);

      final orders = (ordersData as List).map((o) => Order.fromJson(o)).toList();
      
      // Re-calculate metrics to ensure they are fresh
      int totalSales = orders.fold(0, (sum, o) => sum + o.quantity);
      double totalRevenue = orders.fold(0.0, (sum, o) => sum + o.totalPrice);
      int pendingOrders = orders.where((o) => o.status == 'pending').length;

      if (mounted) {
        setState(() {
          _allOrders = orders;
          _currentMetrics = {
            ..._currentMetrics,
            'totalSales': totalSales,
            'totalOrders': orders.length,
            'totalRevenue': totalRevenue,
            'pendingOrders': pendingOrders,
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching sales data: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _dismissNotification(String orderId) {
    setState(() {
      _dismissedOrderIds.add(orderId);
    });
  }

  void _showTotalSalesAnalytics() {
    Map<String, int> regionWiseSales = {};
    Map<String, int> productWiseSales = {};
    
    for (var order in _allOrders) {
      regionWiseSales[order.region] = (regionWiseSales[order.region] ?? 0) + order.quantity;
      productWiseSales[order.productName] = (productWiseSales[order.productName] ?? 0) + order.quantity;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sales Analytics',
                style: GoogleFonts.urbanist(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(height: 32),
              Text(
                'By Region',
                style: GoogleFonts.urbanist(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blueGrey,
                ),
              ),
              const SizedBox(height: 12),
              ...regionWiseSales.entries.map((e) => _buildAnalyticsRow(
                e.key, 
                '${e.value} items', 
                Colors.blue.shade700
              )),
              const SizedBox(height: 24),
              Text(
                'By Product',
                style: GoogleFonts.urbanist(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blueGrey,
                ),
              ),
              const SizedBox(height: 12),
              ...productWiseSales.entries.map((e) => _buildAnalyticsRow(
                e.key, 
                '${e.value} items', 
                Colors.orange.shade700
              )),
            ],
          ),
        ),
      ),
    );
  }

  void _showTotalOrdersAnalytics() {
    String selectedPeriod = 'monthly';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          Map<String, int> periodOrders = {};
          for (var order in _allOrders) {
            String key;
            if (selectedPeriod == 'monthly') {
              key = "${order.createdAt.year}-${order.createdAt.month.toString().padLeft(2, '0')}";
            } else {
              key = "${order.createdAt.year}";
            }
            periodOrders[key] = (periodOrders[key] ?? 0) + order.quantity;
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            minChildSize: 0.4,
            expand: false,
            builder: (context, scrollController) => SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Orders Analytics',
                        style: GoogleFonts.urbanist(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(label: Text("Monthly"), value: 'monthly'),
                          ButtonSegment(label: Text("Yearly"), value: 'yearly'),
                        ],
                        selected: {selectedPeriod},
                        onSelectionChanged: (value) {
                          setModalState(() => selectedPeriod = value.first);
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  if (periodOrders.isEmpty)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text("No orders data available"),
                    ))
                  else
                    ...periodOrders.entries.map((e) => _buildAnalyticsRow(
                      e.key, 
                      '${e.value} items sold', 
                      Colors.purple.shade700
                    )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnalyticsRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          Text(
            value,
            style: GoogleFonts.urbanist(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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
    return Expanded(
      child: InkWell(
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
              if (onTap != null) ...[
                const SizedBox(height: 8),
                Text(
                  "Tap for details →",
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(backgroundColor: const Color(0xff0c1c2c)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final visibleOrders = _allOrders.where((o) => !_dismissedOrderIds.contains(o.id)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Sales Info',
          style: GoogleFonts.urbanist(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xff0c1c2c),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchSalesData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // STAT CARDS
              Row(
                children: [
                  _buildStatCard(
                    onTap: _showTotalSalesAnalytics,
                    title: "Total Sales",
                    accentColor: Colors.blue.shade700,
                    icon: Icons.payments_outlined,
                    items: [
                      _statRow("Qty Sold", "${_currentMetrics['totalSales'] ?? 0}"),
                      _statRow("Revenue", "₹${_currentMetrics['totalRevenue']?.toStringAsFixed(2) ?? '0.00'}", isAlert: false),
                    ],
                  ),
                  const SizedBox(width: 16),
                  _buildStatCard(
                    onTap: _showTotalOrdersAnalytics,
                    title: "Total Orders",
                    accentColor: Colors.purple.shade700,
                    icon: Icons.shopping_bag_outlined,
                    items: [
                      _statRow("Orders", "${_currentMetrics['totalOrders'] ?? 0}"),
                      _statRow(
                        "Pending", 
                        "${_currentMetrics['pendingOrders'] ?? 0}",
                        isAlert: (_currentMetrics['pendingOrders'] ?? 0) > 0,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // LOW STOCK SECTION
              Text(
                "Inventory Alerts",
                style: GoogleFonts.urbanist(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xff0c1c2c),
                ),
              ),
              const SizedBox(height: 12),
              Container(
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_currentMetrics['lowStockAlerts'] ?? 0} items low in stock',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Manage your inventory',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff0c1c2c),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('View All', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // NOTIFICATIONS SECTION
              Text(
                "Recent Orders (${visibleOrders.length})",
                style: GoogleFonts.urbanist(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xff0c1c2c),
                ),
              ),
              const SizedBox(height: 12),
              if (visibleOrders.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      "All notifications cleared",
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: visibleOrders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final order = visibleOrders[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border(
                          left: BorderSide(color: Colors.blue.shade400, width: 4),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Text(
                          '${order.customerName} ordered',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              'Product: ${order.productName} (Qty: ${order.quantity})',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            Text(
                              'From: ${order.region}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => _dismissNotification(order.id),
                          tooltip: 'Dismiss',
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
