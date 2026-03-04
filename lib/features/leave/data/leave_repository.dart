import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';

class LeaveRepository {
  LeaveRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _leaves =>
      _db.collection('leaveRequests');

  Stream<QuerySnapshot<Map<String, dynamic>>> streamMyLeave(String userId) {
    // Remove orderBy to avoid composite index requirement
    // We'll sort on client side instead
    return _leaves.where('userId', isEqualTo: userId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamAllLeaves() {
    return _leaves.orderBy('createdAt', descending: true).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamPendingLeaves() {
    // Remove orderBy to avoid composite index requirement
    // We'll sort on client side instead
    return _leaves.where('status', isEqualTo: 'Menunggu').snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamLeavesByStatus(
    String status,
  ) {
    // Remove orderBy to avoid composite index requirement
    // We'll sort on client side instead
    return _leaves.where('status', isEqualTo: status).snapshots();
  }

  Future<void> submitLeave({
    required String userId,
    required String type,
    required String notes,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    await _leaves.add({
      'userId': userId,
      'type': type,
      'notes': notes,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'status': 'Menunggu',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> approveLeave({
    required String leaveId,
    String? adminNotes,
  }) async {
    await _leaves.doc(leaveId).update({
      'status': 'Diterima',
      'adminNotes': adminNotes,
      'updatedAt': FieldValue.serverTimestamp(),
      'processedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> rejectLeave({
    required String leaveId,
    String? adminNotes,
  }) async {
    await _leaves.doc(leaveId).update({
      'status': 'Ditolak',
      'adminNotes': adminNotes,
      'updatedAt': FieldValue.serverTimestamp(),
      'processedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete all leave requests for [userId] in [year]-[month].
  Future<int> resetUserLeavesForMonth({
    required String userId,
    required int year,
    required int month,
  }) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);

    // Fetch all leaves for user, filter by month client-side
    // to avoid requiring a composite index.
    final snap = await _leaves.where('userId', isEqualTo: userId).get();

    final docsInMonth = snap.docs.where((doc) {
      final created = (doc.data()['createdAt'] as Timestamp?)?.toDate();
      if (created == null) return false;
      return !created.isBefore(start) && created.isBefore(end);
    }).toList();

    if (docsInMonth.isEmpty) return 0;

    final batch = _db.batch();
    for (final doc in docsInMonth) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    return docsInMonth.length;
  }
}

final leaveRepositoryProvider = Provider<LeaveRepository>((ref) {
  return LeaveRepository(ref.watch(firestoreProvider));
});
