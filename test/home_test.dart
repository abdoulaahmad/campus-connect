import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_connect/features/home/presentation/providers/home_provider.dart';
import 'package:campus_connect/features/admin/domain/repositories/i_admin_repository.dart';
import 'package:campus_connect/features/admin/domain/entities/admin_event.dart';
import 'package:campus_connect/features/admin/domain/entities/admin_announcement.dart';
import 'package:campus_connect/features/admin/domain/failures/admin_failure.dart';
import 'package:campus_connect/core/providers/core_providers.dart';

class MockAdminRepository extends Fake implements IAdminRepository {
  List<AdminEvent> mockEvents = [];
  List<AdminAnnouncement> mockAnnouncements = [];

  @override
  Future<AdminResult<List<AdminEvent>>> getEvents() async {
    return AdminSuccess(mockEvents);
  }

  @override
  Future<AdminResult<List<AdminAnnouncement>>> getAnnouncements() async {
    return AdminSuccess(mockAnnouncements);
  }
}

void main() {
  group('HomeNotifier Tests', () {
    late MockAdminRepository mockAdminRepo;

    setUp(() {
      mockAdminRepo = MockAdminRepository();
    });

    test('Initial state loads announcements and events correctly', () async {
      mockAdminRepo.mockEvents = [
        AdminEvent(
          id: 'e1',
          title: 'FUD Hackathon',
          description: 'A grand hackathon',
          venue: 'Faculty of Science Lab',
          timestamp: DateTime(2026, 6, 15, 10, 0),
        ),
      ];
      mockAdminRepo.mockAnnouncements = [
        AdminAnnouncement(
          id: 'a1',
          title: 'Exam Schedule Out',
          content: 'The exams start next week.',
          timestamp: DateTime(2026, 6, 12, 9, 0),
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          adminRepositoryProvider.overrideWithValue(mockAdminRepo),
        ],
      );
      addTearDown(container.dispose);

      // Verify starting state
      expect(container.read(homeProvider).events, isEmpty);
      expect(container.read(homeProvider).announcements, isEmpty);

      // Trigger the load
      await container.read(homeProvider.notifier).load();

      final state = container.read(homeProvider);
      expect(state.isLoading, isFalse);
      expect(state.events.length, equals(1));
      expect(state.events.first.title, equals('FUD Hackathon'));
      expect(state.announcements.length, equals(1));
      expect(state.announcements.first.title, equals('Exam Schedule Out'));
    });
  });
}
