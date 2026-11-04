class UserModel {
  const UserModel({
    required this.id,
    required this.phone,
    required this.status,
    required this.role,
    required this.isProfileComplete,
    this.name,
    this.email,
    this.image,
    this.gender,
    this.whatsappNo,
    this.address,
    this.area,
    this.district,
    this.state,
    this.country,
    this.pincode,
    this.dob,
    this.qrCode,
  });

  final String id;
  final String phone;
  final String status;
  final String role;
  final bool isProfileComplete;
  final String? name;
  final String? email;
  final String? image;
  final String? gender;
  final String? whatsappNo;
  final String? address;
  final String? area;
  final String? district;
  final String? state;
  final String? country;
  final int? pincode;
  final DateTime? dob;
  final String? qrCode;

  bool get canEnterApp => status == 'active' && isProfileComplete;

  bool get isJamiatMember => role == 'jamiat_member';

  String get displayName =>
      (name != null && name!.trim().isNotEmpty) ? name!.trim() : 'Member';

  String get displayMemberId {
    final compact = id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    if (compact.length >= 6) {
      return 'JM${compact.substring(compact.length - 7).toUpperCase()}';
    }
    return id;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      status: (json['status'] ?? 'inactive').toString(),
      role: (json['role'] ?? 'normal_member').toString(),
      isProfileComplete: json['is_profile_complete'] == true,
      name: json['name']?.toString(),
      email: json['email']?.toString(),
      image: () {
        var raw = json['image']?.toString().trim();
        if (raw == null || raw.isEmpty || raw == 'null') return null;
        // Strip accidental surrounding quotes from some API payloads.
        if ((raw.startsWith('"') && raw.endsWith('"')) ||
            (raw.startsWith("'") && raw.endsWith("'"))) {
          raw = raw.substring(1, raw.length - 1).trim();
        }
        if (raw.startsWith('//')) raw = 'https:$raw';
        if (raw.isEmpty || raw == 'null') return null;
        return raw;
      }(),
      gender: json['gender']?.toString(),
      whatsappNo: json['whatsapp_no']?.toString(),
      address: json['address']?.toString(),
      area: json['area']?.toString(),
      district: json['district']?.toString(),
      state: json['state']?.toString(),
      country: json['country']?.toString(),
      pincode: (json['pincode'] as num?)?.toInt(),
      dob: json['dob'] != null
          ? DateTime.tryParse(json['dob'].toString())?.toLocal()
          : null,
      qrCode: json['qr_code']?.toString(),
    );
  }
}
