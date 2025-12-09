import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';

class LeaveRepository {
  LeaveRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _leaves =>
      _db.collection('leaveRequests');

  Stream<QuerySnapshot<Map<String, dynamic>>> streamMyLeave(String userId) {
    return _leaves
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
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
    });
  }
}

final leaveRepositoryProvider = Provider<LeaveRepository>((ref) {
  return LeaveRepository(ref.watch(firestoreProvider));
});

