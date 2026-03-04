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
import '../../attendance/data/wifi_network_repository.dart';
import '../../auth/data/user_providers.dart';
import '../../leave/data/leave_repository.dart';
import '../../auth/application/auth_controller.dart';
import '../../announcements/presentation/announcement_feed.dart';
import '../../announcements/presentation/create_announcement_screen.dart';
import '../../attendance/presentation/attendance_management_screen.dart';
import '../../auth/presentation/employee_list_screen.dart';
import '../../leave/presentation/leave_screen.dart';
import '../../leave/presentation/leave_inbox_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../attendance/presentation/attendance_calendar_screen.dart';
import '../../settings/presentation/settings_screen.dart';

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
    final todayLogsAsync = ref.watch(todayAttendanceLogsProvider);

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
      body: IndexedStack(
        index: _navIndex,
        children: [
          // Tab 0: Home (Admin Dashboard content)
          SafeArea(
            child: Column(
              children: [
                // ─── Top Navbar ───
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
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
                      GestureDetector(
                        onTap: () => context.push('/admin/profile'),
                        child: Container(
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
                        onTap: () => context.push('/notifications'),
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
                                    icon: Icons.campaign_outlined,
                                    label: 'Post Update',
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const CreateAnnouncementScreen(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  _OutlinedActionButton(
                                    icon: Icons.person_add_alt,
                                    label: 'Add Employee',
                                    isDark: isDark,
                                    onTap: () =>
                                        context.push('/admin/add-employee'),
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

                          const SizedBox(height: 8),

                          // Company Announcements Feed (Admin View)
                          const AnnouncementFeed(isAdmin: true),

                          const SizedBox(height: 12),

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
                                      QueryDocumentSnapshot<
                                        Map<String, dynamic>
                                      >
                                    >
                                  >(
                                    future: attendanceRepo.getTodayCheckIns(),
                                    builder: (context, checkInSnap) {
                                      final todayCheckIns =
                                          checkInSnap.data ?? [];
                                      final presentCount = todayCheckIns.length;
                                      final absentCount =
                                          totalEmployees - presentCount;

                                      // Determine late arrivals (check-in after 09:00)
                                      int lateCount = 0;
                                      for (final doc in todayCheckIns) {
                                        final checkIn =
                                            (doc.data()['checkIn']
                                                    as Timestamp?)
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
                                                    iconColor:
                                                        AppColors.primary,
                                                    iconBgColor: AppColors
                                                        .primary
                                                        .withOpacity(0.1),
                                                    title: 'Total Staff',
                                                    value: '$totalUsers',
                                                    badge:
                                                        '+${totalEmployees > 0 ? 2 : 0}%',
                                                    badgeColor:
                                                        AppColors.success,
                                                    isDark: isDark,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: _DashStatCard(
                                                    icon: Icons.how_to_reg,
                                                    iconColor:
                                                        AppColors.success,
                                                    iconBgColor: AppColors
                                                        .success
                                                        .withOpacity(0.1),
                                                    title: 'Present',
                                                    value: '$presentCount',
                                                    badge: presentPct,
                                                    badgeColor:
                                                        AppColors.success,
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
                                                    iconBgColor: AppColors
                                                        .danger
                                                        .withOpacity(0.1),
                                                    title: 'Absent',
                                                    value: '$absentCount',
                                                    badge: absentPct,
                                                    badgeColor:
                                                        AppColors.danger,
                                                    isDark: isDark,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: _DashStatCard(
                                                    icon: Icons.schedule,
                                                    iconColor:
                                                        AppColors.warning,
                                                    iconBgColor: AppColors
                                                        .warning
                                                        .withOpacity(0.1),
                                                    title: 'Late Arrival',
                                                    value: '$lateCount',
                                                    badge: latePct,
                                                    badgeColor:
                                                        AppColors.warning,
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

                          // ─── Live Attendance Monitoring ───
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Live Attendance Monitoring',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _LiveBadge(
                                      isDark: isDark,
                                      isOnline: !todayLogsAsync.hasError,
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: () {
                                        ref.refresh(
                                          todayAttendanceLogsProvider,
                                        );
                                      },
                                      icon: Icon(
                                        Icons.refresh,
                                        size: 18,
                                        color: isDark
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade600,
                                      ),
                                      tooltip: 'Refresh',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      splashRadius: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(4),
                                      onTap: () => context.push(
                                        '/admin/attendance-management',
                                      ),
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
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Attendance Table
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: employeesStream,
                            builder: (context, empSnapshot) {
                              final employees = empSnapshot.data?.docs ?? [];

                              // Show loading only if loading AND no data
                              if (todayLogsAsync.isLoading &&
                                  !todayLogsAsync.hasValue) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              final todayLogs =
                                  todayLogsAsync.value?.docs ?? [];

                              // Map userId -> log data
                              final logsByUser = {
                                for (final queryDoc in todayLogs)
                                  queryDoc.data()['userId']: queryDoc.data(),
                              };

                              // Build rows (Take top 5)
                              final rows = employees.take(5).map((empDoc) {
                                final empData = empDoc.data();
                                final userId = empDoc.id;
                                final name = empData['name'] ?? 'Unknown';
                                final log = logsByUser[userId];

                                return _LiveAttendanceRowData(
                                  name: name,
                                  checkIn: (log?['checkIn'] as Timestamp?)
                                      ?.toDate(),
                                  checkOut: (log?['checkOut'] as Timestamp?)
                                      ?.toDate(),
                                  status: log?['status'],
                                );
                              }).toList();

                              if (rows.isEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Center(
                                    child: Text(
                                      'No employees found',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                );
                              }

                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.cardDark
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark
                                        ? AppColors.primary.withOpacity(0.1)
                                        : Colors.grey.shade200,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.02),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    // Table Header
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? AppColors.primary.withOpacity(0.1)
                                            : Colors.grey.shade50,
                                        border: Border(
                                          bottom: BorderSide(
                                            color: isDark
                                                ? AppColors.primary.withOpacity(
                                                    0.1,
                                                  )
                                                : Colors.grey.shade200,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Expanded(
                                            flex: 3,
                                            child: Text(
                                              'Employee',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          const Expanded(
                                            flex: 2,
                                            child: Text(
                                              'Check In',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          const Expanded(
                                            flex: 2,
                                            child: Text(
                                              'Check Out',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          const Expanded(
                                            flex: 2,
                                            child: Center(
                                              child: Text(
                                                'Status',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Rows
                                    ...rows.asMap().entries.map((entry) {
                                      return _LiveAttendanceRowItem(
                                        data: entry.value,
                                        isLast: entry.key == rows.length - 1,
                                        isDark: isDark,
                                      );
                                    }),
                                  ],
                                ),
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

          // Tab 1: Staff (Employee List)
          const EmployeeListScreen(showAppBar: false),

          // Tab 2: Attendance Management
          const AttendanceManagementScreen(showAppBar: false),

          // Tab 3: Leave Inbox
          const LeaveInboxScreen(showAppBar: false),

          // Tab 4: Settings
          const SettingsScreen(showAppBar: false),
        ],
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
            if (index == _navIndex) return; // Already on this tab
            HapticFeedback.lightImpact();
            setState(() => _navIndex = index);
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

  // WiFi state
  WifiInfo? _wifiInfo;
  bool _isWifiLoading = false;
  bool?
  _isWifiVerified; // null = not checked, true = office WiFi, false = wrong WiFi

  // Cached streams — MUST NOT be recreated on every build()
  Stream<QuerySnapshot<Map<String, dynamic>>>? _activeSessionStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _historyStream;
  String? _cachedUserId;

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

    // Initial WiFi check
    _checkWifi();
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    super.dispose();
  }

  /// Ensures streams are created only once per user ID.
  void _ensureStreams(String userId) {
    if (_cachedUserId == userId && _activeSessionStream != null) return;
    _cachedUserId = userId;
    final repo = ref.read(attendanceRepositoryProvider);
    _activeSessionStream = repo.streamActiveSession(userId);
    _historyStream = repo.streamUserLogs(userId);
  }

  Future<void> _checkWifi() async {
    if (_isWifiLoading) return;
    setState(() => _isWifiLoading = true);
    try {
      final info = await ref.read(wifiServiceProvider).getWifiInfo();
      if (!mounted) return;
      setState(() => _wifiInfo = info);

      // Verify against admin-registered networks
      if (info.isComplete) {
        final wifiRepo = ref.read(wifiNetworkRepositoryProvider);
        final verified = await wifiRepo.verifyWifiNetwork(
          ssid: info.ssid!,
          bssid: info.bssid!,
        );
        if (mounted) setState(() => _isWifiVerified = verified);
      } else {
        if (mounted) setState(() => _isWifiVerified = null);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _wifiInfo = null;
          _isWifiVerified = null;
        });
      }
    } finally {
      if (mounted) setState(() => _isWifiLoading = false);
    }
  }

  Widget _buildWifiStatusChip() {
    // 3 states: verified (green), wrong network (red), no wifi (yellow)
    final Color chipColor;
    final IconData chipIcon;
    final String chipText;

    if (_wifiInfo?.ssid != null && _isWifiVerified == true) {
      // Office WiFi - verified ✅
      chipColor = AppColors.success;
      chipIcon = Icons.wifi;
      chipText = '✓ Office WiFi: ${_wifiInfo!.ssid}';
    } else if (_wifiInfo?.ssid != null && _isWifiVerified == false) {
      // Wrong WiFi - not registered ❌
      chipColor = AppColors.danger;
      chipIcon = Icons.wifi_lock;
      chipText = '✗ Wrong WiFi: ${_wifiInfo!.ssid}';
    } else {
      // No WiFi detected
      chipColor = AppColors.warning;
      chipIcon = Icons.wifi_off;
      chipText = 'WiFi Not Detected';
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: chipColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: chipColor.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(chipIcon, size: 16, color: chipColor),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                chipText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: chipColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: _checkWifi,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: _isWifiLoading
                    ? SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: chipColor,
                        ),
                      )
                    : Icon(Icons.refresh, size: 14, color: chipColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.valueOrNull;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Cache streams so they survive rebuilds
    _ensureStreams(user.id);

    // Determine greeting
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
        ? 'Good Afternoon'
        : 'Good Evening';

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      body: IndexedStack(
        index: _navIndex,
        children: [
          // Index 0: Dashboard Home
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 180,
                floating: false,
                pinned: true,
                automaticallyImplyLeading: false,
                backgroundColor: isDark
                    ? AppColors.backgroundDark
                    : AppColors.backgroundLight,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    padding: const EdgeInsets.only(
                      top: 60,
                      left: 24,
                      right: 24,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() => _navIndex = 3);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.person_outline,
                                  color: AppColors.primary,
                                  size: 24,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  greeting,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade500,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  user.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => context.push('/notifications'),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.cardDark
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark
                                        ? AppColors.primary.withOpacity(0.1)
                                        : Colors.grey.shade200,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.notifications_none,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () async {
                                HapticFeedback.lightImpact();
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Konfirmasi Logout'),
                                    content: const Text(
                                      'Apakah Anda yakin ingin keluar?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Batal'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text(
                                          'Logout',
                                          style: TextStyle(
                                            color: AppColors.danger,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await ref
                                      .read(authControllerProvider.notifier)
                                      .signOut();
                                  if (context.mounted) context.go('/auth');
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.cardDark
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark
                                        ? AppColors.primary.withOpacity(0.1)
                                        : Colors.grey.shade200,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.logout,
                                  size: 20,
                                  color: AppColors.danger,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Column(
                      children: [
                        // WiFi Status Chip
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildWifiStatusChip(),
                        ),

                        // Warning banner when wrong WiFi
                        if (_isWifiVerified == false && _wifiInfo?.ssid != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.danger.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.danger.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: AppColors.danger,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'WiFi "${_wifiInfo!.ssid}" tidak terdaftar. '
                                      'Anda tidak bisa check-in dengan jaringan ini. '
                                      'Hubungkan ke WiFi kantor.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.danger,
                                        fontWeight: FontWeight.w600,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        const SizedBox(height: 24),

                        // Timer & Action Section (Reactive)
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: _activeSessionStream,
                          builder: (context, snapshot) {
                            DateTime? todayCheckIn;
                            bool isCheckedIn = false;

                            if (snapshot.hasData &&
                                snapshot.data!.docs.isNotEmpty) {
                              final data = snapshot.data!.docs.first.data();
                              final checkInRaw = data['checkIn'];
                              final checkIn = checkInRaw is Timestamp
                                  ? checkInRaw.toDate()
                                  : null;

                              isCheckedIn = true;
                              todayCheckIn = checkIn ?? DateTime.now();
                            }

                            return Column(
                              children: [
                                if (isCheckedIn)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.success.withOpacity(
                                          0.5,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                            color: AppColors.success,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'CHECKED IN',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.success,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                const SizedBox(height: 16),
                                _LiveWorkTimer(
                                  checkInTime: todayCheckIn,
                                  isDark: isDark,
                                ),
                                const SizedBox(height: 32),

                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Consumer(
                                    builder: (context, watchRef, _) {
                                      final attState = watchRef.watch(
                                        attendanceControllerProvider,
                                      );
                                      final isLoading =
                                          attState is AsyncLoading;

                                      return SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: isLoading
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
                                                    } else {
                                                      await controller.checkIn(
                                                        user,
                                                        manualSsid:
                                                            _wifiInfo?.ssid,
                                                        manualBssid:
                                                            _wifiInfo?.bssid,
                                                      );
                                                    }
                                                    if (!context.mounted)
                                                      return;
                                                    final state = ref.read(
                                                      attendanceControllerProvider,
                                                    );
                                                    if (state.hasError) {
                                                      final errorMsg = state
                                                          .error
                                                          .toString()
                                                          .replaceFirst(
                                                            RegExp(
                                                              r'^Exception:\s*',
                                                            ),
                                                            '',
                                                          )
                                                          .trim();
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            errorMsg,
                                                          ),
                                                          backgroundColor:
                                                              AppColors.danger,
                                                          duration:
                                                              const Duration(
                                                                seconds: 5,
                                                              ),
                                                        ),
                                                      );
                                                    } else {
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            isCheckedIn
                                                                ? 'Check-out successful!'
                                                                : 'Check-in successful!',
                                                          ),
                                                          backgroundColor:
                                                              AppColors.success,
                                                        ),
                                                      );
                                                    }
                                                  } catch (e) {
                                                    if (context.mounted) {
                                                      final errorMsg = e
                                                          .toString()
                                                          .replaceFirst(
                                                            RegExp(
                                                              r'^Exception:\s*',
                                                            ),
                                                            '',
                                                          )
                                                          .trim();
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            errorMsg,
                                                          ),
                                                          backgroundColor:
                                                              AppColors.danger,
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
                                              vertical: 18,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            elevation: 0,
                                          ),
                                          child: isLoading
                                              ? const SizedBox(
                                                  height: 24,
                                                  width: 24,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.white,
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
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Text(
                                                      isCheckedIn
                                                          ? 'Check Out'
                                                          : 'Check In',
                                                      style: const TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ],
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

                        const SizedBox(height: 32),

                        // Timeline Section
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "TODAY'S TIMELINE",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              StreamBuilder<
                                QuerySnapshot<Map<String, dynamic>>
                              >(
                                stream: _historyStream,
                                builder: (context, snapshot) {
                                  String punchIn = '--:--';
                                  if (snapshot.hasData &&
                                      snapshot.data!.docs.isNotEmpty) {
                                    final today = DateTime.now();
                                    for (final doc in snapshot.data!.docs) {
                                      final checkIn =
                                          (doc.data()['checkIn'] as Timestamp?)
                                              ?.toDate();
                                      if (checkIn != null &&
                                          checkIn.day == today.day &&
                                          checkIn.month == today.month &&
                                          checkIn.year == today.year) {
                                        punchIn = DateFormat(
                                          'hh:mm a',
                                        ).format(checkIn);
                                        break;
                                      }
                                    }
                                  }
                                  String punchOut = '--:--';
                                  if (snapshot.hasData &&
                                      snapshot.data!.docs.isNotEmpty) {
                                    final today = DateTime.now();
                                    for (final doc in snapshot.data!.docs) {
                                      final checkIn =
                                          (doc.data()['checkIn'] as Timestamp?)
                                              ?.toDate();
                                      final checkOut =
                                          (doc.data()['checkOut'] as Timestamp?)
                                              ?.toDate();
                                      if (checkIn != null &&
                                          checkIn.day == today.day &&
                                          checkIn.month == today.month &&
                                          checkIn.year == today.year &&
                                          checkOut != null) {
                                        punchOut = DateFormat(
                                          'hh:mm a',
                                        ).format(checkOut);
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
                                          value: punchIn,
                                          isDark: isDark,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _TimelineCard(
                                          icon: Icons.logout,
                                          label: 'Punch Out',
                                          value: punchOut,
                                          isDark: isDark,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Summary Section
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'MONTHLY SUMMARY',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              StreamBuilder<
                                QuerySnapshot<Map<String, dynamic>>
                              >(
                                stream: _historyStream,
                                builder: (context, snapshot) {
                                  int present = 0;
                                  final now = DateTime.now();
                                  if (snapshot.hasData) {
                                    present = snapshot.data!.docs.where((doc) {
                                      final tc =
                                          (doc.data()['checkIn'] as Timestamp?)
                                              ?.toDate();
                                      return tc != null &&
                                          tc.month == now.month &&
                                          tc.year == now.year;
                                    }).length;
                                  }

                                  // Calculate workdays elapsed this month (Mon-Fri)
                                  int workdaysElapsed = 0;
                                  for (int d = 1; d <= now.day; d++) {
                                    final date = DateTime(
                                      now.year,
                                      now.month,
                                      d,
                                    );
                                    if (date.weekday <= 5) workdaysElapsed++;
                                  }
                                  // Don't count today if not checked in yet
                                  final absent = (workdaysElapsed - present)
                                      .clamp(0, workdaysElapsed);

                                  return StreamBuilder<
                                    QuerySnapshot<Map<String, dynamic>>
                                  >(
                                    stream: FirebaseFirestore.instance
                                        .collection('leaveRequests')
                                        .where('userId', isEqualTo: user.id)
                                        .where('status', isEqualTo: 'Diterima')
                                        .snapshots(),
                                    builder: (context, leaveSnap) {
                                      int leaves = 0;
                                      if (leaveSnap.hasData) {
                                        leaves = leaveSnap.data!.docs.where((
                                          doc,
                                        ) {
                                          final created =
                                              (doc.data()['createdAt']
                                                      as Timestamp?)
                                                  ?.toDate();
                                          return created != null &&
                                              created.month == now.month &&
                                              created.year == now.year;
                                        }).length;
                                      }
                                      return Row(
                                        children: [
                                          Expanded(
                                            child: _SummaryCard(
                                              value: '$present',
                                              label: 'Present',
                                              valueColor: AppColors.primary,
                                              isDark: isDark,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _SummaryCard(
                                              value: '$absent',
                                              label: 'Absent',
                                              valueColor: AppColors.danger,
                                              isDark: isDark,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _SummaryCard(
                                              value: '$leaves',
                                              label: 'Leaves',
                                              valueColor: AppColors.success,
                                              isDark: isDark,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Announcements Section
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ANNOUNCEMENTS',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const AnnouncementFeed(),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Actions
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
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
                                  onTap: () =>
                                      context.push('/attendance/history'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Index 1: Attendance Calendar
          const AttendanceCalendarScreen(),

          // Index 2: Leave Request
          const LeaveRequestScreen(showAppBar: false),

          // Index 3: Profile
          const ProfileScreen(showAppBar: false),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _navIndex,
        onTap: (index) {
          if (index == _navIndex) return;
          HapticFeedback.lightImpact();
          setState(() => _navIndex = index);
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

class _AttendanceTrendChart extends ConsumerWidget {
  const _AttendanceTrendChart({super.key, required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendanceRepo = ref.watch(attendanceRepositoryProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfRange = today.subtract(const Duration(days: 6));
    final endOfRange = today.add(const Duration(days: 1));

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: attendanceRepo.streamLogsForRange(startOfRange, endOfRange),
      builder: (context, snapshot) {
        // Fetch total employees count for normalization
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'employee')
              .snapshots(),
          builder: (context, staffSnapshot) {
            final totalStaff = staffSnapshot.data?.docs.length ?? 0;
            final logs = snapshot.data?.docs ?? [];

            final List<String> days = [];
            final List<double> heights = [];
            final List<double> fills = [];

            for (int i = 0; i < 7; i++) {
              final day = startOfRange.add(Duration(days: i));
              days.add(DateFormat('E').format(day));

              final dayLogs = logs.where((doc) {
                final checkIn = (doc.data()['checkIn'] as Timestamp?)?.toDate();
                if (checkIn == null) return false;
                return checkIn.year == day.year &&
                    checkIn.month == day.month &&
                    checkIn.day == day.day;
              }).toList();

              final presentCount = dayLogs.length;

              // Late count (after 09:00)
              int lateCount = 0;
              for (final doc in dayLogs) {
                final checkIn = (doc.data()['checkIn'] as Timestamp?)?.toDate();
                if (checkIn != null &&
                    (checkIn.hour > 9 ||
                        (checkIn.hour == 9 && checkIn.minute > 0))) {
                  lateCount++;
                }
              }
              final onTimeCount = presentCount - lateCount;

              // Scaling for chart (0.05 min height to avoid empty bars)
              final h = totalStaff > 0
                  ? (presentCount / totalStaff).clamp(0.05, 1.0)
                  : 0.05;
              final f = presentCount > 0
                  ? (onTimeCount / presentCount).clamp(0.01, 1.0)
                  : 0.01;

              heights.add(h);
              fills.add(f);
            }

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
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
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
                                              ? AppColors.primary.withOpacity(
                                                  0.4,
                                                )
                                              : AppColors.primary.withOpacity(
                                                  0.2,
                                                ),
                                          borderRadius:
                                              const BorderRadius.vertical(
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
          },
        );
      },
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

class _LiveAttendanceRowData {
  final String name;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final String? status;

  _LiveAttendanceRowData({
    required this.name,
    this.checkIn,
    this.checkOut,
    this.status,
  });
}

class _LiveAttendanceRowItem extends StatelessWidget {
  const _LiveAttendanceRowItem({
    required this.data,
    required this.isLast,
    required this.isDark,
  });

  final _LiveAttendanceRowData data;
  final bool isLast;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    // Determine status badge style
    Color badgeBg;
    Color badgeText;
    Color badgeBorder;
    String statusLabel = 'ABSENT';

    if (data.status != null) {
      // Map common API statuses to UI
      final s = data.status!.toUpperCase();
      if (s == 'CHECKED_IN' || s == 'CHECKED_OUT') {
        statusLabel = 'PRESENT';
        badgeBg = Colors.green.withOpacity(0.1);
        badgeText = Colors.green;
        badgeBorder = Colors.green.withOpacity(0.2);
      } else if (s == 'LATE') {
        statusLabel = 'LATE';
        badgeBg = Colors.orange.withOpacity(0.1);
        badgeText = Colors.orange;
        badgeBorder = Colors.orange.withOpacity(0.2);
      } else if (s == 'EARLY_LEAVE') {
        statusLabel = 'LEFT EARLY';
        badgeBg = Colors.orange.withOpacity(0.1);
        badgeText = Colors.orange;
        badgeBorder = Colors.orange.withOpacity(0.2);
      } else if (s == 'OVERTIME') {
        statusLabel = 'OVERTIME';
        badgeBg = Colors.blue.withOpacity(0.1);
        badgeText = Colors.blue;
        badgeBorder = Colors.blue.withOpacity(0.2);
      } else {
        statusLabel = s;
        badgeBg = Colors.grey.withOpacity(0.1);
        badgeText = Colors.grey;
        badgeBorder = Colors.grey.withOpacity(0.2);
      }
    } else {
      // No log found -> Absent
      statusLabel = 'ABSENT';
      badgeBg = Colors.red.withOpacity(0.1);
      badgeText = Colors.red;
      badgeBorder = Colors.red.withOpacity(0.2);
    }

    final checkInStr = data.checkIn != null
        ? DateFormat('hh:mm a').format(data.checkIn!)
        : '--:--';
    final checkOutStr = data.checkOut != null
        ? DateFormat('hh:mm a').format(data.checkOut!)
        : '--:--';

    // Status text color if not set (fallback)
    badgeText = isDark ? badgeText.withOpacity(0.9) : badgeText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: isDark
                      ? AppColors.primary.withOpacity(0.05)
                      : Colors.grey.shade100,
                ),
              ),
      ),
      child: Row(
        children: [
          // Name + Avatar
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      data.name.isNotEmpty ? data.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    data.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.grey.shade800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Check In
          Expanded(
            flex: 2,
            child: Text(
              checkInStr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
          ),

          // Check Out
          Expanded(
            flex: 2,
            child: Text(
              checkOutStr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
          ),

          // Status Badge
          Expanded(
            flex: 2,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: badgeBorder),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: badgeText,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Provider for today's attendance logs to prevent rebuilding on scroll
final todayAttendanceLogsProvider =
    StreamProvider.autoDispose<QuerySnapshot<Map<String, dynamic>>>((ref) {
      final repo = ref.watch(attendanceRepositoryProvider);
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));
      return repo.streamLogsForRange(todayStart, todayEnd);
    });

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({super.key, required this.isDark, required this.isOnline});

  final bool isDark;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    // Green for online, Red for offline
    final color = isOnline ? Colors.green : Colors.red;

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}
