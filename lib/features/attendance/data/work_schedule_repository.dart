import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';

class WorkScheduleRepository {
  WorkScheduleRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _schedules =>
      _db.collection('workSchedules');

  Future<Map<String, bool>?> getEmployeeSchedule(String userId) async {
    final doc = await _schedules.doc(userId).get();
    if (!doc.exists || doc.data() == null) return null;
    final data = doc.data()!;
    return {
      'monday': (data['monday'] ?? true) as bool,
      'tuesday': (data['tuesday'] ?? true) as bool,
      'wednesday': (data['wednesday'] ?? true) as bool,
      'thursday': (data['thursday'] ?? true) as bool,
      'friday': (data['friday'] ?? true) as bool,
      'saturday': (data['saturday'] ?? false) as bool,
      'sunday': (data['sunday'] ?? false) as bool,
    };
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamEmployeeSchedule(String userId) {
    return _schedules.doc(userId).snapshots();
  }

  Future<void> setEmployeeSchedule({
    required String userId,
    required Map<String, bool> schedule,
  }) async {
    await _schedules.doc(userId).set({
      ...schedule,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Check if today is a workday for employee
  Future<bool> isWorkdayToday(String userId) async {
    final schedule = await getEmployeeSchedule(userId);
    if (schedule == null) return true; // Default: all days are workdays
    
    final today = DateTime.now();
    final dayOfWeek = today.weekday; // 1 = Monday, 7 = Sunday
    
    switch (dayOfWeek) {
      case 1:
        return schedule['monday'] ?? true;
      case 2:
        return schedule['tuesday'] ?? true;
      case 3:
        return schedule['wednesday'] ?? true;
      case 4:
        return schedule['thursday'] ?? true;
      case 5:
        return schedule['friday'] ?? true;
      case 6:
        return schedule['saturday'] ?? false;
      case 7:
        return schedule['sunday'] ?? false;
      default:
        return true;
    }
  }
}

final workScheduleRepositoryProvider = Provider<WorkScheduleRepository>((ref) {
  return WorkScheduleRepository(ref.watch(firestoreProvider));
});
