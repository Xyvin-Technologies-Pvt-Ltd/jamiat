class NewsModel {
  const NewsModel({
    required this.id,
    required this.title,
    required this.description,
    this.subTitle,
    this.image,
    this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final String? subTitle;
  final String? image;
  final DateTime? createdAt;

  factory NewsModel.fromJson(Map<String, dynamic> json) {
    return NewsModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      subTitle: json['sub_title']?.toString(),
      image: json['image']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())?.toLocal()
          : null,
    );
  }
}
