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
    return _leaves
        .where('userId', isEqualTo: userId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamAllLeaves() {
    return _leaves.orderBy('createdAt', descending: true).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamPendingLeaves() {
    // Remove orderBy to avoid composite index requirement
    // We'll sort on client side instead
    return _leaves
        .where('status', isEqualTo: 'Menunggu')
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamLeavesByStatus(String status) {
    // Remove orderBy to avoid composite index requirement
    // We'll sort on client side instead
    return _leaves
        .where('status', isEqualTo: status)
        .snapshots();
  }

  Future<void> submitLeave({
    required String userId,
    required String type,
    required String notes,
  }) async {
    await _leaves.add({
      'userId': userId,
      'type': type,
      'notes': notes,
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
}

final leaveRepositoryProvider = Provider<LeaveRepository>((ref) {
  return LeaveRepository(ref.watch(firestoreProvider));
});








