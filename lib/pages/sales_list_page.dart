import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SalesListPage extends StatefulWidget {
  final Map<String, dynamic>? metrics;
  const SalesListPage({super.key, this.metrics});

  @override
  State<SalesListPage> createState() => _SalesListPageState();
}

class _SalesListPageState extends State<SalesListPage> {
  late List<Map<String, dynamic>> recentOrders;

  @override
  void initState() {
    super.initState();
    // Initialize recent orders with dismissible state
    recentOrders = [
      {'id': 1001, 'customer': 'John Doe', 'region': 'North', 'product': 'Laptop', 'dismissed': false},
      {'id': 1002, 'customer': 'Jane Smith', 'region': 'South', 'product': 'Mouse Pad', 'dismissed': false},
      {'id': 1003, 'customer': 'Bob Wilson', 'region': 'East', 'product': 'Keyboard', 'dismissed': false},
      {'id': 1004, 'customer': 'Alice Brown', 'region': 'West', 'product': 'Monitor', 'dismissed': false},
      {'id': 1005, 'customer': 'Charlie Davis', 'region': 'North', 'product': 'Headphones', 'dismissed': false},
      {'id': 1006, 'customer': 'Emma Wilson', 'region': 'South', 'product': 'USB Cable', 'dismissed': false},
    ];
  }

  void _dismissNotification(int index) {
    setState(() {
      recentOrders[index]['dismissed'] = true;
    });
  }

  void _showTotalSalesAnalytics() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sales Analytics',
              style: GoogleFonts.urbanist(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'By Region',
              style: GoogleFonts.urbanist(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            _buildAnalyticsRow('North', '₹45,000', Colors.blue),
            _buildAnalyticsRow('South', '₹38,000', Colors.green),
            _buildAnalyticsRow('East', '₹52,000', Colors.orange),
            _buildAnalyticsRow('West', '₹35,000', Colors.purple),
            const SizedBox(height: 20),
            Text(
              'By Product',
              style: GoogleFonts.urbanist(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            _buildAnalyticsRow('Laptops', '₹120,000', Colors.red),
            _buildAnalyticsRow('Peripherals', '₹25,000', Colors.teal),
            _buildAnalyticsRow('Cables & Accessories', '₹25,000', Colors.indigo),
          ],
        ),
      ),
    );
  }

  void _showTotalOrdersAnalytics() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Orders Analytics',
              style: GoogleFonts.urbanist(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'By Month (2024)',
              style: GoogleFonts.urbanist(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            _buildAnalyticsRow('January', '45 orders', Colors.blue),
            _buildAnalyticsRow('February', '52 orders', Colors.green),
            _buildAnalyticsRow('March', '48 orders', Colors.orange),
            _buildAnalyticsRow('April', '61 orders', Colors.purple),
            const SizedBox(height: 20),
            Text(
              'Product Sales Count',
              style: GoogleFonts.urbanist(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            _buildAnalyticsRow('Laptops', '28 sold', Colors.red),
            _buildAnalyticsRow('Mice', '15 sold', Colors.teal),
            _buildAnalyticsRow('Keyboards', '12 sold', Colors.indigo),
            _buildAnalyticsRow('Monitors', '8 sold', Colors.cyan),
          ],
        ),
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
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget statChip(String label, String value, {Color? color, VoidCallback? onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: GoogleFonts.urbanist(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color ?? const Color(0xff0c1c2c),
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Tap for details →',
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

  @override
  Widget build(BuildContext context) {
    final data = widget.metrics ?? {};
    final visibleOrders = recentOrders.where((o) => !o['dismissed']).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Sales',
          style: GoogleFonts.urbanist(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xff0c1c2c),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                statChip(
                  'Total Sales',
                  '${data['totalSales'] ?? 0}',
                  onTap: _showTotalSalesAnalytics,
                ),
                const SizedBox(width: 12),
                statChip(
                  'Total Orders',
                  '${data['totalOrders'] ?? 0}',
                  onTap: _showTotalOrdersAnalytics,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                statChip(
                  'Revenue',
                  '₹${data['totalRevenue'] ?? 0.0}',
                  color: Colors.green.shade700,
                ),
                const SizedBox(width: 12),
                statChip(
                  'Pending Orders',
                  '${data['pendingOrders'] ?? 0}',
                  color: (data['pendingOrders'] ?? 0) > 0 ? Colors.red : null,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Low Stock Alerts',
              style: GoogleFonts.urbanist(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${data['lowStockAlerts'] ?? 0} items low in stock',
                    style: const TextStyle(fontSize: 14),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff0c1c2c),
                    ),
                    child: const Text('View Products'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Recent Orders (${visibleOrders.length})',
              style: GoogleFonts.urbanist(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: visibleOrders.isEmpty
                  ? Center(
                      child: Text(
                        'All notifications dismissed',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    )
                  : ListView.separated(
                      itemCount: visibleOrders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final order = visibleOrders[index];
                        final originalIndex = recentOrders.indexOf(order);
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border(
                              left: BorderSide(
                                color: Colors.blue.shade400,
                                width: 4,
                              ),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${order['customer']} ordered',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Product: ${order['product']}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Text(
                                        'Region: ${order['region']}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  iconSize: 20,
                                  onPressed: () => _dismissNotification(originalIndex),
                                  tooltip: 'Dismiss',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
