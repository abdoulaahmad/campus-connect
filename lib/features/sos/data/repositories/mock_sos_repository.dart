import 'dart:async';
import '../../domain/entities/emergency_alert.dart';
import '../../domain/failures/sos_failure.dart';
import '../../domain/repositories/i_sos_repository.dart';

class MockSosRepository implements ISosRepository {
  final List<EmergencyAlert> _alerts = [];
  final StreamController<SosResult<List<EmergencyAlert>>> _controller = 
      StreamController<SosResult<List<EmergencyAlert>>>.broadcast();

  MockSosRepository() {
    _controller.add(SosSuccess(List.unmodifiable(_alerts)));
  }

  @override
  Stream<SosResult<List<EmergencyAlert>>> streamActiveAlerts() {
    // Return stream immediately initialized with current state
    final controller = StreamController<SosResult<List<EmergencyAlert>>>();
    controller.add(SosSuccess(List.unmodifiable(_alerts.where((a) => a.status == EmergencyStatus.active))));
    
    final subscription = _controller.stream.listen(
      (event) => controller.add(event),
      onError: (err) => controller.addError(err),
      onDone: () => controller.close(),
    );
    
    controller.onCancel = () {
      subscription.cancel();
      controller.close();
    };
    
    return controller.stream;
  }

  @override
  Future<SosResult<void>> triggerAlert(EmergencyAlert alert) async {
    _alerts.removeWhere((a) => a.id == alert.id);
    _alerts.add(alert);
    _controller.add(SosSuccess(List.unmodifiable(_alerts.where((a) => a.status == EmergencyStatus.active))));
    return const SosSuccess(null);
  }

  @override
  Future<SosResult<void>> resolveAlert(String alertId) async {
    final idx = _alerts.indexWhere((a) => a.id == alertId);
    if (idx != -1) {
      _alerts[idx] = _alerts[idx].copyWith(status: EmergencyStatus.resolved);
      _controller.add(SosSuccess(List.unmodifiable(_alerts.where((a) => a.status == EmergencyStatus.active))));
      return const SosSuccess(null);
    }
    return const SosFailed(AlertResolutionFailed('Alert not found'));
  }

  void dispose() {
    _controller.close();
  }
}
