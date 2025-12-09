import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import 'user_model.dart';

final authStateProvider = StreamProvider<fb.User?>(
  (ref) => ref.watch(firebaseAuthProvider).authStateChanges(),
);

final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final authState = ref.watch(authStateProvider).valueOrNull;
  if (authState == null) return const Stream.empty();
  final db = ref.watch(firestoreProvider);
  return db.collection('users').doc(authState.uid).snapshots().map((doc) {
    if (!doc.exists || doc.data() == null) return null;
    return AppUser.fromMap(doc.id, doc.data()!);
  });
});

final usersCollectionProvider = Provider<CollectionReference<Map<String, dynamic>>>(
  (ref) => ref.watch(firestoreProvider).collection('users'),
);

