import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/app_background.dart';
import '../../attendance/application/attendance_controller.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/data/work_schedule_repository.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/user_providers.dart';
import '../../leave/data/leave_repository.dart';

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
    final leaveRepo = ref.watch(leaveRepositoryProvider);
    final pendingLeavesStream = leaveRepo.streamPendingLeaves();

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
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: pendingLeavesStream,
                      builder: (context, pendingSnapshot) {
                        final pendingCount = pendingSnapshot.data?.docs.length ?? 0;
                        return _QuickAction(
                          label: 'Inbox Cuti',
                          icon: Icons.inbox,
                          badge: pendingCount > 0 ? pendingCount : null,
                          onTap: () => context.push('/admin/leave-inbox'),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            _TodayAttendanceSection(textTheme: textTheme, isDark: isDark),
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

class _TodayAttendanceSection extends ConsumerWidget {
  const _TodayAttendanceSection({
    required this.textTheme,
    required this.isDark,
  });

  final TextTheme textTheme;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendanceRepo = ref.watch(attendanceRepositoryProvider);
    final employeesStream = ref.watch(usersCollectionProvider)
        .where('role', isEqualTo: 'employee')
        .snapshots();

    return _SectionCard(
      title: 'Absensi Hari Ini',
      children: [
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: employeesStream,
          builder: (context, employeesSnapshot) {
            if (employeesSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final employees = employeesSnapshot.data?.docs ?? [];
            if (employees.isEmpty) {
              return const ListTile(
                title: Text('Belum ada karyawan'),
              );
            }

            return FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
              future: attendanceRepo.getTodayCheckIns(),
              builder: (context, checkInsSnapshot) {
                if (checkInsSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (checkInsSnapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red, size: 48),
                          const SizedBox(height: 8),
                          Text(
                            'Error: ${checkInsSnapshot.error}',
                            style: textTheme.bodyMedium?.copyWith(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final todayCheckIns = checkInsSnapshot.data ?? [];
                final checkedInUserIds = <String>{};
                for (final doc in todayCheckIns) {
                  try {
                    final userId = doc.data()['userId'] as String?;
                    if (userId != null) {
                      checkedInUserIds.add(userId);
                    }
                  } catch (e) {
                    // Skip invalid documents
                    continue;
                  }
                }

                // Get checked in employees
                final checkedInEmployees = employees.where((emp) {
                  final empId = emp.id;
                  return checkedInUserIds.contains(empId);
                }).toList();

                // Get absent employees (those who should work today but didn't check in)
                final absentEmployees = employees.where((emp) {
                  final empId = emp.id;
                  return !checkedInUserIds.contains(empId);
                }).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            color: Colors.green.withOpacity(0.1),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.green, size: 32),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${checkedInEmployees.length}',
                                    style: textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                  Text(
                                    'Sudah Check-in',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Card(
                            color: Colors.red.withOpacity(0.1),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  const Icon(Icons.person_off, color: Colors.red, size: 32),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${absentEmployees.length}',
                                    style: textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                  Text(
                                    'Belum Check-in',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Checked in list
                    if (checkedInEmployees.isNotEmpty) ...[
                      Text(
                        'Sudah Check-in (${checkedInEmployees.length})',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...checkedInEmployees.map((emp) {
                        final empData = emp.data();
                        final empName = empData['name'] ?? emp.id;
                        DateTime? checkInTime;
                        try {
                          if (todayCheckIns.isNotEmpty) {
                            final matchingDocs = todayCheckIns.where((doc) {
                              try {
                                return doc.data()['userId'] == emp.id;
                              } catch (e) {
                                return false;
                              }
                            }).toList();
                            
                            if (matchingDocs.isNotEmpty) {
                              final checkInDoc = matchingDocs.first;
                              checkInTime = (checkInDoc.data()['checkIn'] as Timestamp?)?.toDate();
                            }
                          }
                        } catch (e) {
                          checkInTime = null;
                        }
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: Colors.green.withOpacity(0.05),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green.withOpacity(0.2),
                              child: const Icon(Icons.check_circle, color: Colors.green),
                            ),
                            title: Text(
                              empName.toString(),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: checkInTime != null
                                ? Text(
                                    'Check-in: ${checkInTime.toString().split(' ')[1].substring(0, 5)}',
                                  )
                                : const Text('Check-in: -'),
                            trailing: IconButton(
                              icon: const Icon(Icons.schedule),
                              tooltip: 'Lihat Detail',
                              onPressed: () => context.push(
                                '/admin/employee-attendance/${emp.id}?name=${Uri.encodeComponent(empName.toString())}',
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],
                    // Absent list
                    if (absentEmployees.isNotEmpty) ...[
                      Text(
                        'Belum Check-in (${absentEmployees.length})',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...absentEmployees.take(10).map((emp) {
                        final empData = emp.data();
                        final empName = empData['name'] ?? emp.id;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: Colors.red.withOpacity(0.05),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.red.withOpacity(0.2),
                              child: const Icon(Icons.person_off, color: Colors.red),
                            ),
                            title: Text(
                              empName.toString(),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: const Text('Belum check-in hari ini'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.calendar_today, size: 20),
                                  tooltip: 'Atur Jadwal',
                                  onPressed: () => context.push(
                                    '/admin/work-schedule/${emp.id}?name=${Uri.encodeComponent(empName.toString())}',
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.schedule, size: 20),
                                  tooltip: 'Lihat Riwayat',
                                  onPressed: () => context.push(
                                    '/admin/employee-attendance/${emp.id}?name=${Uri.encodeComponent(empName.toString())}',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      if (absentEmployees.length > 10)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            '... dan ${absentEmployees.length - 10} lainnya',
                            style: textTheme.bodySmall?.copyWith(
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ),
                    ],
                    if (checkedInEmployees.isEmpty && absentEmployees.isEmpty)
                      const ListTile(
                        title: Text('Tidak ada data absensi hari ini'),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ],
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

class _AttendanceStatCard extends StatelessWidget {
  const _AttendanceStatCard({
    required this.title,
    required this.count,
    required this.total,
    required this.color,
    required this.icon,
  });

  final String title;
  final int count;
  final int total;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final percentage = total > 0 ? (count / total * 100).toStringAsFixed(0) : '0';

    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$count / $total',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              '$percentage%',
              style: textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.badge,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          OutlinedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 18),
            label: Text(label, textAlign: TextAlign.center),
          ),
          if (badge != null && badge! > 0)
            Positioned(
              top: -8,
              right: -8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 20,
                  minHeight: 20,
                ),
                child: Text(
                  badge! > 99 ? '99+' : badge.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

