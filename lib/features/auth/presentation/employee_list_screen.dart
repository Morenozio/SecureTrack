import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../auth/data/user_providers.dart';

class EmployeeListScreen extends ConsumerWidget {
  const EmployeeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Hilangkan orderBy di query untuk menghindari kebutuhan indeks komposit.
    // Kita akan urutkan di sisi klien agar tetap rapi tanpa memaksa konfigurasi indeks.
    final employeesStream = ref
        .watch(usersCollectionProvider)
        .where('role', isEqualTo: 'employee')
        .snapshots();
    final attendanceRepo = ref.watch(attendanceRepositoryProvider);

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
        title: const Text('Daftar Karyawan'),
      ),
      body: AppBackground(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: employeesStream,
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
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error: ${snapshot.error}',
                        style: textTheme.bodyLarge?.copyWith(
                          color: Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            final docs = snapshot.data?.docs ?? [];
            // Sort client-side by name untuk mempertahankan urutan alfabetis.
            docs.sort((a, b) {
              final aName = (a.data()['name'] ?? '').toString();
              final bName = (b.data()['name'] ?? '').toString();
              return aName.compareTo(bName);
            });
            if (docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 64,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Belum ada karyawan terdaftar',
                      style: textTheme.bodyLarge?.copyWith(
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data();
                final userId = doc.id;
                final name = data['name'] as String? ?? '-';
                final email = data['email'] as String? ?? '-';
                final contact = data['contact'] as String?;
                final deviceId = data['deviceId'] as String?;
                final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

                // Get today's attendance status
                final todayAttendanceStream = attendanceRepo.streamUserLogs(userId);

                return Card(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: todayAttendanceStream,
                    builder: (context, attendanceSnapshot) {
                      bool hasCheckInToday = false;
                      bool hasCheckOutToday = false;
                      DateTime? checkInTime;
                      DateTime? checkOutTime;

                      if (attendanceSnapshot.hasData) {
                        final attendanceDocs = attendanceSnapshot.data?.docs ?? [];
                        if (attendanceDocs.isNotEmpty) {
                          final latest = attendanceDocs.first.data();
                          final checkIn = (latest['checkIn'] as Timestamp?)?.toDate();
                          if (checkIn != null) {
                            final today = DateTime.now();
                            if (checkIn.year == today.year &&
                                checkIn.month == today.month &&
                                checkIn.day == today.day) {
                              hasCheckInToday = true;
                              checkInTime = checkIn;
                              checkOutTime = (latest['checkOut'] as Timestamp?)?.toDate();
                              hasCheckOutToday = checkOutTime != null;
                            }
                          }
                        }
                      }

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: hasCheckInToday
                              ? (hasCheckOutToday ? Colors.grey : Colors.green).withOpacity(0.15)
                              : Colors.blue.withOpacity(0.15),
                          child: Icon(
                            hasCheckInToday
                                ? (hasCheckOutToday ? Icons.check_circle_outline : Icons.radio_button_checked)
                                : Icons.person_outline,
                            color: hasCheckInToday
                                ? (hasCheckOutToday ? Colors.grey : Colors.green)
                                : Colors.blue,
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('Email: $email'),
                            if (contact != null && contact.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text('Kontak: $contact'),
                            ],
                            if (hasCheckInToday) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: hasCheckOutToday
                                      ? Colors.grey.withOpacity(0.2)
                                      : Colors.green.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  hasCheckOutToday
                                      ? '✓ Check-out: ${checkOutTime?.toString().split(' ')[1].substring(0, 5) ?? '-'}'
                                      : '● Masuk: ${checkInTime?.toString().split(' ')[1].substring(0, 5) ?? '-'}',
                                  style: TextStyle(
                                    color: hasCheckOutToday ? Colors.grey.shade700 : Colors.green.shade700,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ] else ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Belum check-in hari ini',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        isThreeLine: true,
                        onTap: () => context.push(
                          '/admin/employee-attendance/$userId?name=${Uri.encodeComponent(name)}',
                        ),
                        trailing: IconButton(
                          tooltip: 'Detail absensi',
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () => context.push(
                            '/admin/employee-attendance/$userId?name=${Uri.encodeComponent(name)}',
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

