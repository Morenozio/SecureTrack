import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'attendance_status.dart';
import 'work_schedule_model.dart';
import '../../../core/firebase/firebase_providers.dart';
import 'wifi_network_repository.dart';

class AttendanceRepository {
  AttendanceRepository(this._db, this._wifiRepo);

  final FirebaseFirestore _db;
  final WifiNetworkRepository _wifiRepo;

  CollectionReference<Map<String, dynamic>> get _logs =>
      _db.collection('attendanceLogs');

  Stream<QuerySnapshot<Map<String, dynamic>>> streamUserLogs(String userId) {
    // Removed orderBy and limit to avoid needing a composite index on userId + checkIn.
    // Sorting and limiting will be done on the client side.
    return _logs.where('userId', isEqualTo: userId).snapshots();
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
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getTodayCheckIns({
    String? userId,
  }) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Get all recent logs and filter on client side to avoid composite index
    // If userId is provided, we can try to filter by it if we had a composite index,
    // but without one, we just fetch recent logs.
    // Optimization: If userId provided but no composite index, we might fetch too much.
    // However, keeping it simple as per original design (client-side filtering).

    Query<Map<String, dynamic>> query = _logs
        .orderBy('checkIn', descending: true)
        .limit(100);

    if (userId != null) {
      // If we have index, use it. If not, this might fail without index.
      // But since we are doing client side filtering in original code, let's keep it safe:
      // Actually, we can just filter in memory from the 100 recent logs.
      // OR better: use where('userId', isEqualTo: userId) if we don't order by checkIn first?
      // Let's stick to the safe "fetch recent global logs" approach for now to avoid index issues,
      // then filter in memory.
    }

    final snapshot = await query.get();

    // Filter on client side for today's check-ins AND userId
    return snapshot.docs.where((doc) {
      final data = doc.data();
      if (userId != null && data['userId'] != userId) return false;

      final checkIn = (data['checkIn'] as Timestamp?)?.toDate();
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
    // 1. Validate WiFi Credentials
    if (ssid.trim().isEmpty ||
        bssid.trim().isEmpty ||
        ssid.toLowerCase() == 'manual' ||
        bssid.toLowerCase() == 'manual') {
      throw Exception(
        'Check-in ditolak: Informasi WiFi tidak valid atau tidak terbaca.\n'
        'Pastikan GPS dan WiFi aktif.',
      );
    }

    // 2. Verify WiFi network (if check-in allowed only via registered WiFi)
    final isValid = await _wifiRepo.verifyWifiNetwork(ssid: ssid, bssid: bssid);
    if (!isValid) {
      throw Exception(
        'Check-in ditolak: Perangkat tidak terhubung ke WiFi kantor yang terdaftar.\n'
        'SSID: $ssid\n'
        'BSSID: ${bssid.toUpperCase()}',
      );
    }

    // 3. Check for existing attendance today
    final todayCheckIns = await getTodayCheckIns(userId: userId);
    if (todayCheckIns.isNotEmpty) {
      // Check if already checked in and not checked out (active session)
      final hasActiveSession = todayCheckIns.any(
        (doc) => doc['checkOut'] == null,
      );
      if (hasActiveSession) {
        throw Exception(
          'Check-in ditolak: Anda sudah melakukan check-in hari ini dan belum check-out.',
        );
      }

      // Check if already completed a session today
      // (Assuming 1 session per day policy, but can be relaxed if needed)
      throw Exception(
        'Check-in ditolak: Anda sudah menyelesaikan absensi hari ini.',
      );
    }

    // 4. Fetch Work Schedule for validation
    // Warning: This creates a circular dependency if WorkScheduleRepository depends on something AttendanceRepo uses.
    // Ideally, we should inject WorkScheduleRepository or fetch it here directly if simple.
    // For now, let's assume we can fetch it via a separate provider call in controller,
    // BUT typically repo logic should be self-contained.
    // Let's resolve this by fetching the schedule directly from Firestore here to avoid circular dep issues
    // or by assuming the repo has access to it.
    // To keep it clean, let's fetch the schedule doc manually here or inject WorkScheduleRepo.
    // Since we don't have it injected, let's just read the doc directly for now to be safe and fast.
    final scheduleDoc = await _db.collection('workSchedules').doc(userId).get();
    WorkSchedule? schedule;
    if (scheduleDoc.exists && scheduleDoc.data() != null) {
      schedule = WorkSchedule.fromMap(scheduleDoc.data()!);
    }
    // Default schedule if not found
    schedule ??= WorkSchedule(
      workHoursEnabled: true,
      shiftStart: const TimeOfDay(hour: 9, minute: 0),
      shiftEnd: const TimeOfDay(hour: 17, minute: 0),
      toleranceMinutes: 15,
      minWorkingHours: 8,
      workDays: {},
    );

    // 5. Calculate Status (LATE vs CHECKED_IN)
    // If work hours disabled: always CHECKED_IN (check-in anytime)
    final DateTime now = DateTime.now();
    final AttendanceStatus status = schedule.workHoursEnabled
        ? _calculateCheckInStatus(now, schedule)
        : AttendanceStatus.checkedIn;

    // 6. Save Record
    await _logs.add({
      'userId': userId,
      'deviceId': deviceId,
      'method': method,
      'wifiSsid': ssid,
      'wifiBssid': bssid.toLowerCase(),
      'checkIn': FieldValue.serverTimestamp(),
      'checkOut': null,
      'status': status.name,
      'workDuration': 0,
      'overtimeDuration': 0,
      'approvalStatus': null, // Only relevant for overtime/manual
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> checkOut(
    String userId, {
    required String ssid,
    required String bssid,
  }) async {
    // 0. Validate WiFi
    if (ssid.trim().isEmpty || bssid.trim().isEmpty) {
      throw Exception(
        'Check-out ditolak: Informasi WiFi tidak terbaca.\n'
        'Pastikan GPS dan WiFi aktif.',
      );
    }
    final isValid = await _wifiRepo.verifyWifiNetwork(ssid: ssid, bssid: bssid);
    if (!isValid) {
      throw Exception(
        'Check-out ditolak: Perangkat tidak terhubung ke WiFi kantor yang terdaftar.\n'
        'SSID: $ssid',
      );
    }

    final open = await _logs
        .where('userId', isEqualTo: userId)
        .where('checkOut', isNull: true)
        .limit(1)
        .get();

    if (open.docs.isEmpty) {
      throw Exception('Check-out gagal: Tidak ada sesi check-in yang aktif.');
    }

    final doc = open.docs.first;
    final data = doc.data();
    final checkInTime = (data['checkIn'] as Timestamp).toDate();
    final now = DateTime.now();

    // 1. Fetch Schedule
    final scheduleDoc = await _db.collection('workSchedules').doc(userId).get();
    WorkSchedule? schedule;
    if (scheduleDoc.exists && scheduleDoc.data() != null) {
      schedule = WorkSchedule.fromMap(scheduleDoc.data()!);
    }
    schedule ??= WorkSchedule(
      workHoursEnabled: true,
      shiftStart: const TimeOfDay(hour: 9, minute: 0),
      shiftEnd: const TimeOfDay(hour: 17, minute: 0),
      toleranceMinutes: 15,
      minWorkingHours: 8,
      workDays: {},
    );

    // 2. Calculate Durations
    final workDurationMinutes = now.difference(checkInTime).inMinutes;

    AttendanceStatus status;
    AttendanceApprovalStatus? approvalStatus;
    int overtimeMinutes = 0;

    if (schedule.workHoursEnabled) {
      // Apply time-based validation: early leave, overtime
      final shiftEndDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        schedule.shiftEnd.hour,
        schedule.shiftEnd.minute,
      );
      if (now.isAfter(shiftEndDateTime)) {
        overtimeMinutes = now.difference(shiftEndDateTime).inMinutes;
      }
      if (overtimeMinutes > 0) {
        status = AttendanceStatus.overtime;
        approvalStatus = AttendanceApprovalStatus.pending;
      } else if (workDurationMinutes < (schedule.minWorkingHours * 60)) {
        status = AttendanceStatus.earlyLeave;
      } else {
        status = AttendanceStatus.checkedOut;
      }
    } else {
      // Work hours disabled: always CHECKED_OUT, no early leave/overtime
      status = AttendanceStatus.checkedOut;
    }

    // 4. Update Record
    await doc.reference.update({
      'checkOut': FieldValue.serverTimestamp(),
      'workDuration': workDurationMinutes,
      'overtimeDuration': overtimeMinutes,
      'status': status.name,
      'approvalStatus': approvalStatus?.name,
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
    // Calculate durations if checkOut is provided
    int workDuration = 0;
    int overtimeDuration = 0;

    // If status is not provided, we should probably calculate it,
    // but for manual logs, admin usually overrides.
    // Ideally we should calculate it too, but let's stick to provided status needed for admin.

    if (checkOut != null) {
      workDuration = checkOut.difference(checkIn).inMinutes;
      // Overtime calc would need schedule, simplified here for manual entry
    }

    await _logs.add({
      'userId': userId,
      'deviceId': deviceId,
      'method': 'manual',
      'wifiSsid': ssid,
      'wifiBssid': bssid?.toLowerCase(),
      'checkIn': Timestamp.fromDate(checkIn),
      'checkOut': checkOut != null ? Timestamp.fromDate(checkOut) : null,
      'status': status ?? AttendanceStatus.checkedIn.name,
      'workDuration': workDuration,
      'overtimeDuration': overtimeDuration,
      'approvalStatus': AttendanceApprovalStatus
          .approved
          .name, // Manual logs by admin are auto-approved
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
    String? approvalStatus,
  }) async {
    final updates = <String, dynamic>{};
    if (checkIn != null) updates['checkIn'] = Timestamp.fromDate(checkIn);
    if (checkOut != null) updates['checkOut'] = Timestamp.fromDate(checkOut);
    if (ssid != null) updates['wifiSsid'] = ssid;
    if (bssid != null) updates['wifiBssid'] = bssid.toLowerCase();
    if (status != null) updates['status'] = status;
    if (approvalStatus != null) updates['approvalStatus'] = approvalStatus;

    if (updates.isEmpty) return;

    // Recalculate duration if checkIn/checkOut changed?
    // Complex to do without full read. Assuming admin handles it or fields updated separately.
    // For now just update fields.

    updates['updatedAt'] = FieldValue.serverTimestamp();
    await _logs.doc(logId).update(updates);
  }

  AttendanceStatus _calculateCheckInStatus(
    DateTime checkInTime,
    WorkSchedule schedule,
  ) {
    final shiftStart = DateTime(
      checkInTime.year,
      checkInTime.month,
      checkInTime.day,
      schedule.shiftStart.hour,
      schedule.shiftStart.minute,
    );

    // Add tolerance
    final lateThreshold = shiftStart.add(
      Duration(minutes: schedule.toleranceMinutes),
    );

    if (checkInTime.isAfter(lateThreshold)) {
      return AttendanceStatus.late;
    }
    return AttendanceStatus.checkedIn;
  }

  /// Delete all attendance logs for [userId] in [year]-[month].
  Future<int> resetUserLogsForMonth({
    required String userId,
    required int year,
    required int month,
  }) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);

    // Fetch all logs for user, then filter by month client-side
    // to avoid requiring a composite index on userId + checkIn.
    final snap = await _logs.where('userId', isEqualTo: userId).get();

    final docsInMonth = snap.docs.where((doc) {
      final checkIn = (doc.data()['checkIn'] as Timestamp?)?.toDate();
      if (checkIn == null) return false;
      return !checkIn.isBefore(start) && checkIn.isBefore(end);
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

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository(
    ref.watch(firestoreProvider),
    ref.watch(wifiNetworkRepositoryProvider),
  );
});
