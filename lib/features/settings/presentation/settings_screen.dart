import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/animated_page.dart';
import '../../auth/application/auth_controller.dart';

/// Firestore collection for app settings
final _settingsDoc = FirebaseFirestore.instance
    .collection('settings')
    .doc('app_config');

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Company
  final _companyNameCtrl = TextEditingController();
  final _companyAddressCtrl = TextEditingController();

  // Work hours
  TimeOfDay _workStart = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _workEnd = const TimeOfDay(hour: 17, minute: 0);
  int _lateThresholdMinutes = 15;

  // Rules
  bool _requireWifi = true;
  bool _autoAbsent = true;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _companyNameCtrl.dispose();
    _companyAddressCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final doc = await _settingsDoc.get();
      if (doc.exists) {
        final data = doc.data()!;
        _companyNameCtrl.text = data['companyName'] as String? ?? '';
        _companyAddressCtrl.text = data['companyAddress'] as String? ?? '';

        final startHour = data['workStartHour'] as int? ?? 8;
        final startMin = data['workStartMinute'] as int? ?? 0;
        _workStart = TimeOfDay(hour: startHour, minute: startMin);

        final endHour = data['workEndHour'] as int? ?? 17;
        final endMin = data['workEndMinute'] as int? ?? 0;
        _workEnd = TimeOfDay(hour: endHour, minute: endMin);

        _lateThresholdMinutes = data['lateThresholdMinutes'] as int? ?? 15;
        _requireWifi = (data['requireWifi'] as bool?) ?? true;
        _autoAbsent = (data['autoAbsent'] as bool?) ?? true;
      }
    } catch (_) {
      // Use defaults on error
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      await _settingsDoc.set({
        'companyName': _companyNameCtrl.text.trim(),
        'companyAddress': _companyAddressCtrl.text.trim(),
        'workStartHour': _workStart.hour,
        'workStartMinute': _workStart.minute,
        'workEndHour': _workEnd.hour,
        'workEndMinute': _workEnd.minute,
        'lateThresholdMinutes': _lateThresholdMinutes,
        'requireWifi': _requireWifi,
        'autoAbsent': _autoAbsent,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        title: const Text('Settings'),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _saveSettings,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save, size: 18),
            label: Text(_isSaving ? 'Saving...' : 'Save'),
          ),
        ],
      ),
      body: AnimatedPage(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ─── Company Info ───
                  _SectionHeader(title: 'Company Information', isDark: isDark),
                  const SizedBox(height: 12),
                  _SettingsCard(
                    isDark: isDark,
                    children: [
                      TextField(
                        controller: _companyNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Company Name',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.business),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _companyAddressCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Company Address',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_on),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ─── Work Hours ───
                  _SectionHeader(title: 'Work Hours', isDark: isDark),
                  const SizedBox(height: 12),
                  _SettingsCard(
                    isDark: isDark,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _TimeTile(
                              label: 'Start Time',
                              time: _workStart,
                              isDark: isDark,
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: _workStart,
                                );
                                if (picked != null) {
                                  setState(() => _workStart = picked);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _TimeTile(
                              label: 'End Time',
                              time: _workEnd,
                              isDark: isDark,
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: _workEnd,
                                );
                                if (picked != null) {
                                  setState(() => _workEnd = picked);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Late Threshold (minutes)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Mark as late after $_lateThresholdMinutes min past start time',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: _lateThresholdMinutes > 0
                                    ? () => setState(
                                        () => _lateThresholdMinutes--,
                                      )
                                    : null,
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  size: 20,
                                ),
                              ),
                              Container(
                                width: 40,
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.backgroundDark
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '$_lateThresholdMinutes',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () =>
                                    setState(() => _lateThresholdMinutes++),
                                icon: const Icon(
                                  Icons.add_circle_outline,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ─── Attendance Rules ───
                  _SectionHeader(title: 'Attendance Rules', isDark: isDark),
                  const SizedBox(height: 12),
                  _SettingsCard(
                    isDark: isDark,
                    children: [
                      SwitchListTile(
                        title: const Text('Require WiFi Verification'),
                        subtitle: const Text(
                          'Employees must be on office WiFi to check in',
                        ),
                        value: _requireWifi,
                        activeColor: AppColors.primary,
                        onChanged: (v) => setState(() => _requireWifi = v),
                      ),
                      Divider(
                        height: 1,
                        color: isDark
                            ? AppColors.primary.withOpacity(0.1)
                            : Colors.grey.shade200,
                      ),
                      SwitchListTile(
                        title: const Text('Auto-mark Absent'),
                        subtitle: const Text(
                          'Automatically mark employees absent if not checked in by end of day',
                        ),
                        value: _autoAbsent,
                        activeColor: AppColors.primary,
                        onChanged: (v) => setState(() => _autoAbsent = v),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ─── Appearance ───
                  _SectionHeader(title: 'Appearance', isDark: isDark),
                  const SizedBox(height: 12),
                  _SettingsCard(
                    isDark: isDark,
                    children: [
                      ListTile(
                        leading: Icon(
                          isDark ? Icons.dark_mode : Icons.light_mode,
                          color: AppColors.primary,
                        ),
                        title: const Text('Dark Mode'),
                        subtitle: Text(
                          isDark ? 'Currently dark' : 'Currently light',
                        ),
                        trailing: Switch(
                          value: isDark,
                          activeColor: AppColors.primary,
                          onChanged: (_) => ref
                              .read(themeModeProvider.notifier)
                              .toggleTheme(),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ─── Quick Links ───
                  _SectionHeader(title: 'Administration', isDark: isDark),
                  const SizedBox(height: 12),
                  _SettingsCard(
                    isDark: isDark,
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.admin_panel_settings,
                          color: AppColors.primary,
                        ),
                        title: const Text('Manage Admin Roles'),
                        subtitle: const Text('Promote/demote users'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/admin/users'),
                      ),
                      Divider(
                        height: 1,
                        color: isDark
                            ? AppColors.primary.withOpacity(0.1)
                            : Colors.grey.shade200,
                      ),
                      ListTile(
                        leading: Icon(Icons.wifi, color: AppColors.primary),
                        title: const Text('WiFi Networks'),
                        subtitle: const Text('Manage office WiFi list'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/admin/wifi-networks'),
                      ),
                      Divider(
                        height: 1,
                        color: isDark
                            ? AppColors.primary.withOpacity(0.1)
                            : Colors.grey.shade200,
                      ),
                      ListTile(
                        leading: Icon(Icons.logout, color: AppColors.danger),
                        title: Text(
                          'Sign Out',
                          style: TextStyle(color: AppColors.danger),
                        ),
                        onTap: () {
                          ref.read(authControllerProvider.notifier).signOut();
                          context.go('/auth');
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                ],
              ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
//  Settings Widgets
// ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.isDark});

  final String title;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.isDark, required this.children});

  final bool isDark;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? AppColors.primary.withOpacity(0.1)
              : Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.label,
    required this.time,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final TimeOfDay time;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final formatted =
        '${time.hourOfPeriod.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} ${time.period == DayPeriod.am ? 'AM' : 'PM'}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.backgroundDark : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark
                ? AppColors.primary.withOpacity(0.2)
                : Colors.grey.shade300,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  formatted,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
