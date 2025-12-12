import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import 'user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    auth: ref.watch(firebaseAuthProvider),
    db: ref.watch(firestoreProvider),
    deviceInfo: DeviceInfoPlugin(),
  );
});

class AuthRepository {
  AuthRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore db,
    required DeviceInfoPlugin deviceInfo,
  })  : _auth = auth,
        _db = db,
        _deviceInfo = deviceInfo;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final DeviceInfoPlugin _deviceInfo;

  Stream<AppUser?> currentUserStream() {
    return _auth.authStateChanges().asyncExpand((user) async* {
      if (user == null) {
        yield null;
        return;
      }
      yield* _db.collection('users').doc(user.uid).snapshots().map((doc) {
        if (!doc.exists || doc.data() == null) return null;
        return AppUser.fromMap(doc.id, doc.data()!);
      });
    });
  }

  Future<AppUser> adminSignUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    final uid = cred.user!.uid;

    final userData = {
      'name': name,
      'email': email,
      'role': 'admin',
      'contact': '',
      'deviceId': null,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _db.collection('users').doc(uid).set(userData);

    return AppUser(
      id: uid,
      name: name,
      email: email,
      role: 'admin',
      contact: '',
      deviceId: null,
    );
  }

  Future<AppUser> employeeSignUp({
    required String name,
    required String email,
    required String password,
    String? contact,
  }) async {
    final deviceId = await _deviceId();
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    final uid = cred.user!.uid;

    await _db.collection('users').doc(uid).set({
      'name': name,
      'email': email,
      'role': 'employee',
      'contact': contact ?? '',
      'deviceId': deviceId,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return AppUser(
      id: uid,
      name: name,
      email: email,
      role: 'employee',
      contact: contact ?? '',
      deviceId: deviceId,
    );
  }

  Future<void> adminLogin({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> employeeLogin({
    required String email,
    required String password,
  }) async {
    final deviceId = await _deviceId();
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    final uid = cred.user!.uid;

    final doc = await _db.collection('users').doc(uid).get();
    final data = doc.data();
    final savedDevice = data?['deviceId'] as String?;
    final isActive = (data?['isActive'] ?? true) as bool;

    if (!isActive) {
      await _auth.signOut();
      throw Exception('Akun karyawan ini non-aktif. Hubungi admin.');
    }

    // Untuk sementara, izinkan login tanpa cek perangkat.
    if (savedDevice == null || savedDevice.isEmpty) {
      await doc.reference.update({'deviceId': deviceId, 'updatedAt': FieldValue.serverTimestamp()});
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<AppUser> loginAuto({
    required String email,
    required String password,
  }) async {
    final deviceId = await _deviceId();
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    final uid = cred.user!.uid;

    final docRef = _db.collection('users').doc(uid);
    var snap = await docRef.get();
    Map<String, dynamic> data;

    if (!snap.exists || snap.data() == null) {
      // Auto-create minimal profile if missing
      data = {
        'name': email.split('@').first,
        'email': email,
        'role': 'employee',
        'contact': '',
        'deviceId': deviceId,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await docRef.set(data);
      snap = await docRef.get();
    } else {
      data = snap.data()!;
    }

    final role = (data['role'] ?? '') as String;
    final isActive = (data['isActive'] ?? true) as bool;
    String? savedDevice = data['deviceId'] as String?;

    if (role == 'employee') {
      if (!isActive) {
        await _auth.signOut();
        throw Exception('Akun karyawan ini non-aktif. Hubungi admin.');
      }
      // Untuk sementara, izinkan login tanpa cek perangkat.
      if (savedDevice == null || savedDevice.isEmpty) {
        await docRef.update({
          'deviceId': deviceId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        savedDevice = deviceId;
      }
    }

    return AppUser.fromMap(uid, {
      ...data,
      'deviceId': savedDevice,
    });
  }

  Future<void> updateUserRole({
    required String userId,
    required String newRole,
  }) async {
    if (newRole != 'admin' && newRole != 'employee') {
      throw Exception('Role tidak valid. Harus "admin" atau "employee".');
    }
    
    await _db.collection('users').doc(userId).update({
      'role': newRole,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateUserProfile({
    required String userId,
    String? name,
    String? email,
    String? contact,
    String? role,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name.trim();
    if (email != null) updates['email'] = email.trim();
    if (contact != null) updates['contact'] = contact.trim();
    if (role != null) {
      if (role != 'admin' && role != 'employee') {
        throw Exception('Role tidak valid. Harus "admin" atau "employee".');
      }
      updates['role'] = role;
    }
    if (updates.isEmpty) return;
    updates['updatedAt'] = FieldValue.serverTimestamp();
    await _db.collection('users').doc(userId).update(updates);
  }

  Future<void> setUserActiveStatus({
    required String userId,
    required bool isActive,
  }) async {
    await _db.collection('users').doc(userId).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteUserDoc({required String userId}) async {
    await _db.collection('users').doc(userId).delete();
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<String> _deviceId() async {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) {
      final info = await _deviceInfo.androidInfo;
      return info.id ?? info.fingerprint ?? 'unknown-android';
    }
    if (Platform.isIOS) {
      final info = await _deviceInfo.iosInfo;
      return info.identifierForVendor ?? 'unknown-ios';
    }
    return 'unknown-device';
  }
}

