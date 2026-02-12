import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/animated_page.dart';
import '../data/attendance_repository.dart';
import '../../auth/data/user_providers.dart';

class AttendanceManagementScreen extends ConsumerStatefulWidget {
  const AttendanceManagementScreen({super.key});

  @override
  ConsumerState<AttendanceManagementScreen> createState() =>
      _AttendanceManagementScreenState();
}

class _AttendanceManagementScreenState
    extends ConsumerState<AttendanceManagementScreen> {
  DateTime _selectedDate = DateTime.now();
  String _departmentFilter = 'All';
  String _statusFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final attendanceRepo = ref.watch(attendanceRepositoryProvider);
    final employeesStream = ref
        .watch(usersCollectionProvider)
        .where('role', isEqualTo: 'employee')
        .snapshots();

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
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
        title: const Text('Attendance Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export CSV',
            onPressed: () => _exportCsv(context),
          ),
        ],
      ),
      body: AnimatedPage(
        child: Column(
          children: [
            // ─── Filter Bar ───
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? AppColors.primary.withOpacity(0.1)
                        : Colors.grey.shade200,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // Date picker row
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _pickDate(context),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.backgroundDark
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? AppColors.primary.withOpacity(0.1)
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              DateFormat(
                                'EEEE, MMM dd, yyyy',
                              ).format(_selectedDate),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Department + Status row
                  Row(
                    children: [
                      // Department
                      Expanded(
                        child:
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: employeesStream,
                              builder: (context, snap) {
                                final departments = <String>{'All'};
                                if (snap.hasData) {
                                  for (final doc in snap.data!.docs) {
                                    final dept =
                                        doc.data()['department'] as String?;
                                    if (dept != null && dept.isNotEmpty) {
                                      departments.add(dept);
                                    }
                                  }
                                }
                                return _FilterDropdown(
                                  value: _departmentFilter,
                                  items: departments.toList(),
                                  prefix: 'Dept: ',
                                  isDark: isDark,
                                  onChanged: (v) => setState(
                                    () => _departmentFilter = v ?? 'All',
                                  ),
                                );
                              },
                            ),
                      ),
                      const SizedBox(width: 12),
                      // Status
                      Expanded(
                        child: _FilterDropdown(
                          value: _statusFilter,
                          items: const [
                            'All',
                            'Present',
                            'Late',
                            'Absent',
                            'On Leave',
                          ],
                          prefix: 'Status: ',
                          isDark: isDark,
                          onChanged: (v) =>
                              setState(() => _statusFilter = v ?? 'All'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ─── Attendance Table ───
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: employeesStream,
                builder: (context, empSnapshot) {
                  if (empSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final employees = empSnapshot.data?.docs ?? [];

                  // Filter by department
                  final filteredEmployees = _departmentFilter == 'All'
                      ? employees
                      : employees.where((d) {
                          return d.data()['department'] == _departmentFilter;
                        }).toList();

                  if (filteredEmployees.isEmpty) {
                    return Center(
                      child: Text(
                        'No employees found',
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                    );
                  }

                  return FutureBuilder<
                    List<QueryDocumentSnapshot<Map<String, dynamic>>>
                  >(
                    future: attendanceRepo.getTodayCheckIns(),
                    builder: (context, checkInSnap) {
                      final todayLogs = checkInSnap.data ?? [];

                      // Build a map of userId → attendance data
                      final Map<String, Map<String, dynamic>> attendanceByUser =
                          {};
                      for (final log in todayLogs) {
                        final data = log.data();
                        final userId = data['userId'] as String?;
                        final checkIn = (data['checkIn'] as Timestamp?)
                            ?.toDate();
                        if (userId != null && checkIn != null) {
                          // Only include logs for selected date
                          if (checkIn.year == _selectedDate.year &&
                              checkIn.month == _selectedDate.month &&
                              checkIn.day == _selectedDate.day) {
                            attendanceByUser[userId] = data;
                          }
                        }
                      }

                      // Build rows
                      final rows = <_AttendanceRow>[];
                      for (final emp in filteredEmployees) {
                        final empData = emp.data();
                        final userId = emp.id;
                        final name = empData['name'] as String? ?? '-';
                        final dept = empData['department'] as String? ?? '';
                        final att = attendanceByUser[userId];

                        String status;
                        DateTime? checkIn;
                        DateTime? checkOut;

                        if (att != null) {
                          checkIn = (att['checkIn'] as Timestamp?)?.toDate();
                          checkOut = (att['checkOut'] as Timestamp?)?.toDate();
                          if (checkIn != null &&
                              checkIn.hour >= 9 &&
                              checkIn.minute > 0) {
                            status = 'Late';
                          } else {
                            status = 'Present';
                          }
                        } else {
                          status = 'Absent';
                        }

                        // Check if on leave
                        // (simplified — checks leave collection)
                        // For now just use attendance data

                        rows.add(
                          _AttendanceRow(
                            userId: userId,
                            name: name,
                            department: dept,
                            status: status,
                            checkIn: checkIn,
                            checkOut: checkOut,
                          ),
                        );
                      }

                      // Apply status filter
                      final displayRows = _statusFilter == 'All'
                          ? rows
                          : rows
                                .where((r) => r.status == _statusFilter)
                                .toList();

                      // Count summary
                      final presentCount = rows
                          .where((r) => r.status == 'Present')
                          .length;
                      final lateCount = rows
                          .where((r) => r.status == 'Late')
                          .length;
                      final absentCount = rows
                          .where((r) => r.status == 'Absent')
                          .length;

                      return Column(
                        children: [
                          // Summary bar
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                _SummaryChip(
                                  label: 'Present',
                                  count: presentCount,
                                  color: AppColors.success,
                                  isDark: isDark,
                                ),
                                const SizedBox(width: 8),
                                _SummaryChip(
                                  label: 'Late',
                                  count: lateCount,
                                  color: AppColors.warning,
                                  isDark: isDark,
                                ),
                                const SizedBox(width: 8),
                                _SummaryChip(
                                  label: 'Absent',
                                  count: absentCount,
                                  color: AppColors.danger,
                                  isDark: isDark,
                                ),
                                const Spacer(),
                                Text(
                                  '${displayRows.length} shown',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // List
                          Expanded(
                            child: displayRows.isEmpty
                                ? Center(
                                    child: Text(
                                      'No records match filter',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    physics: const BouncingScrollPhysics(),
                                    cacheExtent: 1000,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    itemCount: displayRows.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      final row = displayRows[index];
                                      return _AttendanceRowCard(
                                        row: row,
                                        isDark: isDark,
                                        onTap: () => context.push(
                                          '/admin/employee-attendance/${row.userId}?name=${Uri.encodeComponent(row.name)}',
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _exportCsv(BuildContext context) {
    // Build CSV from current state — simplified clipboard export
    final sb = StringBuffer();
    sb.writeln('Name,Department,Status,Check In,Check Out');
    // Note: For a real export we'd need to rebuild the data.
    // This is a placeholder that copies column headers.
    Clipboard.setData(ClipboardData(text: sb.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('CSV headers copied to clipboard'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
//  Data models & Widgets
// ──────────────────────────────────────────────────────────

class _AttendanceRow {
  final String userId;
  final String name;
  final String department;
  final String status;
  final DateTime? checkIn;
  final DateTime? checkOut;

  _AttendanceRow({
    required this.userId,
    required this.name,
    required this.department,
    required this.status,
    this.checkIn,
    this.checkOut,
  });
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.value,
    required this.items,
    required this.prefix,
    required this.isDark,
    required this.onChanged,
  });

  final String value;
  final List<String> items;
  final String prefix;
  final bool isDark;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.backgroundDark : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.expand_more, size: 18),
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white : Colors.grey.shade800,
          ),
          dropdownColor: isDark ? AppColors.cardDark : Colors.white,
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item == 'All' ? '$prefix All' : item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.count,
    required this.color,
    required this.isDark,
  });

  final String label;
  final int count;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$count $label',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceRowCard extends StatelessWidget {
  const _AttendanceRowCard({
    required this.row,
    required this.isDark,
    required this.onTap,
  });

  final _AttendanceRow row;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    IconData statusIcon;
    switch (row.status) {
      case 'Present':
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle;
        break;
      case 'Late':
        statusColor = AppColors.warning;
        statusIcon = Icons.schedule;
        break;
      case 'On Leave':
        statusColor = Colors.blue;
        statusIcon = Icons.flight;
        break;
      default:
        statusColor = AppColors.danger;
        statusIcon = Icons.cancel;
    }

    final checkInStr = row.checkIn != null
        ? DateFormat('hh:mm a').format(row.checkIn!)
        : '--:--';
    final checkOutStr = row.checkOut != null
        ? DateFormat('hh:mm a').format(row.checkOut!)
        : '--:--';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? AppColors.primary.withOpacity(0.1)
                  : Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              // Status icon
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, size: 18, color: statusColor),
              ),
              const SizedBox(width: 12),
              // Name + department
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (row.department.isNotEmpty)
                      Text(
                        row.department,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade500,
                        ),
                      ),
                  ],
                ),
              ),
              // Time column
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    checkInStr,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.grey.shade800,
                    ),
                  ),
                  Text(
                    checkOutStr,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  row.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
