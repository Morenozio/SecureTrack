import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../auth/data/user_providers.dart';

class EmployeeListScreen extends ConsumerStatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  ConsumerState<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends ConsumerState<EmployeeListScreen> {
  String _searchQuery = '';
  String _departmentFilter = 'All';
  bool _sortAscending = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final employeesStream = ref
        .watch(usersCollectionProvider)
        .where('role', isEqualTo: 'employee')
        .snapshots();
    final attendanceRepo = ref.watch(attendanceRepositoryProvider);

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
        title: const Text('Employee Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Add Employee',
            onPressed: () => context.push('/admin/add-employee'),
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Search & Filter Bar ───
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
                // Search bar
                TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search by name or email...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? AppColors.backgroundDark
                        : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Filter row
                Row(
                  children: [
                    // Department filter
                    Expanded(
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: ref
                            .watch(usersCollectionProvider)
                            .where('role', isEqualTo: 'employee')
                            .snapshots(),
                        builder: (context, snap) {
                          final departments = <String>{'All'};
                          if (snap.hasData) {
                            for (final doc in snap.data!.docs) {
                              final dept = doc.data()['department'] as String?;
                              if (dept != null && dept.isNotEmpty) {
                                departments.add(dept);
                              }
                            }
                          }
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.backgroundDark
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _departmentFilter,
                                isExpanded: true,
                                icon: const Icon(Icons.filter_list, size: 18),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark
                                      ? Colors.white
                                      : Colors.grey.shade800,
                                ),
                                dropdownColor: isDark
                                    ? AppColors.cardDark
                                    : Colors.white,
                                items: departments.map((d) {
                                  return DropdownMenuItem(
                                    value: d,
                                    child: Text(
                                      d == 'All' ? 'All Departments' : d,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (v) => setState(
                                  () => _departmentFilter = v ?? 'All',
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Sort button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () =>
                            setState(() => _sortAscending = !_sortAscending),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.backgroundDark
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _sortAscending
                                    ? Icons.arrow_upward
                                    : Icons.arrow_downward,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _sortAscending ? 'A-Z' : 'Z-A',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ─── Employee List ───
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: employeesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                var docs = snapshot.data?.docs ?? [];

                // Filter by search
                if (_searchQuery.isNotEmpty) {
                  final q = _searchQuery.toLowerCase();
                  docs = docs.where((d) {
                    final data = d.data();
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    final email = (data['email'] ?? '')
                        .toString()
                        .toLowerCase();
                    return name.contains(q) || email.contains(q);
                  }).toList();
                }

                // Filter by department
                if (_departmentFilter != 'All') {
                  docs = docs.where((d) {
                    final dept = d.data()['department'] as String?;
                    return dept == _departmentFilter;
                  }).toList();
                }

                // Sort
                docs.sort((a, b) {
                  final aName = (a.data()['name'] ?? '')
                      .toString()
                      .toLowerCase();
                  final bName = (b.data()['name'] ?? '')
                      .toString()
                      .toLowerCase();
                  return _sortAscending
                      ? aName.compareTo(bName)
                      : bName.compareTo(aName);
                });

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: isDark ? Colors.white54 : Colors.black38,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No employees match your search'
                              : 'No employees registered',
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Count header
                return Column(
                  children: [
                    // Result count
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Text(
                            '${docs.length} employee${docs.length != 1 ? "s" : ""}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        cacheExtent: 1000,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data();
                          final userId = doc.id;
                          final name = data['name'] as String? ?? '-';
                          final email = data['email'] as String? ?? '-';
                          final department =
                              data['department'] as String? ?? '';
                          final position = data['position'] as String? ?? '';
                          final isActive = (data['isActive'] as bool?) ?? true;
                          final contact = data['contact'] as String? ?? '';

                          return _EmployeeCard(
                            userId: userId,
                            name: name,
                            email: email,
                            department: department,
                            position: position,
                            isActive: isActive,
                            contact: contact,
                            isDark: isDark,
                            attendanceRepo: attendanceRepo,
                            usersCollection: ref.read(usersCollectionProvider),
                            onView: () => context.push(
                              '/admin/employee-attendance/$userId?name=${Uri.encodeComponent(name)}',
                            ),
                            onEdit: () =>
                                _showEditDialog(context, userId, data, isDark),
                            onDelete: () =>
                                _showDeleteDialog(context, userId, name),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    String userId,
    Map<String, dynamic> data,
    bool isDark,
  ) {
    final nameCtrl = TextEditingController(text: data['name'] as String? ?? '');
    final deptCtrl = TextEditingController(
      text: data['department'] as String? ?? '',
    );
    final posCtrl = TextEditingController(
      text: data['position'] as String? ?? '',
    );
    final contactCtrl = TextEditingController(
      text: data['contact'] as String? ?? '',
    );
    bool isActive = (data['isActive'] as bool?) ?? true;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Employee'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: deptCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Department',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.business),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: posCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Position',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.work),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contactCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Contact',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Active'),
                      subtitle: Text(
                        isActive
                            ? 'Employee is active'
                            : 'Employee is inactive',
                      ),
                      value: isActive,
                      activeColor: AppColors.success,
                      onChanged: (v) => setDialogState(() => isActive = v),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await ref.read(usersCollectionProvider).doc(userId).update({
                      'name': nameCtrl.text.trim(),
                      'department': deptCtrl.text.trim(),
                      'position': posCtrl.text.trim(),
                      'contact': contactCtrl.text.trim(),
                      'isActive': isActive,
                    });
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Employee updated'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteDialog(BuildContext context, String userId, String name) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Employee'),
          content: Text(
            'Are you sure you want to delete "$name"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
              ),
              onPressed: () async {
                await ref.read(usersCollectionProvider).doc(userId).delete();
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('"$name" deleted'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────
//  Employee Card Widget
// ──────────────────────────────────────────────────────────

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({
    required this.userId,
    required this.name,
    required this.email,
    required this.department,
    required this.position,
    required this.isActive,
    required this.contact,
    required this.isDark,
    required this.attendanceRepo,
    required this.usersCollection,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  final String userId;
  final String name;
  final String email;
  final String department;
  final String position;
  final bool isActive;
  final String contact;
  final bool isDark;
  final AttendanceRepository attendanceRepo;
  final CollectionReference<Map<String, dynamic>> usersCollection;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(
        children: [
          // Top row: avatar + info + status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? AppColors.primary.withOpacity(0.1)
                      : AppColors.danger.withOpacity(0.1),
                  border: Border.all(
                    color: isActive
                        ? AppColors.primary.withOpacity(0.3)
                        : AppColors.danger.withOpacity(0.3),
                  ),
                ),
                child: Icon(
                  Icons.person,
                  color: isActive ? AppColors.primary : AppColors.danger,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              // Name + info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Active/Inactive badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.success.withOpacity(0.15)
                                : AppColors.danger.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          child: Text(
                            isActive ? 'ACTIVE' : 'INACTIVE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: isActive
                                  ? AppColors.success
                                  : AppColors.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                    if (department.isNotEmpty || position.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (department.isNotEmpty) ...[
                            Icon(
                              Icons.business,
                              size: 12,
                              color: isDark
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade400,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              department,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade500,
                              ),
                            ),
                          ],
                          if (department.isNotEmpty && position.isNotEmpty)
                            Text(
                              '  •  ',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          if (position.isNotEmpty) ...[
                            Icon(
                              Icons.work_outline,
                              size: 12,
                              color: isDark
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade400,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                position,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Today attendance status
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: attendanceRepo.streamUserLogs(userId),
            builder: (context, snap) {
              String status = 'Absent';
              String timeStr = '';

              if (snap.hasData && snap.data!.docs.isNotEmpty) {
                final today = DateTime.now();
                for (final doc in snap.data!.docs) {
                  final data = doc.data();
                  final checkIn = (data['checkIn'] as Timestamp?)?.toDate();
                  if (checkIn != null &&
                      checkIn.year == today.year &&
                      checkIn.month == today.month &&
                      checkIn.day == today.day) {
                    final checkOut = data['checkOut'] as Timestamp?;
                    timeStr = DateFormat('hh:mm a').format(checkIn);
                    if (checkIn.hour >= 9 && checkIn.minute > 0) {
                      status = 'Late';
                    } else {
                      status = 'Present';
                    }
                    if (checkOut != null) {
                      status = 'Done';
                      timeStr +=
                          ' - ${DateFormat("hh:mm a").format(checkOut.toDate())}';
                    }
                    break;
                  }
                }
              }

              Color badgeColor;
              switch (status) {
                case 'Present':
                  badgeColor = AppColors.success;
                  break;
                case 'Late':
                  badgeColor = AppColors.warning;
                  break;
                case 'Done':
                  badgeColor = Colors.grey;
                  break;
                default:
                  badgeColor = AppColors.danger;
              }

              return Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(9999),
                      border: Border.all(color: badgeColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: badgeColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: badgeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (timeStr.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade500,
                      ),
                    ),
                  ],
                  const Spacer(),
                  // Action buttons
                  _ActionIcon(
                    icon: Icons.visibility_outlined,
                    tooltip: 'View Attendance',
                    color: AppColors.primary,
                    isDark: isDark,
                    onTap: onView,
                  ),
                  const SizedBox(width: 4),
                  _ActionIcon(
                    icon: Icons.edit_outlined,
                    tooltip: 'Edit',
                    color: AppColors.warning,
                    isDark: isDark,
                    onTap: onEdit,
                  ),
                  const SizedBox(width: 4),
                  _ActionIcon(
                    icon: Icons.delete_outline,
                    tooltip: 'Delete',
                    color: AppColors.danger,
                    isDark: isDark,
                    onTap: onDelete,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }
}
