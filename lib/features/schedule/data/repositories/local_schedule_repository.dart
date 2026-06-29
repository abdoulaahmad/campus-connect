import 'dart:convert';
import '../../../../core/database/app_database.dart';
import '../../domain/entities/schedule.dart';
import '../../domain/failures/schedule_failure.dart';
import '../../domain/repositories/i_schedule_repository.dart';

class LocalScheduleRepository implements IScheduleRepository {
  final AppDatabase _dbHelper;

  LocalScheduleRepository({required AppDatabase dbHelper}) : _dbHelper = dbHelper;

  @override
  Future<ScheduleResult<Schedule>> getSchedule(String userId) async {
    try {
      final db = await _dbHelper.database;
      final results = await db.query(
        'local_users',
        columns: ['schedule'],
        where: 'id = ?',
        whereArgs: [userId],
      );

      if (results.isEmpty) {
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

      final scheduleStr = results.first['schedule'] as String? ?? '{}';
      final Map<String, dynamic> decoded = jsonDecode(scheduleStr);
      final Map<String, String> masks = decoded.map((key, value) => MapEntry(key, value.toString()));
      
      final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
      for (final day in days) {
        if (!masks.containsKey(day) || !Schedule.isValidBitmask(masks[day]!)) {
          masks[day] = '0' * 48;
        }
      }

      return ScheduleSuccess(Schedule(userId: userId, dailyBitmasks: masks));
    } catch (e) {
      return ScheduleFailed(ScheduleStorageFailure(e.toString()));
    }
  }

  @override
  Future<ScheduleResult<void>> updateSchedule(Schedule schedule) async {
    for (final entry in schedule.dailyBitmasks.entries) {
      if (!Schedule.isValidBitmask(entry.value)) {
        return const ScheduleFailed(InvalidBitmaskFailure());
      }
    }

    try {
      final db = await _dbHelper.database;
      final scheduleJson = jsonEncode(schedule.dailyBitmasks);

      final exist = await db.query(
        'local_users',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [schedule.userId],
      );

      if (exist.isEmpty) {
        await db.insert('local_users', {
          'id': schedule.userId,
          'name': 'Unknown User',
          'email': 'unknown@fud.edu.ng',
          'role': 'student',
          'schedule': scheduleJson,
        });
      } else {
        await db.update(
          'local_users',
          {'schedule': scheduleJson},
          where: 'id = ?',
          whereArgs: [schedule.userId],
        );
      }

      return const ScheduleSuccess(null);
    } catch (e) {
      return ScheduleFailed(ScheduleStorageFailure(e.toString()));
    }
  }
}
