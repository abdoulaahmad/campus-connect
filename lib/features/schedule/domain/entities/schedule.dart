class Schedule {
  final String userId;
  final Map<String, String> dailyBitmasks; // e.g. 'monday' -> '11110000...' (48 chars)

  const Schedule({
    required this.userId,
    required this.dailyBitmasks,
  });

  /// Enforces that bitmask strings are exactly 48 characters of only '0' or '1'
  static bool isValidBitmask(String value) {
    if (value.length != 48) return false;
    final regex = RegExp(r'^[01]+$');
    return regex.hasMatch(value);
  }

  /// Computes the bitwise AND of multiple weekly schedules
  static Map<String, String> intersectSchedules(List<Schedule> schedules) {
    if (schedules.isEmpty) return {};
    
    final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    final Map<String, String> intersection = {};

    for (final day in days) {
      String dayBitmask = schedules.first.dailyBitmasks[day] ?? '0' * 48;
      if (!isValidBitmask(dayBitmask)) {
        dayBitmask = '0' * 48;
      }
      for (int i = 1; i < schedules.length; i++) {
        final nextBitmask = schedules[i].dailyBitmasks[day] ?? '0' * 48;
        final validNext = isValidBitmask(nextBitmask) ? nextBitmask : '0' * 48;
        dayBitmask = _bitwiseAnd(dayBitmask, validNext);
      }
      intersection[day] = dayBitmask;
    }
    return intersection;
  }

  static String _bitwiseAnd(String a, String b) {
    final length = a.length;
    final sb = StringBuffer();
    for (int i = 0; i < length; i++) {
      sb.write((a[i] == '1' && b[i] == '1') ? '1' : '0');
    }
    return sb.toString();
  }
}
