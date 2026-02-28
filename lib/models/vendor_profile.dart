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
  final bool businessSubmitted;
  final String? businessName;
  final String? dateOfBirth;
  final List<String> businessContacts;
  final String role;
  // Banking / business details
  final String? accountHolderName;
  final String? accountNumber;
  final String? ifscCode;
  final String? idNumber;
  final String? bankProofUrl;
  final String? businessProofUrl;

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
    this.businessSubmitted = false,
    this.businessName,
    this.dateOfBirth,
    this.businessContacts = const [],
    this.role = 'venue_distributor',
    this.accountHolderName,
    this.accountNumber,
    this.ifscCode,
    this.idNumber,
    this.bankProofUrl,
    this.businessProofUrl,
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
      businessSubmitted: json['business_submitted'] as bool? ?? false,
      businessName: json['business_name'],
      dateOfBirth: json['date_of_birth'],
      businessContacts:
          (json['business_contacts'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      role: json['role'] ?? 'venue_distributor',
      accountHolderName: json['account_holder_name'],
      accountNumber: json['account_number'],
      ifscCode: json['ifsc_code'],
      idNumber: json['id_number'],
      bankProofUrl: json['bank_proof_url'],
      businessProofUrl: json['business_proof_url'],
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
      'business_submitted': businessSubmitted,
      'business_name': businessName,
      'date_of_birth': dateOfBirth,
      'business_contacts': businessContacts,
      'role': role,
      'account_holder_name': accountHolderName,
      'account_number': accountNumber,
      'ifsc_code': ifscCode,
      'id_number': idNumber,
      'bank_proof_url': bankProofUrl,
      'business_proof_url': businessProofUrl,
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
    bool? businessSubmitted,
    String? businessName,
    String? dateOfBirth,
    List<String>? businessContacts,
    String? role,
    String? accountHolderName,
    String? accountNumber,
    String? ifscCode,
    String? idNumber,
    String? bankProofUrl,
    String? businessProofUrl,
    required profileImageUrl,
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
      businessSubmitted: businessSubmitted ?? this.businessSubmitted,
      businessName: businessName ?? this.businessName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      businessContacts: businessContacts ?? this.businessContacts,
      role: role ?? this.role,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      accountNumber: accountNumber ?? this.accountNumber,
      ifscCode: ifscCode ?? this.ifscCode,
      idNumber: idNumber ?? this.idNumber,
      bankProofUrl: bankProofUrl ?? this.bankProofUrl,
      businessProofUrl: businessProofUrl ?? this.businessProofUrl,
    );
  }

  // Role-based permission helpers
  bool get isAdmin => role == 'admin';
  bool get canManageVenues =>
      role == 'venue_distributor' || role == 'venue_vendor_distributor';
  bool get canManageVendorServices =>
      role == 'vendor_distributor' || role == 'venue_vendor_distributor';

  get profileImageUrl => null;
}
