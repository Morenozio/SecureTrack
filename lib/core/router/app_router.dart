import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/attendance/presentation/attendance_screens.dart';
import '../../features/auth/presentation/auth_screens.dart';
import '../../features/dashboard/presentation/dashboard_screens.dart';
import '../../features/leave/presentation/leave_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';

final appRouterProvider = Provider<GoRouter>(
  (ref) => GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthChoiceScreen(),
      ),
      GoRoute(
        path: '/auth/signup',
        builder: (context, state) => const UnifiedSignUpScreen(),
      ),
      GoRoute(
        path: '/dashboard/admin',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/dashboard/employee',
        builder: (context, state) => const EmployeeDashboardScreen(),
      ),
      GoRoute(
        path: '/attendance',
        builder: (context, state) => const AttendanceScreen(),
      ),
      GoRoute(
        path: '/attendance/history',
        builder: (context, state) => const AttendanceHistoryScreen(),
      ),
      GoRoute(
        path: '/leave',
        builder: (context, state) => const LeaveRequestScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/qr',
        builder: (context, state) => const QrBackupScreen(),
      ),
    ],
  ),
);

