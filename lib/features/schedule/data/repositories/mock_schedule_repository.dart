import '../../domain/entities/schedule.dart';
import '../../domain/failures/schedule_failure.dart';
import '../../domain/repositories/i_schedule_repository.dart';

class MockScheduleRepository implements IScheduleRepository {
  final Map<String, Schedule> _schedules = {};

  @override
  Future<ScheduleResult<Schedule>> getSchedule(String userId) async {
    if (_schedules.containsKey(userId)) {
      return ScheduleSuccess(_schedules[userId]!);
    }
    final defaultMasks = {
      'monday': '0' * 48,
      'tuesday': '0' * 48,
      'wednesday': '0' * 48,
      'thursday': '0' * 48,
      'friday': '0' * 48,
      'saturday': '0' * 48,
      'sunday': '0' * 48,
    };
    return ScheduleSuccess(Schedule(userId: userId, dailyBitmasks: defaultMasks));
  }

  @override
  Future<ScheduleResult<void>> updateSchedule(Schedule schedule) async {
    for (final entry in schedule.dailyBitmasks.entries) {
      if (!Schedule.isValidBitmask(entry.value)) {
        return const ScheduleFailed(InvalidBitmaskFailure());
      }
    }
    _schedules[schedule.userId] = schedule;
    return const ScheduleSuccess(null);
  }
}
