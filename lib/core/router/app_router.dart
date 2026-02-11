import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/attendance/presentation/attendance_screens.dart';
import '../../features/attendance/presentation/attendance_management_screen.dart';
import '../../features/attendance/presentation/wifi_network_management_screen.dart';
import '../../features/attendance/presentation/employee_attendance_detail_screen.dart';
import '../../features/attendance/presentation/work_schedule_screen.dart';
import '../../features/auth/presentation/add_employee_screen.dart';
import '../../features/auth/presentation/auth_screens.dart';
import '../../features/auth/presentation/employee_list_screen.dart';
import '../../features/auth/presentation/user_management_screen.dart';
import '../../features/dashboard/presentation/dashboard_screens.dart';
import '../../features/leave/presentation/leave_screen.dart';
import '../../features/leave/presentation/leave_inbox_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';

// ─── Shared transition builder ───────────────────────────
CustomTransitionPage<void> _transitionPage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.04, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

final appRouterProvider = Provider<GoRouter>(
  (ref) => GoRouter(
    initialLocation: '/',
    routes: [
      // Splash — no transition (instant)
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: '/auth',
        pageBuilder: (context, state) =>
            _transitionPage(state: state, child: const AuthChoiceScreen()),
      ),
      GoRoute(
        path: '/auth/signup',
        pageBuilder: (context, state) =>
            _transitionPage(state: state, child: const UnifiedSignUpScreen()),
      ),
      GoRoute(
        path: '/dashboard/admin',
        pageBuilder: (context, state) =>
            _transitionPage(state: state, child: const AdminDashboardScreen()),
      ),
      GoRoute(
        path: '/dashboard/employee',
        pageBuilder: (context, state) => _transitionPage(
          state: state,
          child: const EmployeeDashboardScreen(),
        ),
      ),
      GoRoute(
        path: '/attendance',
        pageBuilder: (context, state) =>
            _transitionPage(state: state, child: const AttendanceScreen()),
      ),
      GoRoute(
        path: '/attendance/history',
        pageBuilder: (context, state) => _transitionPage(
          state: state,
          child: const AttendanceHistoryScreen(),
        ),
      ),
      GoRoute(
        path: '/leave',
        pageBuilder: (context, state) =>
            _transitionPage(state: state, child: const LeaveRequestScreen()),
      ),
      GoRoute(
        path: '/admin/leave-inbox',
        pageBuilder: (context, state) =>
            _transitionPage(state: state, child: const LeaveInboxScreen()),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (context, state) =>
            _transitionPage(state: state, child: const ProfileScreen()),
      ),
      GoRoute(
        path: '/qr',
        pageBuilder: (context, state) =>
            _transitionPage(state: state, child: const QrBackupScreen()),
      ),
      GoRoute(
        path: '/admin/wifi-networks',
        pageBuilder: (context, state) => _transitionPage(
          state: state,
          child: const WifiNetworkManagementScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/users',
        pageBuilder: (context, state) =>
            _transitionPage(state: state, child: const UserManagementScreen()),
      ),
      GoRoute(
        path: '/admin/employees',
        pageBuilder: (context, state) =>
            _transitionPage(state: state, child: const EmployeeListScreen()),
      ),
      GoRoute(
        path: '/admin/add-employee',
        pageBuilder: (context, state) =>
            _transitionPage(state: state, child: const AddEmployeeScreen()),
      ),
      GoRoute(
        path: '/admin/attendance-management',
        pageBuilder: (context, state) => _transitionPage(
          state: state,
          child: const AttendanceManagementScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/settings',
        pageBuilder: (context, state) =>
            _transitionPage(state: state, child: const SettingsScreen()),
      ),
      GoRoute(
        path: '/admin/employee-attendance/:userId',
        pageBuilder: (context, state) {
          final userId = state.pathParameters['userId']!;
          final name = state.uri.queryParameters['name'] ?? 'Karyawan';
          return _transitionPage(
            state: state,
            child: EmployeeAttendanceDetailScreen(
              userId: userId,
              userName: name,
            ),
          );
        },
      ),
      GoRoute(
        path: '/admin/work-schedule/:userId',
        pageBuilder: (context, state) {
          final userId = state.pathParameters['userId']!;
          final name = state.uri.queryParameters['name'] ?? 'Karyawan';
          return _transitionPage(
            state: state,
            child: WorkScheduleScreen(userId: userId, userName: name),
          );
        },
      ),
    ],
  ),
);
