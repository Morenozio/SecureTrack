import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';

class AttendanceRepository {
  AttendanceRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _logs =>
      _db.collection('attendanceLogs');

  Stream<QuerySnapshot<Map<String, dynamic>>> streamUserLogs(String userId) {
    return _logs
        .where('userId', isEqualTo: userId)
        .orderBy('checkIn', descending: true)
        .limit(50)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamRecentLogs() {
    return _logs.orderBy('checkIn', descending: true).limit(20).snapshots();
  }

  Future<void> checkIn({
    required String userId,
    required String? deviceId,
    required String method,
  }) async {
    await _logs.add({
      'userId': userId,
      'deviceId': deviceId,
      'method': method,
      'checkIn': FieldValue.serverTimestamp(),
      'checkOut': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> checkOut(String userId) async {
    final open = await _logs
        .where('userId', isEqualTo: userId)
        .where('checkOut', isNull: true)
        .orderBy('checkIn', descending: true)
        .limit(1)
        .get();
    if (open.docs.isEmpty) {
      // Jika tidak ada sesi terbuka, tidak melakukan apa-apa.
      return;
    }
    await open.docs.first.reference.update({
      'checkOut': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository(ref.watch(firestoreProvider));
});

