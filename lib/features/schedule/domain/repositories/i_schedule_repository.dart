import '../entities/schedule.dart';
import '../failures/schedule_failure.dart';

abstract class IScheduleRepository {
  Future<ScheduleResult<Schedule>> getSchedule(String userId);
  Future<ScheduleResult<void>> updateSchedule(Schedule schedule);
}
