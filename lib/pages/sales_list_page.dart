import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SalesListPage extends StatelessWidget {
  final Map<String, dynamic>? metrics;
  const SalesListPage({super.key, this.metrics});

  @override
  Widget build(BuildContext context) {
    final data = metrics ?? {};

    Widget statChip(String label, String value, {Color? color}) {
      return Expanded(
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
            ],
          ),
        ),
      );
    }

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
                statChip('Total Sales', '${data['totalSales'] ?? 0}'),
                const SizedBox(width: 12),
                statChip('Total Orders', '${data['totalOrders'] ?? 0}'),
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
              'Recent Orders',
              style: GoogleFonts.urbanist(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: 6,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  return ListTile(
                    tileColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    title: Text('Order #${1000 + index}'),
                    subtitle: Text('Status: Pending'),
                    trailing: Text(
                      '₹0.00',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onTap: () {},
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
