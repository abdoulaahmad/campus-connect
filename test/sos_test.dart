import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_connect/features/sos/domain/entities/emergency_alert.dart';
import 'package:campus_connect/features/sos/domain/failures/sos_failure.dart';
import 'package:campus_connect/features/sos/presentation/providers/sos_provider.dart';
import 'package:campus_connect/features/sos/data/repositories/mock_sos_repository.dart';
import 'package:campus_connect/features/map/domain/entities/geo_point.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SOS Emergency Tests', () {
    late MockSosRepository sosRepo;
    late SosNotifier sosNotifier;

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers.global'),
        (MethodCall methodCall) async {
          return null;
        },
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers'),
        (MethodCall methodCall) async {
          return null;
        },
      );

      sosRepo = MockSosRepository();
      sosNotifier = SosNotifier(sosRepo);
    });

    tearDown(() {
      sosNotifier.dispose();
      sosRepo.dispose();
    });

    test('Initial state of SosNotifier is default', () {
      expect(sosNotifier.state.remainingSeconds, equals(10));
      expect(sosNotifier.state.isCountingDown, isFalse);
      expect(sosNotifier.state.isTriggered, isFalse);
    });

    test('startCountdown sets countdown status to true', () {
      sosNotifier.startCountdown();
      expect(sosNotifier.state.isCountingDown, isTrue);
      expect(sosNotifier.state.remainingSeconds, equals(10));
    });

    test('cancelCountdown resets state completely', () {
      sosNotifier.startCountdown();
      sosNotifier.cancelCountdown();
      expect(sosNotifier.state.isCountingDown, isFalse);
      expect(sosNotifier.state.remainingSeconds, equals(10));
    });

    test('triggerEmergencyAlert writes alert successfully to repo', () async {
      final loc = const GeoPoint(latitude: 11.7136, longitude: 9.3419);
      final res = await sosNotifier.triggerEmergencyAlert(
        senderId: 'u1',
        senderName: 'Test Student',
        location: loc,
      );

      expect(res, isA<SosSuccess<void>>());

      final streamResult = await sosRepo.streamActiveAlerts().first;
      expect(streamResult, isA<SosSuccess<List<EmergencyAlert>>>());
      
      final list = (streamResult as SosSuccess<List<EmergencyAlert>>).value;
      expect(list.length, equals(1));
      expect(list.first.senderName, equals('Test Student'));
      expect(list.first.location.latitude, equals(11.7136));
    });
  });
}
