class EnquiryModel {
  const EnquiryModel({
    required this.id,
    required this.name,
    required this.email,
    required this.message,
    this.phone,
    this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final String message;
  final String? phone;
  final DateTime? createdAt;

  factory EnquiryModel.fromJson(Map<String, dynamic> json) {
    return EnquiryModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString().trim(),
      email: (json['email'] ?? '').toString().trim(),
      phone: () {
        final raw = json['phone']?.toString().trim();
        if (raw == null || raw.isEmpty || raw == 'null') return null;
        return raw;
      }(),
      message: (json['message'] ?? '').toString().trim(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())?.toLocal()
          : null,
    );
  }
}
