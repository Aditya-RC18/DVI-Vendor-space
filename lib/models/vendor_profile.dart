class VendorProfile {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final String? identificationUrl;
  final String verificationStatus;
  final String? rejectionReason;
  final String
  role; // admin, venue_distributor, vendor_distributor, venue_vendor_distributor

  VendorProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.address,
    required this.city,
    required this.state,
    required this.pincode,
    this.identificationUrl,
    this.verificationStatus = 'pending',
    this.rejectionReason,
    this.role = 'venue_distributor', // Default role
  });

  factory VendorProfile.fromJson(Map<String, dynamic> json) {
    return VendorProfile(
      id: json['id'],
      fullName: json['full_name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      pincode: json['pincode'] ?? '',
      identificationUrl: json['identification_url'],
      verificationStatus: json['verification_status'] ?? 'pending',
      rejectionReason: json['rejection_reason'],
      role: json['role'] ?? 'venue_distributor',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'address': address,
      'city': city,
      'state': state,
      'pincode': pincode,
      'identification_url': identificationUrl,
      'verification_status': verificationStatus,
      'rejection_reason': rejectionReason,
      'role': role,
    };
  }

  VendorProfile copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? identificationUrl,
    String? verificationStatus,
    String? rejectionReason,
    String? role,
  }) {
    return VendorProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      identificationUrl: identificationUrl ?? this.identificationUrl,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      role: role ?? this.role,
    );
  }

  // Role-based permission helpers
  bool get isAdmin => role == 'admin';
  bool get canManageVenues =>
      role == 'venue_distributor' || role == 'venue_vendor_distributor';
  bool get canManageVendorServices =>
      role == 'vendor_distributor' || role == 'venue_vendor_distributor';
}
