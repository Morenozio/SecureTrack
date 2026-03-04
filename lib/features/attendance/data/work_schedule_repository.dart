import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/material.dart';
import '../../../core/firebase/firebase_providers.dart';
import 'work_schedule_model.dart';

class WorkScheduleRepository {
  WorkScheduleRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _schedules =>
      _db.collection('workSchedules');

  Future<WorkSchedule> getEmployeeSchedule(String userId) async {
    final doc = await _schedules.doc(userId).get();
    if (!doc.exists || doc.data() == null) {
      // Return default schedule if none exists
      return WorkSchedule(
        shiftStart: const TimeOfDay(hour: 9, minute: 0),
        shiftEnd: const TimeOfDay(hour: 17, minute: 0),
        toleranceMinutes: 15,
        minWorkingHours: 8,
        workDays: {
          'monday': true,
          'tuesday': true,
          'wednesday': true,
          'thursday': true,
          'friday': true,
          'saturday': false,
          'sunday': false,
        },
      );
    }
    return WorkSchedule.fromMap(doc.data()!);
  }

  Stream<WorkSchedule> streamEmployeeSchedule(String userId) {
    return _schedules.doc(userId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        return WorkSchedule(
          shiftStart: const TimeOfDay(hour: 9, minute: 0),
          shiftEnd: const TimeOfDay(hour: 17, minute: 0),
          toleranceMinutes: 15,
          minWorkingHours: 8,
          workDays: {
            'monday': true,
            'tuesday': true,
            'wednesday': true,
            'thursday': true,
            'friday': true,
            'saturday': false,
            'sunday': false,
          },
        );
      }
      return WorkSchedule.fromMap(doc.data()!);
    });
  }

  Future<void> setEmployeeSchedule({
    required String userId,
    required WorkSchedule schedule,
  }) async {
    await _schedules.doc(userId).set({
      ...schedule.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Check if today is a workday for employee
  Future<bool> isWorkdayToday(String userId) async {
    final schedule = await getEmployeeSchedule(userId);

    final today = DateTime.now();
    final dayOfWeek = today.weekday; // 1 = Monday, 7 = Sunday

    switch (dayOfWeek) {
      case 1:
        return schedule.workDays['monday'] ?? true;
      case 2:
        return schedule.workDays['tuesday'] ?? true;
      case 3:
        return schedule.workDays['wednesday'] ?? true;
      case 4:
        return schedule.workDays['thursday'] ?? true;
      case 5:
        return schedule.workDays['friday'] ?? true;
      case 6:
        return schedule.workDays['saturday'] ?? false;
      case 7:
        return schedule.workDays['sunday'] ?? false;
      default:
        return true;
    }
  }
}

final workScheduleRepositoryProvider = Provider<WorkScheduleRepository>((ref) {
  return WorkScheduleRepository(ref.watch(firestoreProvider));
});
