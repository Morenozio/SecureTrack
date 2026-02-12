import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/animated_page.dart';
import '../../../core/widgets/app_background.dart';
import '../data/attendance_repository.dart';
import '../../auth/data/user_providers.dart';

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
        title: Text('Absensi ${widget.userName}'),
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
                return const LinearProgressIndicator();
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 64,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                        const SizedBox(height: 12),
                        const Text('Belum ada data absensi'),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _addManualLog,
                          icon: const Icon(Icons.add),
                          label: const Text('Tambah manual'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  if (_isSaving) const LinearProgressIndicator(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Total log: ${docs.length}',
                          style: textTheme.bodyMedium,
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: () => _exportCsv(docs),
                          icon: const Icon(Icons.file_download),
                          label: const Text('Export CSV'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final data = docs[index].data();
                        final logId = docs[index].id;
                        final checkIn = (data['checkIn'] as Timestamp?)
                            ?.toDate();
                        final checkOut = (data['checkOut'] as Timestamp?)
                            ?.toDate();
                        final ssid = data['wifiSsid'] as String?;
                        final bssid = data['wifiBssid'] as String?;
                        final status = (data['status'] ?? '') as String;
                        final duration = _duration(checkIn, checkOut);

                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.accent.withOpacity(
                                0.15,
                              ),
                              child: const Icon(
                                Icons.access_time,
                                color: AppColors.accent,
                              ),
                            ),
                            title: Text(
                              _formatDateTime(checkIn),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text('Check-out: ${_formatDateTime(checkOut)}'),
                                if (ssid != null && ssid.isNotEmpty)
                                  Text('SSID: $ssid'),
                                if (bssid != null && bssid.isNotEmpty)
                                  Text('BSSID: $bssid'),
                                Text(
                                  'Durasi: ${duration.inHours}h ${duration.inMinutes.remainder(60)}m',
                                ),
                                if (status.isNotEmpty) Text('Status: $status'),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: IconButton(
                              tooltip: 'Edit',
                              onPressed: () => _editLog(logId, data),
                              icon: const Icon(Icons.edit),
                            ),
                          ),
                        );
                      },
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
