import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../auth/data/user_providers.dart';
import '../application/leave_controller.dart';
import '../data/leave_repository.dart';
import '../../../core/widgets/animated_page.dart';
import '../../../core/widgets/app_background.dart';

/// Firestore ref to read monthly leave quota from app settings.
final _settingsDoc = FirebaseFirestore.instance
    .collection('settings')
    .doc('app_config');

class LeaveRequestScreen extends ConsumerStatefulWidget {
  const LeaveRequestScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  ConsumerState<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends ConsumerState<LeaveRequestScreen> {
  String type = 'Sakit';
  String notes = '';
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider).valueOrNull;
    final Stream<QuerySnapshot<Map<String, dynamic>>> leavesStream =
        user == null
        ? Stream<QuerySnapshot<Map<String, dynamic>>>.empty()
        : ref.watch(leaveRepositoryProvider).streamMyLeave(user.id);
    final leaveState = ref.watch(leaveControllerProvider);

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    context.go('/dashboard/employee');
                  }
                },
              ),
              title: const Text('Permohonan Cuti'),
            )
          : null,
      body: AnimatedPage(
        child: AppBackground(
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _settingsDoc.snapshots(),
            builder: (context, settingsSnap) {
              final int monthlyQuota =
                  (settingsSnap.data?.data()?['monthlyLeaveQuota'] as int?) ??
                  12;

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: leavesStream,
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? [];

                  // Sort by createdAt descending
                  final sortedDocs = docs.toList()
                    ..sort((a, b) {
                      final aTime = (a.data()['createdAt'] as Timestamp?)
                          ?.toDate();
                      final bTime = (b.data()['createdAt'] as Timestamp?)
                          ?.toDate();
                      if (aTime == null && bTime == null) return 0;
                      if (aTime == null) return 1;
                      if (bTime == null) return -1;
                      return bTime.compareTo(aTime);
                    });

                  // Calculate approved leaves this month
                  final now = DateTime.now();
                  final monthStart = DateTime(now.year, now.month, 1);
                  final monthEnd = DateTime(now.year, now.month + 1, 1);
                  int usedThisMonth = 0;
                  for (final d in docs) {
                    final data = d.data();
                    final status = data['status'] as String? ?? '';
                    final created = (data['createdAt'] as Timestamp?)?.toDate();
                    if (created != null &&
                        !created.isBefore(monthStart) &&
                        created.isBefore(monthEnd) &&
                        (status == 'Diterima' || status == 'Menunggu')) {
                      // Count days between start and end dates
                      final s = (data['startDate'] as Timestamp?)?.toDate();
                      final e = (data['endDate'] as Timestamp?)?.toDate();
                      if (s != null && e != null) {
                        usedThisMonth += e.difference(s).inDays + 1;
                      } else {
                        usedThisMonth += 1;
                      }
                    }
                  }
                  final remaining = (monthlyQuota - usedThisMonth).clamp(
                    0,
                    monthlyQuota,
                  );

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    children: [
                      // ─── Leave Balance Card ───
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withOpacity(0.12),
                              AppColors.primary.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'SISA JATAH BULAN INI',
                                    style: textTheme.labelSmall?.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: '$remaining',
                                          style: textTheme.headlineLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.black87,
                                              ),
                                        ),
                                        TextSpan(
                                          text: ' / $monthlyQuota Hari',
                                          style: textTheme.titleSmall?.copyWith(
                                            color: isDark
                                                ? Colors.white60
                                                : Colors.black45,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Terpakai: $usedThisMonth hari',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.black45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.event_available,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ─── Request Form ───
                      Text(
                        'Ajukan Cuti',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Date pickers
                      Row(
                        children: [
                          Expanded(
                            child: _DateField(
                              label: 'Tanggal Mulai',
                              value: _startDate,
                              isDark: isDark,
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _startDate ?? DateTime.now(),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );
                                if (picked != null) {
                                  setState(() => _startDate = picked);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _DateField(
                              label: 'Tanggal Selesai',
                              value: _endDate,
                              isDark: isDark,
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      _endDate ??
                                      (_startDate ?? DateTime.now()),
                                  firstDate: _startDate ?? DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );
                                if (picked != null) {
                                  setState(() => _endDate = picked);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Leave type
                      _FormCard(
                        isDark: isDark,
                        child: DropdownButtonFormField<String>(
                          value: type,
                          items: const [
                            DropdownMenuItem(
                              value: 'Sakit',
                              child: Text('Sakit'),
                            ),
                            DropdownMenuItem(
                              value: 'Cuti',
                              child: Text('Cuti Tahunan'),
                            ),
                            DropdownMenuItem(
                              value: 'Pribadi',
                              child: Text('Keperluan Pribadi'),
                            ),
                            DropdownMenuItem(
                              value: 'Tanpa Bayar',
                              child: Text('Cuti Tanpa Bayar'),
                            ),
                          ],
                          onChanged: (v) => setState(() => type = v ?? 'Sakit'),
                          decoration: const InputDecoration(
                            labelText: 'Jenis Cuti',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Notes
                      _FormCard(
                        isDark: isDark,
                        child: TextField(
                          controller: _notesController,
                          decoration: const InputDecoration(
                            labelText: 'Alasan / Catatan',
                            hintText:
                                'Masukkan alasan atau detail permohonan cuti...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          maxLines: 4,
                          onChanged: (v) => setState(() => notes = v),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 3,
                          ),
                          onPressed:
                              user == null ||
                                  leaveState.isLoading ||
                                  _startDate == null ||
                                  _endDate == null
                              ? null
                              : () async {
                                  try {
                                    await ref
                                        .read(leaveControllerProvider.notifier)
                                        .submit(
                                          user,
                                          type: type,
                                          notes: notes,
                                          startDate: _startDate!,
                                          endDate: _endDate!,
                                        );
                                    if (!mounted) return;
                                    setState(() {
                                      type = 'Sakit';
                                      notes = '';
                                      _startDate = null;
                                      _endDate = null;
                                    });
                                    _notesController.clear();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Permohonan cuti berhasil dikirim!',
                                        ),
                                        backgroundColor: Colors.green,
                                        duration: Duration(seconds: 3),
                                      ),
                                    );
                                  } catch (e) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                          child: leaveState.isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Text(
                                      'Kirim Permohonan',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(Icons.send, size: 18),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ─── Recent Requests ───
                      Text(
                        'RIWAYAT PERMOHONAN',
                        style: textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (snapshot.connectionState == ConnectionState.waiting)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (snapshot.hasError)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: Colors.red,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Error: ${snapshot.error}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (sortedDocs.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.event_busy,
                                  size: 48,
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.black26,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Belum ada permohonan cuti',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.black45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...sortedDocs.map((d) {
                          final data = d.data();
                          return _LeaveHistoryCard(
                            data: data,
                            isDark: isDark,
                            textTheme: textTheme,
                          );
                        }),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  Reusable Widgets
// ────────────────────────────────────────────────────────────

/// Date field card
class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final bool isDark;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.value,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.grey.shade200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  value != null
                      ? DateFormat('dd MMM yyyy').format(value!)
                      : 'Pilih tanggal',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: value != null
                        ? (isDark ? Colors.white : Colors.black87)
                        : (isDark ? Colors.white38 : Colors.black38),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Form card wrapper
class _FormCard extends StatelessWidget {
  final bool isDark;
  final Widget child;

  const _FormCard({required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
        ),
      ),
      child: child,
    );
  }
}

/// Leave history card
class _LeaveHistoryCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isDark;
  final TextTheme textTheme;

  const _LeaveHistoryCard({
    required this.data,
    required this.isDark,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final type = data['type'] ?? '-';
    final status = data['status'] ?? '-';
    final notes = data['notes'] as String? ?? '';
    final adminNotes = data['adminNotes'] as String?;
    final startDate = (data['startDate'] as Timestamp?)?.toDate();
    final endDate = (data['endDate'] as Timestamp?)?.toDate();
    final df = DateFormat('dd MMM');

    Color statusColor;
    IconData statusIcon;
    String statusLabel;
    switch (status) {
      case 'Diterima':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusLabel = 'DITERIMA';
        break;
      case 'Ditolak':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusLabel = 'DITOLAK';
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_top;
        statusLabel = 'MENUNGGU';
    }

    final dateRange = (startDate != null && endDate != null)
        ? '${df.format(startDate)} - ${df.format(endDate)}'
        : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade100,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateRange,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          // Expandable detail
          if (notes.isNotEmpty ||
              (adminNotes != null && adminNotes.isNotEmpty)) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.04)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (notes.isNotEmpty) ...[
                    Text(notes, style: textTheme.bodySmall),
                  ],
                  if (adminNotes != null && adminNotes.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Admin: $adminNotes',
                      style: textTheme.bodySmall?.copyWith(
                        color: statusColor,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
