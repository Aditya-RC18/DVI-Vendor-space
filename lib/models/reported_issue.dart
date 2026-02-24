class ReportedIssue {
  final String? id;
  final String reporterId;
  final String title;
  final String description;
  final String status; // pending, in_progress, resolved, rejected
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Related data (loaded separately)
  String? reporterName;
  String? reporterEmail;

  ReportedIssue({
    this.id,
    required this.reporterId,
    required this.title,
    required this.description,
    this.status = 'pending',
    this.createdAt,
    this.updatedAt,
    this.reporterName,
    this.reporterEmail,
  });

  factory ReportedIssue.fromJson(Map<String, dynamic> json) {
    return ReportedIssue(
      id: json['id'],
      reporterId: json['reporter_id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      reporterName: json['reporter_name'],
      reporterEmail: json['reporter_email'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'reporter_id': reporterId,
      'title': title,
      'description': description,
      'status': status,
    };
  }

  /// Get status display text with color
  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Unknown';
    }
  }

  /// Create a copy with updated fields
  ReportedIssue copyWith({
    String? id,
    String? reporterId,
    String? title,
    String? description,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? reporterName,
    String? reporterEmail,
  }) {
    return ReportedIssue(
      id: id ?? this.id,
      reporterId: reporterId ?? this.reporterId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reporterName: reporterName ?? this.reporterName,
      reporterEmail: reporterEmail ?? this.reporterEmail,
    );
  }
}
