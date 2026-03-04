import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/animated_page.dart';
import '../../../core/widgets/app_background.dart';
import '../data/attendance_repository.dart';
import '../../leave/data/leave_repository.dart';

class EmployeeAttendanceDetailScreen extends ConsumerStatefulWidget {
  const EmployeeAttendanceDetailScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  final String userId;
  final String userName;

  @override
  ConsumerState<EmployeeAttendanceDetailScreen> createState() =>
      _EmployeeAttendanceDetailScreenState();
}

class _EmployeeAttendanceDetailScreenState
    extends ConsumerState<EmployeeAttendanceDetailScreen> {
  bool _isSaving = false;

  // User profile data
  String? _photoUrl;
  String? _role;
  String? _department;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _photoUrl = data['photoUrl'] as String?;
          _role = data['role'] as String?;
          _department = data['department'] as String?;
        });
      }
    } catch (_) {}
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _logsStream() {
    return ref.read(attendanceRepositoryProvider).streamUserLogs(widget.userId);
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '-';
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final yyyy = dt.year.toString().padLeft(4, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    return '$yyyy-$mo-$dd $hh:$mm';
  }

  Duration _duration(DateTime? a, DateTime? b) {
    if (a == null || b == null) return Duration.zero;
    return b.difference(a);
  }

  // ─── Edit Log Dialog ───
  Future<void> _editLog(String logId, Map<String, dynamic> data) async {
    final checkIn = (data['checkIn'] as Timestamp?)?.toDate();
    final checkOut = (data['checkOut'] as Timestamp?)?.toDate();
    final ssid = data['wifiSsid'] as String?;
    final bssid = data['wifiBssid'] as String?;
    final status = data['status'] as String?;

    final checkInCtrl = TextEditingController(
      text: checkIn?.toIso8601String() ?? '',
    );
    final checkOutCtrl = TextEditingController(
      text: checkOut?.toIso8601String() ?? '',
    );
    final ssidCtrl = TextEditingController(text: ssid ?? '');
    final bssidCtrl = TextEditingController(text: bssid ?? '');
    String? selectedStatus = status;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Absensi'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: checkInCtrl,
                decoration: const InputDecoration(
                  labelText: 'Check-in (ISO 8601) contoh: 2025-12-10T08:30:00',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: checkOutCtrl,
                decoration: const InputDecoration(
                  labelText: 'Check-out (ISO 8601, opsional)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ssidCtrl,
                decoration: const InputDecoration(labelText: 'SSID'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: bssidCtrl,
                decoration: const InputDecoration(labelText: 'BSSID'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Status Kehadiran',
                ),
                items: const [
                  DropdownMenuItem(value: 'hadir', child: Text('Hadir')),
                  DropdownMenuItem(value: 'telat', child: Text('Telat')),
                  DropdownMenuItem(value: 'izin', child: Text('Izin')),
                  DropdownMenuItem(value: 'sakit', child: Text('Sakit')),
                  DropdownMenuItem(value: 'alpha', child: Text('Alpha')),
                  DropdownMenuItem(value: 'wfh', child: Text('WFH')),
                ],
                onChanged: (v) => selectedStatus = v,
              ),
              const SizedBox(height: 8),
              const Text(
                'Format cepat: gunakan tombol copy/export untuk verifikasi. '
                'Waktu menggunakan zona lokal perangkat.',
                style: TextStyle(fontSize: 12, color: Colors.orange),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final ci = checkInCtrl.text.trim().isEmpty
                  ? null
                  : DateTime.tryParse(checkInCtrl.text.trim());
              final co = checkOutCtrl.text.trim().isEmpty
                  ? null
                  : DateTime.tryParse(checkOutCtrl.text.trim());
              if (checkInCtrl.text.trim().isNotEmpty && ci == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Format check-in tidak valid'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              if (checkOutCtrl.text.trim().isNotEmpty && co == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Format check-out tidak valid'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              setState(() => _isSaving = true);
              try {
                await ref
                    .read(attendanceRepositoryProvider)
                    .updateLog(
                      logId: logId,
                      checkIn: ci,
                      checkOut: co,
                      ssid: ssidCtrl.text.trim().isEmpty
                          ? null
                          : ssidCtrl.text.trim(),
                      bssid: bssidCtrl.text.trim().isEmpty
                          ? null
                          : bssidCtrl.text.trim(),
                      status: selectedStatus,
                    );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Absensi diperbarui'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } finally {
                if (mounted) setState(() => _isSaving = false);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  // ─── Add Manual Log Dialog ───
  Future<void> _addManualLog() async {
    DateTime? checkIn;
    DateTime? checkOut;
    final checkInCtrl = TextEditingController();
    final checkOutCtrl = TextEditingController();
    final ssidCtrl = TextEditingController();
    final bssidCtrl = TextEditingController();
    String? status;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Manual'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: checkInCtrl,
                decoration: const InputDecoration(
                  labelText: 'Check-in (ISO 8601, wajib)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: checkOutCtrl,
                decoration: const InputDecoration(
                  labelText: 'Check-out (ISO 8601, opsional)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ssidCtrl,
                decoration: const InputDecoration(labelText: 'SSID'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: bssidCtrl,
                decoration: const InputDecoration(labelText: 'BSSID'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(
                  labelText: 'Status Kehadiran',
                ),
                items: const [
                  DropdownMenuItem(value: 'hadir', child: Text('Hadir')),
                  DropdownMenuItem(value: 'telat', child: Text('Telat')),
                  DropdownMenuItem(value: 'izin', child: Text('Izin')),
                  DropdownMenuItem(value: 'sakit', child: Text('Sakit')),
                  DropdownMenuItem(value: 'alpha', child: Text('Alpha')),
                  DropdownMenuItem(value: 'wfh', child: Text('WFH')),
                ],
                onChanged: (v) => status = v,
              ),
              const SizedBox(height: 8),
              const Text(
                'Gunakan format 2025-12-10T08:30:00. Zona waktu mengikuti perangkat.',
                style: TextStyle(fontSize: 12, color: Colors.orange),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              checkIn = DateTime.tryParse(checkInCtrl.text.trim());
              checkOut = checkOutCtrl.text.trim().isEmpty
                  ? null
                  : DateTime.tryParse(checkOutCtrl.text.trim());
              if (checkIn == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Check-in wajib dan harus valid'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.of(context).pop(true);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (checkIn == null) return;
    setState(() => _isSaving = true);
    try {
      await ref
          .read(attendanceRepositoryProvider)
          .addManualLog(
            userId: widget.userId,
            checkIn: checkIn!,
            checkOut: checkOut,
            ssid: ssidCtrl.text.trim().isEmpty ? null : ssidCtrl.text.trim(),
            bssid: bssidCtrl.text.trim().isEmpty ? null : bssidCtrl.text.trim(),
            status: status,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Log manual ditambahkan'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── Reset Data Dialog ───
  Future<void> _resetData() async {
    final now = DateTime.now();
    int selectedYear = now.year;
    int selectedMonth = now.month;
    final monthNames = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    String resetType = 'all';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Reset Data Karyawan'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pilih bulan dan jenis data yang akan direset untuk ${widget.userName}.',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: selectedMonth,
                          decoration: const InputDecoration(
                            labelText: 'Bulan',
                            isDense: true,
                          ),
                          items: List.generate(12, (i) {
                            return DropdownMenuItem(
                              value: i + 1,
                              child: Text(monthNames[i]),
                            );
                          }),
                          onChanged: (v) {
                            if (v != null) {
                              setDialogState(() => selectedMonth = v);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 90,
                        child: DropdownButtonFormField<int>(
                          value: selectedYear,
                          decoration: const InputDecoration(
                            labelText: 'Tahun',
                            isDense: true,
                          ),
                          items: List.generate(5, (i) {
                            final y = now.year - 2 + i;
                            return DropdownMenuItem(
                              value: y,
                              child: Text('$y'),
                            );
                          }),
                          onChanged: (v) {
                            if (v != null) {
                              setDialogState(() => selectedYear = v);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: resetType,
                    decoration: const InputDecoration(
                      labelText: 'Jenis data',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('Semua (Absensi + Cuti)'),
                      ),
                      DropdownMenuItem(
                        value: 'attendance',
                        child: Text('Absensi saja'),
                      ),
                      DropdownMenuItem(
                        value: 'leaves',
                        child: Text('Cuti saja'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() => resetType = v);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Data yang dihapus tidak dapat dikembalikan!',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Reset'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      int deletedLogs = 0;
      int deletedLeaves = 0;

      if (resetType == 'attendance' || resetType == 'all') {
        deletedLogs = await ref
            .read(attendanceRepositoryProvider)
            .resetUserLogsForMonth(
              userId: widget.userId,
              year: selectedYear,
              month: selectedMonth,
            );
      }

      if (resetType == 'leaves' || resetType == 'all') {
        deletedLeaves = await ref
            .read(leaveRepositoryProvider)
            .resetUserLeavesForMonth(
              userId: widget.userId,
              year: selectedYear,
              month: selectedMonth,
            );
      }

      if (!mounted) return;
      final period = '${monthNames[selectedMonth - 1]} $selectedYear';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reset berhasil untuk $period:\n'
            '$deletedLogs log absensi & $deletedLeaves cuti dihapus.',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── Export CSV ───
  Future<void> _exportCsv(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    if (docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data kosong'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final buffer = StringBuffer();
    buffer.writeln(
      'EmployeeID,Name,Tanggal,CheckIn,CheckOut,SSID,BSSID,Durasi(Status),Status',
    );
    for (final doc in docs) {
      final data = doc.data();
      final checkIn = (data['checkIn'] as Timestamp?)?.toDate();
      final checkOut = (data['checkOut'] as Timestamp?)?.toDate();
      final ssid = data['wifiSsid'] ?? '';
      final bssid = data['wifiBssid'] ?? '';
      final status = data['status'] ?? '';
      final duration = _duration(checkIn, checkOut);
      final dateStr = checkIn != null
          ? '${checkIn.year.toString().padLeft(4, '0')}-${checkIn.month.toString().padLeft(2, '0')}-${checkIn.day.toString().padLeft(2, '0')}'
          : '';
      final checkInStr = _formatDateTime(checkIn);
      final checkOutStr = _formatDateTime(checkOut);
      final durStr =
          '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
      buffer.writeln(
        '${widget.userId},${widget.userName},$dateStr,$checkInStr,$checkOutStr,$ssid,$bssid,$durStr,$status',
      );
    }
    final csv = buffer.toString();
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'CSV disalin ke clipboard (silakan tempel di Excel/Sheets)',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  // ─── Helpers ───
  static const _dayNames = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  String _statusLabel(String raw) {
    switch (raw.toLowerCase()) {
      case 'checkedin':
        return 'Hadir';
      case 'checkedout':
        return 'Hadir';
      case 'late':
        return 'Telat';
      case 'hadir':
        return 'Hadir';
      case 'telat':
        return 'Telat';
      case 'izin':
        return 'Izin';
      case 'sakit':
        return 'Sakit';
      case 'alpha':
        return 'Alpha';
      case 'wfh':
        return 'WFH';
      case 'earlyleave':
        return 'Pulang Awal';
      case 'overtime':
        return 'Lembur';
      default:
        if (raw.isEmpty) return '-';
        return raw[0].toUpperCase() + raw.substring(1);
    }
  }

  Color _statusColor(String raw) {
    switch (raw.toLowerCase()) {
      case 'checkedin':
      case 'checkedout':
      case 'hadir':
        return Colors.green;
      case 'late':
      case 'telat':
        return Colors.orange;
      case 'alpha':
        return Colors.grey;
      case 'izin':
      case 'sakit':
        return Colors.blue;
      case 'wfh':
        return Colors.purple;
      case 'earlyleave':
        return Colors.amber.shade700;
      case 'overtime':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  // ────────────────────────────────────────────────────────────
  //  BUILD
  // ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/dashboard/admin');
            }
          },
        ),
        title: const Text('Attendance Log'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              switch (v) {
                case 'reset':
                  _resetData();
                  break;
                case 'schedule':
                  context.push(
                    '/admin/work-schedule/${widget.userId}?name=${Uri.encodeComponent(widget.userName)}',
                  );
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'reset', child: Text('Reset Data')),
              PopupMenuItem(value: 'schedule', child: Text('Jadwal Kerja')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addManualLog,
        icon: const Icon(Icons.add),
        label: const Text('Tambah manual'),
      ),
      body: AnimatedPage(
        child: AppBackground(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _logsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }
              final docs = snapshot.data?.docs ?? [];

              // Sort by checkIn descending
              final sortedDocs = docs.toList()
                ..sort((a, b) {
                  final aTime = (a.data()['checkIn'] as Timestamp?)?.toDate();
                  final bTime = (b.data()['checkIn'] as Timestamp?)?.toDate();
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });

              // Monthly stats — current month
              final now = DateTime.now();
              final monthStart = DateTime(now.year, now.month, 1);
              final monthEnd = DateTime(now.year, now.month + 1, 1);
              int present = 0, late = 0, absent = 0, onLeave = 0;
              for (final d in docs) {
                final data = d.data();
                final ci = (data['checkIn'] as Timestamp?)?.toDate();
                if (ci == null) continue;
                if (ci.isBefore(monthStart) || !ci.isBefore(monthEnd)) continue;
                final st = (data['status'] as String? ?? '').toLowerCase();
                switch (st) {
                  case 'checkedin':
                  case 'checkedout':
                  case 'hadir':
                  case 'wfh':
                    present++;
                    break;
                  case 'late':
                  case 'telat':
                    late++;
                    break;
                  case 'alpha':
                    absent++;
                    break;
                  case 'izin':
                  case 'sakit':
                    onLeave++;
                    break;
                  default:
                    present++;
                }
              }

              final monthLabel = DateFormat('MMMM yyyy').format(now);

              return ListView(
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  if (_isSaving) const LinearProgressIndicator(),

                  // ─── Employee Profile Summary ───
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.primary.withOpacity(0.1)
                          : AppColors.primary.withOpacity(0.05),
                    ),
                    child: Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 36,
                            backgroundColor: AppColors.primary.withOpacity(0.2),
                            backgroundImage:
                                _photoUrl != null && _photoUrl!.isNotEmpty
                                ? NetworkImage(_photoUrl!)
                                : null,
                            child: (_photoUrl == null || _photoUrl!.isEmpty)
                                ? Text(
                                    widget.userName.isNotEmpty
                                        ? widget.userName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.userName,
                                style: textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (_role != null || _department != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  [
                                    if (_role != null)
                                      _role![0].toUpperCase() +
                                          _role!.substring(1),
                                    if (_department != null) _department,
                                  ].join(' • '),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.badge_outlined,
                                    size: 14,
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.black45,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'ID: ${widget.userId.substring(0, 8).toUpperCase()}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.black45,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ─── Monthly Statistics ───
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: Row(
                      children: [
                        Text(
                          'Statistik Bulanan',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            monthLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        _StatCard(
                          label: 'HADIR',
                          value: '$present',
                          color: Colors.green,
                          isDark: isDark,
                        ),
                        const SizedBox(width: 10),
                        _StatCard(
                          label: 'TELAT',
                          value: '$late',
                          color: Colors.orange,
                          isDark: isDark,
                        ),
                        const SizedBox(width: 10),
                        _StatCard(
                          label: 'ALPHA',
                          value: '$absent',
                          color: Colors.grey,
                          isDark: isDark,
                        ),
                        const SizedBox(width: 10),
                        _StatCard(
                          label: 'CUTI',
                          value: '$onLeave',
                          color: Colors.blue,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),

                  // ─── Log Header ───
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                    child: Row(
                      children: [
                        Text(
                          'Log Kehadiran',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${sortedDocs.length}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => _exportCsv(docs),
                          icon: const Icon(Icons.file_download, size: 16),
                          label: const Text(
                            'Export',
                            style: TextStyle(fontSize: 13),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (sortedDocs.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            Icon(
                              Icons.history,
                              size: 48,
                              color: isDark ? Colors.white38 : Colors.black26,
                            ),
                            const SizedBox(height: 12),
                            const Text('Belum ada data absensi'),
                          ],
                        ),
                      ),
                    )
                  else
                    // ─── Attendance Table ───
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _AttendanceTable(
                        docs: sortedDocs,
                        isDark: isDark,
                        dayNames: _dayNames,
                        statusLabel: _statusLabel,
                        statusColor: _statusColor,
                        duration: _duration,
                        onEditLog: _editLog,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  Stat Card Widget
// ────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.primary.withOpacity(0.15) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? AppColors.primary.withOpacity(0.25)
                : AppColors.primary.withOpacity(0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white54 : Colors.black45,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  Attendance Table Widget
// ────────────────────────────────────────────────────────────
class _AttendanceTable extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final bool isDark;
  final List<String> dayNames;
  final String Function(String) statusLabel;
  final Color Function(String) statusColor;
  final Duration Function(DateTime?, DateTime?) duration;
  final Future<void> Function(String, Map<String, dynamic>) onEditLog;

  const _AttendanceTable({
    required this.docs,
    required this.isDark,
    required this.dayNames,
    required this.statusLabel,
    required this.statusColor,
    required this.duration,
    required this.onEditLog,
  });

  @override
  Widget build(BuildContext context) {
    final headerStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 1,
      color: isDark ? Colors.white54 : Colors.black45,
    );

    return Column(
      children: [
        // Table header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? AppColors.primary.withOpacity(0.2)
                    : AppColors.primary.withOpacity(0.1),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(flex: 3, child: Text('TANGGAL', style: headerStyle)),
              Expanded(flex: 2, child: Text('MASUK', style: headerStyle)),
              Expanded(flex: 2, child: Text('KELUAR', style: headerStyle)),
              Expanded(flex: 2, child: Text('TOTAL', style: headerStyle)),
              Expanded(
                flex: 2,
                child: Text(
                  'STATUS',
                  style: headerStyle,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ),
        // Table rows
        ...docs.map((doc) {
          final data = doc.data();
          final logId = doc.id;
          final checkIn = (data['checkIn'] as Timestamp?)?.toDate();
          final checkOut = (data['checkOut'] as Timestamp?)?.toDate();
          final status = data['status'] as String? ?? '';
          final dur = duration(checkIn, checkOut);

          // Date info
          final dateLabelMain = checkIn != null
              ? DateFormat('dd MMM yyyy').format(checkIn)
              : '-';
          final dayLabel = checkIn != null ? dayNames[checkIn.weekday - 1] : '';

          // Time strings
          final inTime = checkIn != null
              ? '${checkIn.hour.toString().padLeft(2, '0')}:${checkIn.minute.toString().padLeft(2, '0')}'
              : '--:--';
          final outTime = checkOut != null
              ? '${checkOut.hour.toString().padLeft(2, '0')}:${checkOut.minute.toString().padLeft(2, '0')}'
              : '--:--';
          final totalStr = dur > Duration.zero
              ? '${dur.inHours}h ${dur.inMinutes.remainder(60)}m'
              : '0h 0m';

          final sLabel = statusLabel(status);
          final sColor = statusColor(status);

          // Highlight late check-in time
          final isLateStatus =
              status.toLowerCase() == 'late' || status.toLowerCase() == 'telat';

          return InkWell(
            onTap: () => onEditLog(logId, data),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? AppColors.primary.withOpacity(0.08)
                        : AppColors.primary.withOpacity(0.05),
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Date column
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateLabelMain,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dayLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Check-in
                  Expanded(
                    flex: 2,
                    child: Text(
                      inTime,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isLateStatus
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isLateStatus
                            ? Colors.orange
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ),
                  // Check-out
                  Expanded(
                    flex: 2,
                    child: Text(
                      outTime,
                      style: TextStyle(
                        fontSize: 13,
                        color: checkOut == null
                            ? (isDark ? Colors.white30 : Colors.black26)
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ),
                  // Total
                  Expanded(
                    flex: 2,
                    child: Text(
                      totalStr,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: dur > Duration.zero
                            ? (isDark ? Colors.white70 : Colors.black87)
                            : (isDark ? Colors.white30 : Colors.black26),
                      ),
                    ),
                  ),
                  // Status badge
                  Expanded(
                    flex: 2,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: sColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          sLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: sColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
