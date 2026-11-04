class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.subject,
    required this.content,
    required this.isRead,
    this.image,
    this.link,
    this.createdAt,
  });

  final String id;
  final String subject;
  final String content;
  final bool isRead;
  final String? image;
  final String? link;
  final DateTime? createdAt;

  factory NotificationModel.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    return NotificationModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      subject: (json['subject'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      isRead: _parseIsRead(json, currentUserId: currentUserId),
      image: json['image']?.toString(),
      link: json['link']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())?.toLocal()
          : null,
    );
  }

  /// Backend stores per-user read flags under `users[].read`, and may also
  /// expose a projected top-level `is_read` / `read`.
  static bool _parseIsRead(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    if (json['read'] == true || json['is_read'] == true) return true;
    if (json['read'] == false || json['is_read'] == false) {
      // Explicit top-level false wins over nested lookup only when present.
      if (json.containsKey('is_read') || json.containsKey('read')) {
        return false;
      }
    }

    final users = json['users'];
    if (users is! List || currentUserId == null || currentUserId.isEmpty) {
      return false;
    }

    for (final entry in users) {
      if (entry is! Map) continue;
      final rawUser = entry['user'];
      final userId = rawUser is Map
          ? (rawUser['_id'] ?? rawUser['id'])?.toString()
          : rawUser?.toString();
      if (userId == currentUserId) {
        return entry['read'] == true;
      }
    }
    return false;
  }
}
