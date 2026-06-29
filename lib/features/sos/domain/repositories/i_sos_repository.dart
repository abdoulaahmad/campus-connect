import '../entities/emergency_alert.dart';
import '../failures/sos_failure.dart';

abstract class ISosRepository {
  Stream<SosResult<List<EmergencyAlert>>> streamActiveAlerts();
  Future<SosResult<void>> triggerAlert(EmergencyAlert alert);
  Future<SosResult<void>> resolveAlert(String alertId);
}
