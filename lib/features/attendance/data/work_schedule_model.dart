import 'package:flutter/material.dart';

class WorkSchedule {
  /// When false: employee can check-in anytime; no LATE/EARLY_LEAVE/OVERTIME.
  /// When true: shift start/end times apply for validation.
  final bool workHoursEnabled;
  final TimeOfDay shiftStart;
  final TimeOfDay shiftEnd;
  final int toleranceMinutes; // Grace period for late check-in
  final int minWorkingHours; // Minimum hours to not count as early leave
  final Map<String, bool> workDays;

  WorkSchedule({
    this.workHoursEnabled = true,
    required this.shiftStart,
    required this.shiftEnd,
    required this.toleranceMinutes,
    required this.minWorkingHours,
    required this.workDays,
  });

  factory WorkSchedule.fromMap(Map<String, dynamic> data) {
    return WorkSchedule(
      workHoursEnabled: (data['workHoursEnabled'] as bool?) ?? true,
      shiftStart:
          _parseTime(data['shiftStart'] as String?) ??
          const TimeOfDay(hour: 9, minute: 0),
      shiftEnd:
          _parseTime(data['shiftEnd'] as String?) ??
          const TimeOfDay(hour: 17, minute: 0),
      toleranceMinutes: (data['toleranceMinutes'] as num?)?.toInt() ?? 15,
      minWorkingHours: (data['minWorkingHours'] as num?)?.toInt() ?? 8,
      workDays: {
        'monday': (data['monday'] ?? true) as bool,
        'tuesday': (data['tuesday'] ?? true) as bool,
        'wednesday': (data['wednesday'] ?? true) as bool,
        'thursday': (data['thursday'] ?? true) as bool,
        'friday': (data['friday'] ?? true) as bool,
        'saturday': (data['saturday'] ?? false) as bool,
        'sunday': (data['sunday'] ?? false) as bool,
      },
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'workHoursEnabled': workHoursEnabled,
      'shiftStart': '${shiftStart.hour}:${shiftStart.minute}',
      'shiftEnd': '${shiftEnd.hour}:${shiftEnd.minute}',
      'toleranceMinutes': toleranceMinutes,
      'minWorkingHours': minWorkingHours,
      ...workDays,
    };
  }

  static TimeOfDay? _parseTime(String? value) {
    if (value == null || !value.contains(':')) return null;
    final parts = value.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 0,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }
}
