import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Order> _activeOrders = [];
  List<Order> _historyOrders = [];

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final response = await _supabase
          .from('orders')
          .select()
          .eq('vendor_id', user.id)
          .order('created_at', ascending: false);

      final allOrders = (response as List).map((o) => Order.fromJson(o)).toList();

      if (mounted) {
        setState(() {
          // Active: accepted, pending, shipped
          _activeOrders = allOrders.where((o) => 
            ['accepted', 'pending', 'shipped'].contains(o.status.toLowerCase())
          ).toList();
          
          // History: completed, rejected
          _historyOrders = allOrders.where((o) => 
            ['completed', 'rejected'].contains(o.status.toLowerCase())
          ).toList();
          
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching orders: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await _supabase
          .from('orders')
          .update({'status': newStatus})
          .eq('id', orderId);
      
      _fetchOrders(); // Refresh list
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Order status updated to $newStatus")),
        );
      }
    } catch (e) {
      debugPrint("Error updating status: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            "Manage Orders",
            style: GoogleFonts.urbanist(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xff0c1c2c),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: [
              Tab(text: "Active Orders"),
              Tab(text: "Order History"),
            ],
          ),
        ),
        body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              children: [
                _buildOrderList(_activeOrders, isActive: true),
                _buildOrderList(_historyOrders, isActive: false),
              ],
            ),
      ),
    );
  }

  Widget _buildOrderList(List<Order> orders, {required bool isActive}) {
    if (orders.isEmpty) {
      return Center(
        child: Text(
          isActive ? "No active orders found" : "No history found",
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        order.customerName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      _buildStatusBadge(order.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text("Product: ${order.productName}", style: TextStyle(color: Colors.grey.shade700)),
                  Text("Qty: ${order.quantity} | Total: ₹${order.totalPrice.toStringAsFixed(2)}"),
                  Text("Region: ${order.region}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const Divider(height: 24),
                  if (isActive) 
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Update Status:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Wrap(
                          spacing: 8,
                          children: [
                            _actionButton("Pending", 'pending', order.id),
                            _actionButton("Shipped", 'shipped', order.id),
                            _actionButton("Complete", 'completed', order.id, color: Colors.green),
                          ],
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

  Widget _actionButton(String label, String status, String orderId, {Color? color}) {
    return InkWell(
      onTap: () => _updateOrderStatus(orderId, status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: (color ?? Colors.blue).withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: (color ?? Colors.blue).withOpacity(0.5)),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color ?? Colors.blue.shade700),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'completed': color = Colors.green; break;
      case 'shipped': color = Colors.blue; break;
      case 'rejected': color = Colors.red; break;
      case 'accepted': color = Colors.teal; break;
      default: color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
