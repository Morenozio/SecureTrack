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
    required String adminCode,
    required String name,
    required String email,
    required String password,
  }) async {
    await _validateAdminCode(adminCode);
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    final uid = cred.user!.uid;

    final userData = {
      'name': name,
      'email': email,
      'role': 'admin',
      'contact': '',
      'deviceId': null,
      'adminCodeUsed': adminCode,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _db.collection('users').doc(uid).set(userData);

    await _db.collection('adminCodes').doc(adminCode).update({
      'used': true,
      'usedBy': uid,
      'usedAt': FieldValue.serverTimestamp(),
    });

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

    if (savedDevice == null || savedDevice.isEmpty) {
      // bind the first device
      await doc.reference.update({'deviceId': deviceId, 'updatedAt': FieldValue.serverTimestamp()});
      return;
    }
    if (savedDevice != deviceId) {
      await _auth.signOut();
      throw Exception('Perangkat berbeda. Akses ditolak dan admin akan diberi notifikasi.');
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
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await docRef.set(data);
      snap = await docRef.get();
    } else {
      data = snap.data()!;
    }

    final role = (data['role'] ?? '') as String;
    String? savedDevice = data['deviceId'] as String?;

    if (role == 'employee') {
      if (savedDevice == null || savedDevice.isEmpty) {
        await docRef.update({
          'deviceId': deviceId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        savedDevice = deviceId;
      } else if (savedDevice != deviceId) {
        await _auth.signOut();
        throw Exception('Perangkat berbeda. Akses ditolak dan admin akan diberi notifikasi.');
      }
    }

    return AppUser.fromMap(uid, {
      ...data,
      'deviceId': savedDevice,
    });
  }

  Future<void> _validateAdminCode(String code) async {
    final doc = await _db.collection('adminCodes').doc(code).get();
    if (!doc.exists) {
      throw Exception('Admin code tidak valid.');
    }
    final data = doc.data()!;
    final isActive = data['isActive'] as bool? ?? false;
    final used = data['used'] as bool? ?? false;
    if (!isActive || used) {
      throw Exception('Admin code sudah digunakan / tidak aktif.');
    }
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

