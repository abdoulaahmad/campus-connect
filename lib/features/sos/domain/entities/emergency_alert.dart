import '../../../map/domain/entities/geo_point.dart';

enum EmergencyStatus {
  active,
  resolved,
}

class EmergencyAlert {
  final String id;
  final String senderId;
  final String senderName;
  final GeoPoint location;
  final EmergencyStatus status;
  final DateTime timestamp;

  const EmergencyAlert({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.location,
    required this.status,
    required this.timestamp,
  });

  EmergencyAlert copyWith({
    String? id,
    String? senderId,
    String? senderName,
    GeoPoint? location,
    EmergencyStatus? status,
    DateTime? timestamp,
  }) {
    return EmergencyAlert(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      location: location ?? this.location,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
