class AdminEvent {
  final String id;
  final String title;
  final String description;
  final String venue;
  final DateTime timestamp;

  const AdminEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.venue,
    required this.timestamp,
  });

  AdminEvent copyWith({
    String? id,
    String? title,
    String? description,
    String? venue,
    DateTime? timestamp,
  }) {
    return AdminEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      venue: venue ?? this.venue,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
