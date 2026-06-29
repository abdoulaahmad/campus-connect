import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/emergency_alert.dart';
import '../../domain/failures/sos_failure.dart';
import '../../domain/repositories/i_sos_repository.dart';
import '../models/emergency_alert_model.dart';

class FirestoreSosRepository implements ISosRepository {
  final FirebaseFirestore _firestore;

  FirestoreSosRepository({required FirebaseFirestore firestore}) : _firestore = firestore;

  @override
  Stream<SosResult<List<EmergencyAlert>>> streamActiveAlerts() {
    return _firestore
        .collection('emergency_alerts')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map<SosResult<List<EmergencyAlert>>>((snapshot) {
      final alerts = snapshot.docs.map((doc) {
        return EmergencyAlertModel.fromMap(doc.id, doc.data());
      }).toList();
      return SosSuccess(alerts);
    }).handleError((err) {
      return SosFailed(SosUnknownFailure(err.toString()));
    });
  }

  @override
  Future<SosResult<void>> triggerAlert(EmergencyAlert alert) async {
    try {
      final docRef = _firestore.collection('emergency_alerts').doc(alert.id.isNotEmpty ? alert.id : null);
      final model = EmergencyAlertModel(
        id: docRef.id,
        senderId: alert.senderId,
        senderName: alert.senderName,
        location: alert.location,
        status: alert.status,
        timestamp: alert.timestamp,
      );
      await docRef.set(model.toFirestore());
      return const SosSuccess(null);
    } catch (e) {
      return SosFailed(AlertCreationFailed(e.toString()));
    }
  }

  @override
  Future<SosResult<void>> resolveAlert(String alertId) async {
    try {
      await _firestore.collection('emergency_alerts').doc(alertId).update({
        'status': 'resolved',
        'resolved_at': FieldValue.serverTimestamp(),
      });
      return const SosSuccess(null);
    } catch (e) {
      return SosFailed(AlertResolutionFailed(e.toString()));
    }
  }
}
