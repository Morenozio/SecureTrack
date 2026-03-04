import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/constants/app_colors.dart';
import '../../auth/data/user_providers.dart';
import '../data/attendance_repository.dart';
import '../data/attendance_status.dart';
import '../data/work_schedule_model.dart';
import '../data/work_schedule_repository.dart';

class AttendanceCalendarScreen extends ConsumerStatefulWidget {
  const AttendanceCalendarScreen({super.key});

  @override
  ConsumerState<AttendanceCalendarScreen> createState() =>
      _AttendanceCalendarScreenState();
}

class _AttendanceCalendarScreenState
    extends ConsumerState<AttendanceCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  // Color mapping for attendance statuses
  static const Map<AttendanceStatus, Color> _statusColors = {
    AttendanceStatus.checkedOut: Color(0xFF10B981), // emerald
    AttendanceStatus.checkedIn: Color(0xFF3B82F6), // blue
    AttendanceStatus.late: Color(0xFFF59E0B), // amber
    AttendanceStatus.absent: Color(0xFFEF4444), // red
    AttendanceStatus.overtime: Color(0xFF8B5CF6), // purple
    AttendanceStatus.earlyLeave: Color(0xFFF59E0B), // amber
    AttendanceStatus.notCheckedIn: Color(0xFF6B7280), // grey
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider).valueOrNull;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final logsStream = ref
        .read(attendanceRepositoryProvider)
        .streamUserLogs(user.id);

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      body: SafeArea(
        child: StreamBuilder<WorkSchedule>(
          stream: ref
              .read(workScheduleRepositoryProvider)
              .streamEmployeeSchedule(user.id),
          builder: (context, scheduleSnapshot) {
            final workSchedule = scheduleSnapshot.data;

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: logsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Parse attendance data
                final docs = snapshot.data?.docs ?? [];
                final Map<DateTime, List<Map<String, dynamic>>> attendanceMap =
                    {};

                for (final doc in docs) {
                  final data = doc.data();
                  final checkIn = (data['checkIn'] as Timestamp?)?.toDate();
                  if (checkIn != null) {
                    final dateKey = DateTime(
                      checkIn.year,
                      checkIn.month,
                      checkIn.day,
                    );
                    attendanceMap.putIfAbsent(dateKey, () => []);
                    attendanceMap[dateKey]!.add(data);
                  }
                }

                // Compute monthly stats
                final monthStart = DateTime(
                  _focusedDay.year,
                  _focusedDay.month,
                  1,
                );
                final monthEnd = DateTime(
                  _focusedDay.year,
                  _focusedDay.month + 1,
                  0,
                );
                int presentCount = 0;
                int lateCount = 0;
                int absentCount = 0;

                for (
                  var d = monthStart;
                  !d.isAfter(monthEnd);
                  d = d.add(const Duration(days: 1))
                ) {
                  final key = DateTime(d.year, d.month, d.day);
                  final records = attendanceMap[key];
                  if (records != null && records.isNotEmpty) {
                    final status = AttendanceStatus.fromString(
                      records.first['status'] as String?,
                    );
                    if (status == AttendanceStatus.late ||
                        status == AttendanceStatus.earlyLeave) {
                      lateCount++;
                    } else if (status == AttendanceStatus.absent) {
                      absentCount++;
                    } else if (status == AttendanceStatus.checkedOut ||
                        status == AttendanceStatus.checkedIn ||
                        status == AttendanceStatus.overtime) {
                      presentCount++;
                    }
                  }
                }

                // Get today's record for the schedule card
                final todayKey = DateTime(
                  DateTime.now().year,
                  DateTime.now().month,
                  DateTime.now().day,
                );
                final todayRecords = attendanceMap[todayKey];

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── Calendar Section ───
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // Month navigation
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    setState(() {
                                      _focusedDay = DateTime(
                                        _focusedDay.year,
                                        _focusedDay.month - 1,
                                        1,
                                      );
                                    });
                                  },
                                  icon: const Icon(Icons.chevron_left),
                                ),
                                Text(
                                  DateFormat('MMMM yyyy').format(_focusedDay),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    setState(() {
                                      _focusedDay = DateTime(
                                        _focusedDay.year,
                                        _focusedDay.month + 1,
                                        1,
                                      );
                                    });
                                  },
                                  icon: const Icon(Icons.chevron_right),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Calendar with dot indicators
                            TableCalendar(
                              firstDay: DateTime(2024, 1, 1),
                              lastDay: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                              focusedDay: _focusedDay,
                              selectedDayPredicate: (day) =>
                                  isSameDay(_selectedDay, day),
                              calendarFormat: _calendarFormat,
                              availableCalendarFormats: const {
                                CalendarFormat.month: 'Month',
                              },
                              onDaySelected: (selectedDay, focusedDay) {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  _selectedDay = selectedDay;
                                  _focusedDay = focusedDay;
                                });
                                // Show detail bottom sheet
                                final dateKey = DateTime(
                                  selectedDay.year,
                                  selectedDay.month,
                                  selectedDay.day,
                                );
                                final records = attendanceMap[dateKey];
                                _showDayDetail(
                                  context,
                                  selectedDay,
                                  records,
                                  isDark,
                                );
                              },
                              onPageChanged: (focusedDay) {
                                setState(() => _focusedDay = focusedDay);
                              },
                              startingDayOfWeek: StartingDayOfWeek.sunday,
                              headerVisible: false,
                              daysOfWeekStyle: DaysOfWeekStyle(
                                weekdayStyle: TextStyle(
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade500,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                                weekendStyle: TextStyle(
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade500,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              calendarStyle: const CalendarStyle(
                                outsideDaysVisible: false,
                                cellMargin: EdgeInsets.all(2),
                              ),
                              calendarBuilders: CalendarBuilders(
                                defaultBuilder: (context, day, focusedDay) {
                                  return _buildDayCell(
                                    day,
                                    attendanceMap,
                                    isDark,
                                    false,
                                    false,
                                    workSchedule,
                                  );
                                },
                                todayBuilder: (context, day, focusedDay) {
                                  return _buildDayCell(
                                    day,
                                    attendanceMap,
                                    isDark,
                                    true,
                                    false,
                                    workSchedule,
                                  );
                                },
                                selectedBuilder: (context, day, focusedDay) {
                                  return _buildDayCell(
                                    day,
                                    attendanceMap,
                                    isDark,
                                    false,
                                    true,
                                    workSchedule,
                                  );
                                },
                              ),
                            ),

                            // Legend
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.only(top: 16),
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color: AppColors.primary.withAlpha(25),
                                  ),
                                ),
                              ),
                              child: Wrap(
                                spacing: 16,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: const [
                                  _LegendDot(
                                    color: Color(0xFF10B981),
                                    label: 'Present',
                                  ),
                                  _LegendDot(
                                    color: Color(0xFFEF4444),
                                    label: 'Absent',
                                  ),
                                  _LegendDot(
                                    color: Color(0xFF3B82F6),
                                    label: 'On Leave',
                                  ),
                                  _LegendDot(
                                    color: Color(0xFFF59E0B),
                                    label: 'Late',
                                  ),
                                  _LegendDot(
                                    color: Color(0xFF9CA3AF),
                                    label: 'Scheduled',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ─── Today's Schedule Card ───
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Today's Schedule",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildTodayScheduleCard(isDark, todayRecords),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ─── Monthly Stats ───
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Monthly Stats',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _StatCard(
                                    value: presentCount.toString(),
                                    label: 'Present',
                                    color: const Color(0xFF10B981),
                                    isDark: isDark,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _StatCard(
                                    value: lateCount.toString(),
                                    label: 'Late',
                                    color: const Color(0xFFF59E0B),
                                    isDark: isDark,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _StatCard(
                                    value: absentCount.toString(),
                                    label: 'Absent',
                                    color: const Color(0xFFEF4444),
                                    isDark: isDark,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ─── Day Cell Builder (dot indicator below number) ───
  Widget _buildDayCell(
    DateTime day,
    Map<DateTime, List<Map<String, dynamic>>> attendanceMap,
    bool isDark,
    bool isToday,
    bool isSelected,
    WorkSchedule? workSchedule,
  ) {
    final dateKey = DateTime(day.year, day.month, day.day);
    final records = attendanceMap[dateKey];
    Color? dotColor;

    if (records != null && records.isNotEmpty) {
      final status = AttendanceStatus.fromString(
        records.first['status'] as String?,
      );
      dotColor = _statusColors[status];
    } else if (workSchedule != null && day.isAfter(DateTime.now())) {
      // Future workday with no attendance — show grey dot
      final dayNames = [
        'monday',
        'tuesday',
        'wednesday',
        'thursday',
        'friday',
        'saturday',
        'sunday',
      ];
      final dayName = dayNames[day.weekday - 1];
      if (workSchedule.workDays[dayName] == true) {
        dotColor = const Color(0xFF9CA3AF); // grey scheduled
      }
    }

    final bool highlight = isSelected || isToday;

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary
            : (isToday ? AppColors.primary.withAlpha(30) : Colors.transparent),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${day.day}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white : Colors.black87),
            ),
          ),
          const SizedBox(height: 2),
          // Status dot
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor ?? Colors.transparent,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Today's Schedule Card ───
  Widget _buildTodayScheduleCard(
    bool isDark,
    List<Map<String, dynamic>>? todayRecords,
  ) {
    final checkIn = todayRecords != null && todayRecords.isNotEmpty
        ? (todayRecords.first['checkIn'] as Timestamp?)?.toDate()
        : null;
    final checkOut = todayRecords != null && todayRecords.isNotEmpty
        ? (todayRecords.first['checkOut'] as Timestamp?)?.toDate()
        : null;
    final statusStr = todayRecords != null && todayRecords.isNotEmpty
        ? todayRecords.first['status'] as String?
        : null;
    final status = AttendanceStatus.fromString(statusStr);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(80),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circle
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(13),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TODAY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                          color: Colors.white.withAlpha(153),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        checkIn != null
                            ? '${DateFormat('hh:mm a').format(checkIn)} - ${checkOut != null ? DateFormat('hh:mm a').format(checkOut) : 'Active'}'
                            : 'No check-in yet',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(51),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.label,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.wifi,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Work Location',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withAlpha(153),
                        ),
                      ),
                      const Text(
                        'Office - WiFi Required',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Day Detail Bottom Sheet ───
  void _showDayDetail(
    BuildContext context,
    DateTime day,
    List<Map<String, dynamic>>? records,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                DateFormat('EEEE, d MMMM yyyy').format(day),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              if (records == null || records.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.event_available,
                          size: 40,
                          color: isDark ? Colors.white38 : Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No attendance data for this day',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white54
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...records.map((data) {
                  final checkIn = (data['checkIn'] as Timestamp?)?.toDate();
                  final checkOut = (data['checkOut'] as Timestamp?)?.toDate();
                  final statusStr = data['status'] as String?;
                  final status = AttendanceStatus.fromString(statusStr);
                  final workDuration = data['workDuration'] as int? ?? 0;
                  final overtimeDuration =
                      data['overtimeDuration'] as int? ?? 0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: (_statusColors[status] ?? Colors.grey).withAlpha(
                        20,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (_statusColors[status] ?? Colors.grey).withAlpha(
                          77,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: (_statusColors[status] ?? Colors.grey)
                                    .withAlpha(51),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                status.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _statusColors[status],
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (overtimeDuration > 0)
                              Text(
                                'Overtime ${(overtimeDuration / 60).toStringAsFixed(1)}h',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.purple.shade300,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _DetailItem(
                              icon: Icons.login,
                              label: 'Check In',
                              value: checkIn != null
                                  ? DateFormat('HH:mm').format(checkIn)
                                  : '-',
                              isDark: isDark,
                            ),
                            const SizedBox(width: 24),
                            _DetailItem(
                              icon: Icons.logout,
                              label: 'Check Out',
                              value: checkOut != null
                                  ? DateFormat('HH:mm').format(checkOut)
                                  : '-',
                              isDark: isDark,
                            ),
                            const SizedBox(width: 24),
                            _DetailItem(
                              icon: Icons.timer_outlined,
                              label: 'Duration',
                              value:
                                  '${(workDuration / 60).toStringAsFixed(1)}h',
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

// ─── Legend Dot Widget ───
class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }
}

// ─── Monthly Stat Card Widget ───
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
    required this.isDark,
  });

  final String value;
  final String label;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(isDark ? 51 : 25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(51)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isDark ? color.withAlpha(204) : color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Detail Item for Bottom Sheet ───
class _DetailItem extends StatelessWidget {
  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isDark ? Colors.white54 : Colors.grey),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }
}
