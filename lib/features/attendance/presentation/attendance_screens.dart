import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../attendance/application/attendance_controller.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../auth/data/user_providers.dart';

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.valueOrNull;
    final Stream<QuerySnapshot<Map<String, dynamic>>> logsStream = user == null
        ? Stream<QuerySnapshot<Map<String, dynamic>>>.empty()
        : ref.watch(attendanceRepositoryProvider).streamUserLogs(user.id);

    return Scaffold(
      appBar: AppBar(
        leading: context.canPop() ? const BackButton() : null,
        title: const Text('Absensi'),
        actions: [
          IconButton(
            tooltip: 'Riwayat',
            onPressed: () => context.push('/attendance/history'),
            icon: const Icon(Icons.history),
          ),
        ],
      ),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            userAsync.when(
              data: (u) => Text(
                u == null ? 'Tidak ada data user' : 'Halo, ${u.name}',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : null,
                ),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error user: $e'),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Check-in / Check-out', style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : null,
                    )),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: user == null
                                ? null
                                : () async {
                                    await ref.read(attendanceControllerProvider.notifier).checkIn(user);
                                  },
                            icon: const Icon(Icons.login),
                            label: const Text('Check-in'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: user == null
                                ? null
                                : () async {
                                    await ref.read(attendanceControllerProvider.notifier).checkOut(user);
                                  },
                            icon: const Icon(Icons.logout),
                            label: const Text('Check-out'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Log Absensi', style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : null,
                    )),
                    const SizedBox(height: 8),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: logsStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(8),
                            child: LinearProgressIndicator(),
                          );
                        }
                        final docs = snapshot.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return const ListTile(
                            title: Text('Belum ada data absensi'),
                          );
                        }
                        return Column(
                          children: docs.map((d) {
                            final data = d.data();
                            final checkIn = (data['checkIn'] as Timestamp?)?.toDate();
                            final checkOut = (data['checkOut'] as Timestamp?)?.toDate();
                            final method = data['method'] ?? '-';
                            return ListTile(
                              leading: const Icon(Icons.access_time),
                              title: Text('Metode: $method'),
                              subtitle: Text('In: ${checkIn ?? '-'}\nOut: ${checkOut ?? '-'}'),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AttendanceHistoryScreen extends ConsumerWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final Stream<QuerySnapshot<Map<String, dynamic>>> logsStream = user == null
        ? Stream<QuerySnapshot<Map<String, dynamic>>>.empty()
        : ref.watch(attendanceRepositoryProvider).streamUserLogs(user.id);
    return Scaffold(
      appBar: AppBar(
        leading: context.canPop() ? const BackButton() : null,
        title: const Text('Riwayat Absensi'),
      ),
      body: AppBackground(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: logsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LinearProgressIndicator();
            }
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Center(child: Text('Belum ada data absensi'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final data = docs[index].data();
                final checkIn = (data['checkIn'] as Timestamp?)?.toDate();
                final checkOut = (data['checkOut'] as Timestamp?)?.toDate();
                final method = data['method'] ?? '-';
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.accent.withOpacity(0.15),
                      child: const Icon(Icons.wifi_lock, color: AppColors.accent),
                    ),
                    title: Text('Metode: $method'),
                    subtitle: Text('In: ${checkIn ?? '-'}\nOut: ${checkOut ?? '-'}'),
                    isThreeLine: true,
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemCount: docs.length,
            );
          },
        ),
      ),
    );
  }
}

class QrBackupScreen extends StatelessWidget {
  const QrBackupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        leading: context.canPop() ? const BackButton() : null,
        title: const Text('QR Backup Mode'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Aktif karena WiFi & GPS gagal', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(
              'Admin harus membuat QR time-limited. Pemindaian akan mencatat device ID, timestamp, admin ID, dan alasan fallback.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Center(
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.accent.withOpacity(0.4)),
                  ),
                  child: const Center(
                    child: Icon(Icons.qr_code_2, size: 120, color: AppColors.accent),
                  ),
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Pemindaian QR (stub). Integrasikan scanner & token signature.')),
                );
                context.go('/attendance');
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan QR'),
            ),
          ],
        ),
      ),
    );
  }
}

