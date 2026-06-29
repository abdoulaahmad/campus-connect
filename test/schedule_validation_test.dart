import 'package:flutter_test/flutter_test.dart';
import 'package:campus_connect/features/schedule/domain/entities/schedule.dart';

void main() {
  group('Schedule Bitmask Validation Tests', () {
    test('isValidBitmask rejects strings of length != 48', () {
      expect(Schedule.isValidBitmask('1'), isFalse);
      expect(Schedule.isValidBitmask('10101010101010101010101010101010101010101010101'), isFalse); // 47
      expect(Schedule.isValidBitmask('1010101010101010101010101010101010101010101010101'), isFalse); // 49
    });

    test('isValidBitmask rejects non-binary digits', () {
      expect(Schedule.isValidBitmask('a' * 48), isFalse);
      expect(Schedule.isValidBitmask('1' * 47 + '2'), isFalse);
      expect(Schedule.isValidBitmask('0' * 47 + ' '), isFalse);
    });

    test('isValidBitmask accepts exactly 48 binary digits', () {
      expect(Schedule.isValidBitmask('0' * 48), isTrue);
      expect(Schedule.isValidBitmask('1' * 48), isTrue);
      expect(Schedule.isValidBitmask('10101010' * 6), isTrue);
    });

    test('intersectSchedules calculates bitwise AND correctly', () {
      final s1 = Schedule(
        userId: 'u1',
        dailyBitmasks: {
          'monday': '1' * 48,
          'tuesday': '1010' * 12,
        },
      );
      final s2 = Schedule(
        userId: 'u2',
        dailyBitmasks: {
          'monday': '0' * 48,
          'tuesday': '0101' * 12,
        },
      );

      final intersection = Schedule.intersectSchedules([s1, s2]);
      
      expect(intersection['monday'], equals('0' * 48));
      expect(intersection['tuesday'], equals('0' * 48));

      final s3 = Schedule(
        userId: 'u3',
        dailyBitmasks: {
          'monday': '1' * 48,
          'tuesday': '1111' * 12,
        },
      );
      final intersection2 = Schedule.intersectSchedules([s1, s3]);
      expect(intersection2['monday'], equals('1' * 48));
      expect(intersection2['tuesday'], equals('1010' * 12));
    });
  });
}
