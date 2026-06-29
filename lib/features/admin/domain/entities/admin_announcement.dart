class AdminAnnouncement {
  final String id;
  final String title;
  final String content;
  final DateTime timestamp;

  const AdminAnnouncement({
    required this.id,
    required this.title,
    required this.content,
    required this.timestamp,
  });

  AdminAnnouncement copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? timestamp,
  }) {
    return AdminAnnouncement(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
