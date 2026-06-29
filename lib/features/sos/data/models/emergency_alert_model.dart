import 'package:cloud_firestore/cloud_firestore.dart' hide GeoPoint;
import '../../../map/domain/entities/geo_point.dart';
import '../../domain/entities/emergency_alert.dart';

class EmergencyAlertModel extends EmergencyAlert {
  const EmergencyAlertModel({
    required super.id,
    required super.senderId,
    required super.senderName,
    required super.location,
    required super.status,
    required super.timestamp,
  });

  factory EmergencyAlertModel.fromMap(String id, Map<String, dynamic> map) {
    final lat = (map['latitude'] as num?)?.toDouble() ?? 0.0;
    final lng = (map['longitude'] as num?)?.toDouble() ?? 0.0;
    
    DateTime parsedTime;
    final dynamic rawTime = map['created_at'];
    if (rawTime is Timestamp) {
      parsedTime = rawTime.toDate();
    } else if (rawTime is String) {
      parsedTime = DateTime.parse(rawTime);
    } else if (rawTime is int) {
      parsedTime = DateTime.fromMillisecondsSinceEpoch(rawTime);
    } else {
      parsedTime = DateTime.now();
    }

    final statusStr = map['status'] as String? ?? 'active';
    final status = EmergencyStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => EmergencyStatus.active,
    );

    return EmergencyAlertModel(
      id: id,
      senderId: map['sender_id'] as String? ?? '',
      senderName: map['sender_name'] as String? ?? '',
      location: GeoPoint(latitude: lat, longitude: lng),
      status: status,
      timestamp: parsedTime,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'sender_id': senderId,
      'sender_name': senderName,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'status': status.name,
      'created_at': Timestamp.fromDate(timestamp.toUtc()),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender_id': senderId,
      'sender_name': senderName,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'status': status.name,
      'created_at': timestamp.millisecondsSinceEpoch,
    };
  }
}
