import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/app_background.dart';
import '../../attendance/application/attendance_controller.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/user_providers.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userAsync = ref.watch(currentUserProvider);
    final attendanceRepo = ref.watch(attendanceRepositoryProvider);
    final recentLogs = attendanceRepo.streamRecentLogs();
    final employeesStream =
        ref.watch(usersCollectionProvider).where('role', isEqualTo: 'employee').snapshots();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: context.canPop() ? const BackButton() : null,
        title: const Text('Dashboard Admin'),
        actions: [
          IconButton(
            tooltip: 'Ganti Tema',
            onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
          ),
          IconButton(
            tooltip: 'Keluar',
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).signOut();
              if (context.mounted) context.go('/auth');
            },
            icon: const Icon(Icons.logout),
          ),
          IconButton(
            tooltip: 'Profil',
            onPressed: () => context.go('/profile'),
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            userAsync.when(
              data: (user) => Text(
                user == null ? 'Tidak ada data user' : 'Halo, ${user.name} (Admin)',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : null,
                ),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error user: $e'),
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: employeesStream,
              builder: (context, snapshot) {
                final employeesCount = snapshot.data?.docs.length ?? 0;
                final allUsersStream = ref.watch(usersCollectionProvider).snapshots();
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: allUsersStream,
                  builder: (context, allUsersSnapshot) {
                    final allUsersCount = allUsersSnapshot.data?.docs.length ?? 0;
                    final adminsCount = allUsersCount - employeesCount;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _StatCard(
                          title: 'Total User',
                          value: '$allUsersCount',
                          icon: Icons.people,
                        ),
                        _StatCard(
                          title: 'Admin',
                          value: '$adminsCount',
                          icon: Icons.admin_panel_settings,
                        ),
                        _StatCard(
                          title: 'Karyawan',
                          value: '$employeesCount',
                          icon: Icons.person,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Tindakan Cepat',
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _QuickAction(
                      label: 'Tambah Karyawan',
                      icon: Icons.person_add_alt,
                      onTap: () => context.push('/admin/add-employee'),
                    ),
                    _QuickAction(
                      label: 'Daftar Karyawan',
                      icon: Icons.people,
                      onTap: () => context.push('/admin/employees'),
                    ),
                    _QuickAction(
                      label: 'Kelola WiFi Networks',
                      icon: Icons.wifi,
                      onTap: () => context.push('/admin/wifi-networks'),
                    ),
                    _QuickAction(
                      label: 'Kelola User',
                      icon: Icons.admin_panel_settings,
                      onTap: () => context.push('/admin/users'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Monitoring Absensi Terbaru',
              children: [
                // Ambil peta userId -> nama untuk menampilkan nama karyawan di log.
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: ref.watch(usersCollectionProvider).snapshots(),
                  builder: (context, usersSnapshot) {
                    final userDocs = usersSnapshot.data?.docs ?? [];
                    final Map<String, String> userNameById = {
                      for (final doc in userDocs)
                        doc.id: (doc.data()['name'] ?? doc.id).toString(),
                    };

                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: recentLogs,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: LinearProgressIndicator(),
                          );
                        }
                        final docs = snapshot.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return const ListTile(
                            title: Text('Belum ada log absensi'),
                          );
                        }
                        return Column(
                          children: docs.map((d) {
                            final data = d.data();
                            final userId = data['userId'] ?? '-';
                            final userName = userNameById[userId] ?? userId.toString();
                            final checkIn = (data['checkIn'] as Timestamp?)?.toDate();
                            final checkOut = (data['checkOut'] as Timestamp?)?.toDate();
                            final method = data['method'] ?? '-';
                            return ListTile(
                              leading: const Icon(Icons.schedule),
                              title: Text('User: $userName'),
                              subtitle: Text(
                                'In: ${checkIn ?? '-'}\nOut: ${checkOut ?? '-'}\nMetode: $method',
                              ),
                            );
                          }).toList(),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class EmployeeDashboardScreen extends ConsumerWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.valueOrNull;
    final attendanceRepo = ref.watch(attendanceRepositoryProvider);
    final Stream<QuerySnapshot<Map<String, dynamic>>> logsStream = user == null
        ? Stream<QuerySnapshot<Map<String, dynamic>>>.empty()
        : attendanceRepo.streamUserLogs(user.id);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
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
        title: const Text('Dashboard Karyawan'),
        actions: [
          IconButton(
            tooltip: 'Ganti Tema',
            onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
          ),
          IconButton(
            tooltip: 'Keluar',
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).signOut();
              if (context.mounted) context.go('/auth');
            },
            icon: const Icon(Icons.logout),
          ),
          IconButton(
            tooltip: 'Profil',
            onPressed: () => context.go('/profile'),
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            userAsync.when(
              data: (u) => Text(
                u == null ? 'Tidak ada data' : 'Halo, ${u.name}',
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
                    Row(
                      children: [
                        const Icon(Icons.verified_user, color: AppColors.accent),
                        const SizedBox(width: 8),
                        Text('Status kehadiran', style: textTheme.titleMedium?.copyWith(
                          color: isDark ? Colors.white : null,
                        )),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: user == null
                                ? null
                                : () => context.push('/attendance'),
                            icon: const Icon(Icons.login),
                            label: const Text('Check-in'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: user == null
                                ? null
                                : () => context.push('/attendance'),
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
            _SectionCard(
              title: 'Tindakan Cepat',
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _QuickAction(
                      label: 'Riwayat Absensi',
                      icon: Icons.history,
                      onTap: () => context.push('/attendance/history'),
                    ),
                    _QuickAction(
                      label: 'Ajukan Cuti',
                      icon: Icons.beach_access,
                      onTap: () => context.push('/leave'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Log Absensi Saya',
              children: [
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
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = color ?? (isDark ? AppColors.accent : AppColors.navy);
    final textColor = isDark ? Colors.white : null;
    return SizedBox(
      width: 170,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: fg),
              const SizedBox(height: 10),
              Text(title, style: textTheme.bodyMedium?.copyWith(color: textColor)),
              const SizedBox(height: 4),
              Text(
                value,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}

