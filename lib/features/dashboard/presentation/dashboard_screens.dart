import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/wifi_service.dart';
import '../../../core/theme/theme_provider.dart';
import '../../attendance/application/attendance_controller.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../auth/data/user_providers.dart';
import '../../leave/data/leave_repository.dart';

// ──────────────────────────────────────────────────────────
//  ADMIN DASHBOARD
// ──────────────────────────────────────────────────────────

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  int _navIndex = 0;
  late final AnimationController _staggerCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(
      parent: _staggerCtrl,
      curve: Curves.easeOutCubic,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(_fadeAnim);
    _staggerCtrl.forward();
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userAsync = ref.watch(currentUserProvider);
    final attendanceRepo = ref.watch(attendanceRepositoryProvider);
    final recentLogs = attendanceRepo.streamRecentLogs();
    final employeesStream = ref
        .watch(usersCollectionProvider)
        .where('role', isEqualTo: 'employee')
        .snapshots();
    final allUsersStream = ref.watch(usersCollectionProvider).snapshots();
    final leaveRepo = ref.watch(leaveRepositoryProvider);
    final pendingLeavesStream = leaveRepo.streamPendingLeaves();
    final now = DateTime.now();
    final dateStr = DateFormat('MMM dd, yyyy').format(now);

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // ─── Top Navbar ───
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? AppColors.primary.withOpacity(0.2)
                        : Colors.grey.shade200,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Profile avatar
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        userAsync.when(
                          data: (user) => Text(
                            'Hello, ${user?.name ?? 'Admin'}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          loading: () => const Text(
                            'Loading...',
                            style: TextStyle(fontSize: 14),
                          ),
                          error: (_, __) => const Text(
                            'Hello, Admin',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade500,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Notification bell
                  _NavBarIcon(
                    icon: Icons.notifications_outlined,
                    isDark: isDark,
                    onTap: () {},
                    showBadge: true,
                  ),
                  const SizedBox(width: 4),
                  // Dark mode toggle
                  _NavBarIcon(
                    icon: isDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                    isDark: isDark,
                    onTap: () =>
                        ref.read(themeModeProvider.notifier).toggleTheme(),
                  ),
                ],
              ),
            ),

            // ─── Scrollable content ───
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      // Quick Actions
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _PrimaryActionButton(
                                icon: Icons.person_add_alt,
                                label: 'Add Employee',
                                onTap: () =>
                                    context.push('/admin/add-employee'),
                              ),
                              const SizedBox(width: 12),
                              _OutlinedActionButton(
                                icon: Icons.download_outlined,
                                label: 'Reports',
                                isDark: isDark,
                                onTap: () {},
                              ),
                              const SizedBox(width: 12),
                              StreamBuilder<
                                QuerySnapshot<Map<String, dynamic>>
                              >(
                                stream: pendingLeavesStream,
                                builder: (context, snap) {
                                  final count = snap.data?.docs.length ?? 0;
                                  return _OutlinedActionButton(
                                    icon: Icons.inbox,
                                    label:
                                        'Inbox Cuti${count > 0 ? ' ($count)' : ''}',
                                    isDark: isDark,
                                    onTap: () =>
                                        context.push('/admin/leave-inbox'),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Stats Grid
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: employeesStream,
                        builder: (context, empSnapshot) {
                          final totalEmployees =
                              empSnapshot.data?.docs.length ?? 0;

                          return StreamBuilder<
                            QuerySnapshot<Map<String, dynamic>>
                          >(
                            stream: allUsersStream,
                            builder: (context, allSnapshot) {
                              final totalUsers =
                                  allSnapshot.data?.docs.length ?? 0;

                              return FutureBuilder<
                                List<
                                  QueryDocumentSnapshot<Map<String, dynamic>>
                                >
                              >(
                                future: attendanceRepo.getTodayCheckIns(),
                                builder: (context, checkInSnap) {
                                  final todayCheckIns = checkInSnap.data ?? [];
                                  final presentCount = todayCheckIns.length;
                                  final absentCount =
                                      totalEmployees - presentCount;

                                  // Determine late arrivals (check-in after 09:00)
                                  int lateCount = 0;
                                  for (final doc in todayCheckIns) {
                                    final checkIn =
                                        (doc.data()['checkIn'] as Timestamp?)
                                            ?.toDate();
                                    if (checkIn != null &&
                                        checkIn.hour >= 9 &&
                                        checkIn.minute > 0) {
                                      lateCount++;
                                    }
                                  }

                                  final presentPct = totalEmployees > 0
                                      ? '${(presentCount / totalEmployees * 100).toStringAsFixed(0)}%'
                                      : '0%';
                                  final absentPct = totalEmployees > 0
                                      ? '${(absentCount / totalEmployees * 100).toStringAsFixed(0)}%'
                                      : '0%';
                                  final latePct = totalEmployees > 0
                                      ? '${(lateCount / totalEmployees * 100).toStringAsFixed(0)}%'
                                      : '0%';

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _DashStatCard(
                                                icon: Icons.groups,
                                                iconColor: AppColors.primary,
                                                iconBgColor: AppColors.primary
                                                    .withOpacity(0.1),
                                                title: 'Total Staff',
                                                value: '$totalUsers',
                                                badge:
                                                    '+${totalEmployees > 0 ? 2 : 0}%',
                                                badgeColor: AppColors.success,
                                                isDark: isDark,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: _DashStatCard(
                                                icon: Icons.how_to_reg,
                                                iconColor: AppColors.success,
                                                iconBgColor: AppColors.success
                                                    .withOpacity(0.1),
                                                title: 'Present',
                                                value: '$presentCount',
                                                badge: presentPct,
                                                badgeColor: AppColors.success,
                                                isDark: isDark,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _DashStatCard(
                                                icon: Icons.person_off,
                                                iconColor: AppColors.danger,
                                                iconBgColor: AppColors.danger
                                                    .withOpacity(0.1),
                                                title: 'Absent',
                                                value: '$absentCount',
                                                badge: absentPct,
                                                badgeColor: AppColors.danger,
                                                isDark: isDark,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: _DashStatCard(
                                                icon: Icons.schedule,
                                                iconColor: AppColors.warning,
                                                iconBgColor: AppColors.warning
                                                    .withOpacity(0.1),
                                                title: 'Late Arrival',
                                                value: '$lateCount',
                                                badge: latePct,
                                                badgeColor: AppColors.warning,
                                                isDark: isDark,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // Attendance Trend Chart
                      _AttendanceTrendChart(isDark: isDark),

                      const SizedBox(height: 20),

                      // Recent Check-ins
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Recent Check-ins',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            InkWell(
                              borderRadius: BorderRadius.circular(4),
                              onTap: () => context.push('/admin/employees'),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                child: Text(
                                  'View All',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppColors.accent
                                        : AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Check-in list
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: ref.watch(usersCollectionProvider).snapshots(),
                        builder: (context, usersSnapshot) {
                          final userDocs = usersSnapshot.data?.docs ?? [];
                          final Map<String, String> userNameById = {
                            for (final doc in userDocs)
                              doc.id: (doc.data()['name'] ?? doc.id).toString(),
                          };
                          final Map<String, String> userDeptById = {
                            for (final doc in userDocs)
                              doc.id: (doc.data()['department'] ?? 'Staff')
                                  .toString(),
                          };

                          return StreamBuilder<
                            QuerySnapshot<Map<String, dynamic>>
                          >(
                            stream: recentLogs,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              final docs = snapshot.data?.docs ?? [];
                              if (docs.isEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Center(
                                    child: Text(
                                      'Belum ada log absensi',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Column(
                                  children: docs.take(5).map((d) {
                                    final data = d.data();
                                    final userId = data['userId'] ?? '-';
                                    final userName =
                                        userNameById[userId] ??
                                        userId.toString();
                                    final dept =
                                        userDeptById[userId] ?? 'Staff';
                                    final checkIn =
                                        (data['checkIn'] as Timestamp?)
                                            ?.toDate();
                                    final checkOut =
                                        data['checkOut'] as Timestamp?;
                                    final timeStr = checkIn != null
                                        ? DateFormat('hh:mm a').format(checkIn)
                                        : '--:--';

                                    // Determine status
                                    String status = 'Present';
                                    if (checkIn != null &&
                                        checkIn.hour >= 9 &&
                                        checkIn.minute > 0) {
                                      status = 'Late';
                                    }
                                    if (checkOut == null && checkIn == null) {
                                      status = 'Absent';
                                    }

                                    return _RecentCheckInCard(
                                      name: userName,
                                      department: dept,
                                      time: timeStr,
                                      status: status,
                                      isDark: isDark,
                                    );
                                  }).toList(),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      // ─── Bottom Navigation ───
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark
                  ? AppColors.primary.withOpacity(0.2)
                  : Colors.grey.shade200,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _navIndex,
          onTap: (index) {
            if (index == 0) return; // Already on home
            HapticFeedback.lightImpact();
            String? route;
            switch (index) {
              case 1:
                route = '/admin/employees';
                break;
              case 2:
                route = '/admin/attendance-management';
                break;
              case 3:
                route = '/admin/leave-inbox';
                break;
              case 4:
                route = '/admin/settings';
                break;
            }
            if (route != null) {
              context.push(route).then((_) {
                if (mounted) setState(() => _navIndex = 0);
              });
            }
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'HOME'),
            BottomNavigationBarItem(icon: Icon(Icons.groups), label: 'STAFF'),
            BottomNavigationBarItem(
              icon: Icon(Icons.fingerprint),
              label: 'ATTEND',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.inbox), label: 'INBOX'),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'SETTINGS',
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
//  EMPLOYEE DASHBOARD
// ──────────────────────────────────────────────────────────

class EmployeeDashboardScreen extends ConsumerStatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  ConsumerState<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState
    extends ConsumerState<EmployeeDashboardScreen>
    with SingleTickerProviderStateMixin {
  int _navIndex = 0;
  late final AnimationController _staggerCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // New state variables
  WifiInfo? _wifiInfo;
  bool _isWifiLoading = false;

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(
      parent: _staggerCtrl,
      curve: Curves.easeOutCubic,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(_fadeAnim);
    _staggerCtrl.forward();

    _staggerCtrl.forward();

    // Initial WiFi check
    _checkWifi();
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkWifi() async {
    if (_isWifiLoading) return;
    setState(() => _isWifiLoading = true);
    try {
      final info = await ref.read(wifiServiceProvider).getWifiInfo();
      if (mounted) setState(() => _wifiInfo = info);
    } catch (e) {
      if (mounted) setState(() => _wifiInfo = null);
    } finally {
      if (mounted) setState(() => _isWifiLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.valueOrNull;
    final attendanceRepo = ref.watch(attendanceRepositoryProvider);
    final Stream<QuerySnapshot<Map<String, dynamic>>> logsStream = user == null
        ? Stream<QuerySnapshot<Map<String, dynamic>>>.empty()
        : attendanceRepo.streamUserLogs(user.id);

    // Determine greeting
    final hour = DateTime.now().hour;
    String greeting = 'Good Morning';
    if (hour >= 12 && hour < 17) greeting = 'Good Afternoon';
    if (hour >= 17) greeting = 'Good Evening';

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // ─── Header ───
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.backgroundDark
                    : AppColors.backgroundLight,
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? AppColors.primary.withOpacity(0.1)
                        : Colors.grey.shade200,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Profile avatar
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                        width: 2,
                      ),
                      color: AppColors.primary.withOpacity(0.1),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$greeting,',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        userAsync.when(
                          data: (u) => Text(
                            u?.name ?? 'Employee',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          loading: () => const Text(
                            'Loading...',
                            style: TextStyle(fontSize: 18),
                          ),
                          error: (_, __) => const Text(
                            'Employee',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _NavBarIcon(
                    icon: Icons.notifications_outlined,
                    isDark: isDark,
                    onTap: () {},
                  ),
                ],
              ),
            ),

            // ─── Content ───
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    children: [
                      // WiFi Status Chip (Dynamic)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _wifiInfo?.ssid != null
                                ? AppColors.success.withOpacity(0.1)
                                : AppColors.warning.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(9999),
                            border: Border.all(
                              color: _wifiInfo?.ssid != null
                                  ? AppColors.success.withOpacity(0.2)
                                  : AppColors.warning.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _wifiInfo?.ssid != null
                                    ? Icons.wifi
                                    : Icons.wifi_off,
                                size: 14,
                                color: _wifiInfo?.ssid != null
                                    ? AppColors.success
                                    : AppColors.warning,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _wifiInfo?.ssid != null
                                      ? 'Connected: ${_wifiInfo!.ssid}'
                                      : 'WiFi Not Detected',
                                  style: TextStyle(
                                    color: _wifiInfo?.ssid != null
                                        ? AppColors.success
                                        : AppColors.warning,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Refresh Button
                              InkWell(
                                onTap: _checkWifi,
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: _isWifiLoading
                                      ? const SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Icon(
                                          Icons.refresh,
                                          size: 14,
                                          color: _wifiInfo?.ssid != null
                                              ? AppColors.success
                                              : AppColors.warning,
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Timer & Action Section
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: logsStream,
                        builder: (context, snapshot) {
                          DateTime? todayCheckIn;
                          bool isCheckedIn = false;

                          if (snapshot.hasData &&
                              snapshot.data!.docs.isNotEmpty) {
                            final today = DateTime.now();
                            for (final doc in snapshot.data!.docs) {
                              final data = doc.data();
                              final checkIn = (data['checkIn'] as Timestamp?)
                                  ?.toDate();
                              if (checkIn != null &&
                                  checkIn.year == today.year &&
                                  checkIn.month == today.month &&
                                  checkIn.day == today.day) {
                                todayCheckIn = checkIn;
                                isCheckedIn = data['checkOut'] == null;
                                break;
                              }
                            }
                          }
                          return Column(
                            children: [
                              // Timer display
                              _LiveWorkTimer(
                                checkInTime: todayCheckIn,
                                isDark: isDark,
                              ),

                              const SizedBox(height: 32),

                              // Check In / Check Out button (inline — no navigation)
                              SizedBox(
                                width: double.infinity,
                                child: Consumer(
                                  builder: (context, watchRef, _) {
                                    final attState = watchRef.watch(
                                      attendanceControllerProvider,
                                    );
                                    final isLoading = attState is AsyncLoading;
                                    return ElevatedButton(
                                      onPressed: (user == null || isLoading)
                                          ? null
                                          : () async {
                                              final controller = ref.read(
                                                attendanceControllerProvider
                                                    .notifier,
                                              );
                                              try {
                                                if (isCheckedIn) {
                                                  await controller.checkOut(
                                                    user,
                                                  );
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Check-out successful!',
                                                        ),
                                                        backgroundColor:
                                                            Colors.green,
                                                      ),
                                                    );
                                                  }
                                                } else {
                                                  await controller.checkIn(
                                                    user,
                                                    ssid:
                                                        _wifiInfo?.ssid ??
                                                        'manual',
                                                    bssid:
                                                        _wifiInfo?.bssid ??
                                                        'manual',
                                                  );
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Check-in successful!',
                                                        ),
                                                        backgroundColor:
                                                            Colors.green,
                                                      ),
                                                    );
                                                  }
                                                }
                                              } catch (e) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Error: $e',
                                                      ),
                                                      backgroundColor:
                                                          Colors.red,
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isCheckedIn
                                            ? AppColors.danger
                                            : AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 20,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        elevation: 4,
                                        shadowColor: AppColors.primary
                                            .withOpacity(0.3),
                                      ),
                                      child: isLoading
                                          ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  isCheckedIn
                                                      ? Icons.logout
                                                      : Icons.login,
                                                  size: 24,
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  isCheckedIn
                                                      ? 'Check Out'
                                                      : 'Check In',
                                                  style: const TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    );
                                  },
                                ),
                              ),

                              const SizedBox(height: 12),

                              if (todayCheckIn != null)
                                Text(
                                  'Shift started at ${DateFormat('hh:mm a').format(todayCheckIn)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade500,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 28),

                      // Today's Timeline
                      Text(
                        "TODAY'S TIMELINE",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: isDark ? Colors.white : Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: logsStream,
                        builder: (context, snapshot) {
                          String punchInTime = '--:--';
                          String breakTime = '00:00:00';

                          if (snapshot.hasData &&
                              snapshot.data!.docs.isNotEmpty) {
                            final today = DateTime.now();
                            for (final doc in snapshot.data!.docs) {
                              final data = doc.data();
                              final checkIn = (data['checkIn'] as Timestamp?)
                                  ?.toDate();
                              if (checkIn != null &&
                                  checkIn.year == today.year &&
                                  checkIn.month == today.month &&
                                  checkIn.day == today.day) {
                                punchInTime = DateFormat(
                                  'hh:mm a',
                                ).format(checkIn);
                                break;
                              }
                            }
                          }

                          return Row(
                            children: [
                              Expanded(
                                child: _TimelineCard(
                                  icon: Icons.login,
                                  label: 'Punch In',
                                  value: punchInTime,
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _TimelineCard(
                                  icon: Icons.coffee,
                                  label: 'Break Time',
                                  value: breakTime,
                                  isDark: isDark,
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 28),

                      // Monthly Summary
                      Text(
                        'MONTHLY SUMMARY (${DateFormat('MMM').format(DateTime.now()).toUpperCase()})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: isDark ? Colors.white : Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: logsStream,
                        builder: (context, snapshot) {
                          int presentCount = 0;
                          int absentCount = 0;

                          if (snapshot.hasData) {
                            final now = DateTime.now();
                            for (final doc in snapshot.data!.docs) {
                              final data = doc.data();
                              final checkIn = (data['checkIn'] as Timestamp?)
                                  ?.toDate();
                              if (checkIn != null &&
                                  checkIn.year == now.year &&
                                  checkIn.month == now.month) {
                                presentCount++;
                              }
                            }
                            // Rough estimate of workdays passed this month
                            final dayOfMonth = now.day;
                            int workDays = 0;
                            for (int d = 1; d <= dayOfMonth; d++) {
                              final date = DateTime(now.year, now.month, d);
                              if (date.weekday <= 5) workDays++;
                            }
                            absentCount = (workDays - presentCount).clamp(
                              0,
                              workDays,
                            );
                          }

                          return Row(
                            children: [
                              Expanded(
                                child: _SummaryCard(
                                  value: '$presentCount',
                                  label: 'Present',
                                  valueColor: AppColors.primary,
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _SummaryCard(
                                  value: '$absentCount',
                                  label: 'Absent',
                                  valueColor: AppColors.danger,
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _SummaryCard(
                                  value: '0',
                                  label: 'Leaves',
                                  valueColor: AppColors.success,
                                  isDark: isDark,
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 28),

                      // Quick Actions
                      Row(
                        children: [
                          Expanded(
                            child: _EmployeeActionButton(
                              icon: Icons.event_busy,
                              label: 'Leave Request',
                              isDark: isDark,
                              onTap: () => context.push('/leave'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _EmployeeActionButton(
                              icon: Icons.history,
                              label: 'Work History',
                              isDark: isDark,
                              onTap: () => context.push('/attendance/history'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      // ─── Bottom Navigation ───
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark
                  ? AppColors.primary.withOpacity(0.2)
                  : Colors.grey.shade200,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _navIndex,
          onTap: (index) {
            if (index == 0) return; // Already on dashboard
            HapticFeedback.lightImpact();
            String? route;
            switch (index) {
              case 1:
                route = '/attendance/history';
                break;
              case 2:
                route = '/leave';
                break;
              case 3:
                route = '/profile';
                break;
            }
            if (route != null) {
              context.push(route).then((_) {
                if (mounted) setState(() => _navIndex = 0);
              });
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: 'DASHBOARD',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month),
              label: 'ATTENDANCE',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.task), label: 'LEAVE'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'PROFILE'),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
//  SHARED WIDGETS
// ──────────────────────────────────────────────────────────

class _NavBarIcon extends StatelessWidget {
  const _NavBarIcon({
    required this.icon,
    required this.isDark,
    required this.onTap,
    this.showBadge = false,
  });

  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark
                ? AppColors.primary.withOpacity(0.2)
                : Colors.grey.shade100,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 22),
              if (showBadge)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppColors.cardDark : Colors.white,
                        width: 2,
                      ),
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

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(8),
      elevation: 2,
      shadowColor: AppColors.primary.withOpacity(0.3),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlinedActionButton extends StatelessWidget {
  const _OutlinedActionButton({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark
          ? AppColors.primary.withOpacity(0.2)
          : AppColors.primary.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isDark ? Colors.blue.shade300 : AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isDark ? Colors.blue.shade300 : AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashStatCard extends StatelessWidget {
  const _DashStatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.value,
    required this.badge,
    required this.badgeColor,
    required this.isDark,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String value;
  final String badge;
  final Color badgeColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? AppColors.primary.withOpacity(0.1)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark ? iconBgColor.withOpacity(0.3) : iconBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              Text(
                badge,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: badgeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _AttendanceTrendChart extends StatelessWidget {
  const _AttendanceTrendChart({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final heights = [0.75, 0.85, 0.6, 0.95, 0.8, 0.4, 0.3];
    final fills = [0.5, 0.66, 0.33, 0.75, 0.5, 0.25, 0.16];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? AppColors.primary.withOpacity(0.1)
                : Colors.grey.shade200,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Attendance Trend',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                Text(
                  'LAST 7 DAYS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 140,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (i) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: FractionallySizedBox(
                              heightFactor: heights[i],
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.primary.withOpacity(0.4)
                                      : AppColors.primary.withOpacity(0.2),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(3),
                                  ),
                                ),
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: FractionallySizedBox(
                                    heightFactor: fills[i],
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: i == 0
                                            ? const BorderRadius.vertical(
                                                top: Radius.circular(0),
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            days[i].toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentCheckInCard extends StatelessWidget {
  const _RecentCheckInCard({
    required this.name,
    required this.department,
    required this.time,
    required this.status,
    required this.isDark,
  });

  final String name;
  final String department;
  final String time;
  final String status;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    Color statusBgColor;
    Color statusTextColor;

    switch (status.toLowerCase()) {
      case 'late':
        statusBgColor = AppColors.warning.withOpacity(0.2);
        statusTextColor = AppColors.warning;
        break;
      case 'absent':
        statusBgColor = AppColors.danger.withOpacity(0.2);
        statusTextColor = AppColors.danger;
        break;
      default:
        statusBgColor = AppColors.success.withOpacity(0.2);
        statusTextColor = AppColors.success;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
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
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? AppColors.primary.withOpacity(0.2)
                  : Colors.grey.shade100,
              border: Border.all(
                color: isDark
                    ? AppColors.primary.withOpacity(0.2)
                    : Colors.grey.shade200,
              ),
            ),
            child: Icon(
              Icons.person,
              size: 20,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 12),
          // Name and Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$department • $time',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusBgColor,
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(color: statusTextColor.withOpacity(0.3)),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: statusTextColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Employee Dashboard specific widgets ───

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.primary.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? AppColors.primary.withOpacity(0.2)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.2),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: Text(
              value,
              key: ValueKey<String>(value),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.value,
    required this.label,
    required this.valueColor,
    required this.isDark,
  });

  final String value;
  final String label;
  final Color valueColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.primary.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? AppColors.primary.withOpacity(0.2)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Text(
              value,
              key: ValueKey<String>(value),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeActionButton extends StatelessWidget {
  const _EmployeeActionButton({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: isDark ? Colors.white : AppColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.primary,
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

class _LiveWorkTimer extends StatefulWidget {
  const _LiveWorkTimer({required this.checkInTime, required this.isDark});

  final DateTime? checkInTime;
  final bool isDark;

  @override
  State<_LiveWorkTimer> createState() => _LiveWorkTimerState();
}

class _LiveWorkTimerState extends State<_LiveWorkTimer> {
  Timer? _timer;
  String _displayText = '00:00:00';

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  @override
  void didUpdateWidget(_LiveWorkTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.checkInTime != widget.checkInTime) {
      _updateTime();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateTime() {
    if (widget.checkInTime == null) {
      if (_displayText != '00:00:00') {
        if (mounted) setState(() => _displayText = '00:00:00');
      }
      return;
    }

    final now = DateTime.now();
    Duration duration = now.difference(widget.checkInTime!);
    if (duration.isNegative) duration = Duration.zero;

    final h = duration.inHours.toString().padLeft(2, '0');
    final m = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final s = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final newText = '$h:$m:$s';

    if (newText != _displayText) {
      if (mounted) setState(() => _displayText = newText);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          _displayText,
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
            color: widget.isDark ? Colors.white : Colors.grey.shade900,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Working Hours Today',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
