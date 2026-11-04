class EmpowermentProgramModel {
  const EmpowermentProgramModel({
    required this.id,
    required this.title,
    required this.description,
    required this.isBookmarked,
    required this.isApplied,
    this.image,
    this.startDate,
  });

  final String id;
  final String title;
  final String description;
  final bool isBookmarked;
  final bool isApplied;
  final String? image;
  final DateTime? startDate;

  factory EmpowermentProgramModel.fromJson(Map<String, dynamic> json) {
    return EmpowermentProgramModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      isBookmarked: json['is_bookmarked'] == true,
      isApplied: _parseIsApplied(json),
      image: json['image']?.toString(),
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'].toString())?.toLocal()
          : null,
    );
  }

  static bool _parseIsApplied(Map<String, dynamic> json) {
    if (json['is_applied'] == true) return true;
    if (json['applied'] == true) return true;
    if (json['has_applied'] == true) return true;
    final status = json['application_status']?.toString().toLowerCase();
    return status == 'applied';
  }

  EmpowermentProgramModel copyWith({
    String? id,
    String? title,
    String? description,
    bool? isBookmarked,
    bool? isApplied,
    String? image,
    DateTime? startDate,
  }) {
    return EmpowermentProgramModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      isApplied: isApplied ?? this.isApplied,
      image: image ?? this.image,
      startDate: startDate ?? this.startDate,
    );
  }
}
