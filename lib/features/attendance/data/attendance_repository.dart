import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import 'wifi_network_repository.dart';

class AttendanceRepository {
  AttendanceRepository(this._db, this._wifiRepo);

  final FirebaseFirestore _db;
  final WifiNetworkRepository _wifiRepo;

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

  Stream<QuerySnapshot<Map<String, dynamic>>> streamActiveSession(
    String userId,
  ) {
    return _logs
        .where('userId', isEqualTo: userId)
        .where('checkOut', isNull: true)
        .limit(1)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamLogsForRange(
    DateTime start,
    DateTime end,
  ) {
    return _logs
        .where('checkIn', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('checkIn', isLessThan: Timestamp.fromDate(end))
        .orderBy('checkIn', descending: true)
        .snapshots();
  }

  // Get today's check-ins (filter on client side to avoid composite index)
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  getTodayCheckIns() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Get all recent logs and filter on client side to avoid composite index
    final snapshot = await _logs
        .orderBy('checkIn', descending: true)
        .limit(100)
        .get();

    // Filter on client side for today's check-ins
    return snapshot.docs.where((doc) {
      final checkIn = (doc.data()['checkIn'] as Timestamp?)?.toDate();
      if (checkIn == null) return false;
      return checkIn.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
          checkIn.isBefore(endOfDay);
    }).toList();
  }

  Future<void> checkIn({
    required String userId,
    required String? deviceId,
    required String method,
    required String ssid,
    required String bssid,
  }) async {
    // Explicitly reject empty or 'manual' credentials to prevent bypass
    if (ssid.trim().isEmpty ||
        bssid.trim().isEmpty ||
        ssid.toLowerCase() == 'manual' ||
        bssid.toLowerCase() == 'manual') {
      throw Exception(
        'Check-in ditolak: Informasi WiFi tidak valid atau tidak terbaca.\n'
        'Pastikan GPS dan WiFi aktif.',
      );
    }

    // Verify WiFi network against admin list
    final isValid = await _wifiRepo.verifyWifiNetwork(ssid: ssid, bssid: bssid);

    if (!isValid) {
      throw Exception(
        'Check-in ditolak: Perangkat tidak terhubung ke WiFi kantor yang terdaftar.\n'
        'SSID: $ssid\n'
        'BSSID: ${bssid.toUpperCase()}',
      );
    }

    await _logs.add({
      'userId': userId,
      'deviceId': deviceId,
      'method': method,
      'wifiSsid': ssid,
      'wifiBssid': bssid.toLowerCase(), // Store normalized BSSID
      'checkIn': FieldValue.serverTimestamp(),
      'checkOut': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> checkOut(String userId) async {
    final open = await _logs
        .where('userId', isEqualTo: userId)
        .where('checkOut', isNull: true)
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

  Future<void> addManualLog({
    required String userId,
    String? deviceId,
    required DateTime checkIn,
    DateTime? checkOut,
    String? ssid,
    String? bssid,
    String? status,
  }) async {
    await _logs.add({
      'userId': userId,
      'deviceId': deviceId,
      'method': 'manual',
      'wifiSsid': ssid,
      'wifiBssid': bssid?.toLowerCase(),
      'checkIn': Timestamp.fromDate(checkIn),
      'checkOut': checkOut != null ? Timestamp.fromDate(checkOut) : null,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateLog({
    required String logId,
    DateTime? checkIn,
    DateTime? checkOut,
    String? ssid,
    String? bssid,
    String? status,
  }) async {
    final updates = <String, dynamic>{};
    if (checkIn != null) updates['checkIn'] = Timestamp.fromDate(checkIn);
    if (checkOut != null) updates['checkOut'] = Timestamp.fromDate(checkOut);
    if (ssid != null) updates['wifiSsid'] = ssid;
    if (bssid != null) updates['wifiBssid'] = bssid.toLowerCase();
    if (status != null) updates['status'] = status;
    if (updates.isEmpty) return;
    updates['updatedAt'] = FieldValue.serverTimestamp();
    await _logs.doc(logId).update(updates);
  }
}

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository(
    ref.watch(firestoreProvider),
    ref.watch(wifiNetworkRepositoryProvider),
  );
});
