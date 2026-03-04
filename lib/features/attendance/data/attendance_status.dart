import 'package:flutter/material.dart';

enum AttendanceStatus {
  notCheckedIn,
  checkedIn,
  checkedOut,
  late,
  earlyLeave,
  overtime,
  absent;

  String get label {
    switch (this) {
      case AttendanceStatus.notCheckedIn:
        return 'Belum Check-in';
      case AttendanceStatus.checkedIn:
        return 'Checked In';
      case AttendanceStatus.checkedOut:
        return 'Checked Out';
      case AttendanceStatus.late:
        return 'Terlambat';
      case AttendanceStatus.earlyLeave:
        return 'Pulang Awal';
      case AttendanceStatus.overtime:
        return 'Lembur';
      case AttendanceStatus.absent:
        return 'Absen (Tidak Hadir)';
    }
  }

  Color get color {
    switch (this) {
      case AttendanceStatus.notCheckedIn:
        return Colors.grey;
      case AttendanceStatus.checkedIn:
        return Colors.blue;
      case AttendanceStatus.checkedOut:
        return Colors.green;
      case AttendanceStatus.late:
        return Colors.orange;
      case AttendanceStatus.earlyLeave:
        return Colors.orangeAccent;
      case AttendanceStatus.overtime:
        return Colors.purple;
      case AttendanceStatus.absent:
        return Colors.red;
    }
  }

  static AttendanceStatus fromString(String? value) {
    if (value == null) return AttendanceStatus.notCheckedIn;
    try {
      return AttendanceStatus.values.firstWhere(
        (e) => e.name == value,
        orElse: () => AttendanceStatus.notCheckedIn,
      );
    } catch (_) {
      return AttendanceStatus.notCheckedIn;
    }
  }
}

enum AttendanceApprovalStatus {
  pending,
  approved,
  rejected;

  String get label {
    switch (this) {
      case AttendanceApprovalStatus.pending:
        return 'Menunggu Persetujuan';
      case AttendanceApprovalStatus.approved:
        return 'Disetujui';
      case AttendanceApprovalStatus.rejected:
        return 'Ditolak';
    }
  }

  Color get color {
    switch (this) {
      case AttendanceApprovalStatus.pending:
        return Colors.orange;
      case AttendanceApprovalStatus.approved:
        return Colors.green;
      case AttendanceApprovalStatus.rejected:
        return Colors.red;
    }
  }

  static AttendanceApprovalStatus? fromString(String? value) {
    if (value == null) return null;
    try {
      return AttendanceApprovalStatus.values.firstWhere((e) => e.name == value);
    } catch (_) {
      return null;
    }
  }
}
