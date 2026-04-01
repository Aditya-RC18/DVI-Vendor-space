class Order {
  final String id;
  final String vendorId;
  final String customerName;
  final String region;
  final String productName;
  final int quantity;
  final double totalPrice;
  final DateTime createdAt;
  final String status;

  Order({
    required this.id,
    required this.vendorId,
    required this.customerName,
    required this.region,
    required this.productName,
    required this.quantity,
    required this.totalPrice,
    required this.createdAt,
    required this.status,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] ?? '',
      vendorId: json['vendor_id'] ?? '',
      customerName: json['customer_name'] ?? '',
      region: json['region'] ?? '',
      productName: json['product_name'] ?? '',
      quantity: json['quantity'] ?? 0,
      totalPrice: (json['total_price'] ?? 0.0).toDouble(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      status: json['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vendor_id': vendorId,
      'customer_name': customerName,
      'region': region,
      'product_name': productName,
      'quantity': quantity,
      'total_price': totalPrice,
      'created_at': createdAt.toIso8601String(),
      'status': status,
    };
  }
}
