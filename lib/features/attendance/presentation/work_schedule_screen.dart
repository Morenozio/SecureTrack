import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/animated_page.dart';
import '../../../core/widgets/app_background.dart';
import '../data/work_schedule_repository.dart';
import '../data/work_schedule_model.dart';

class WorkScheduleScreen extends ConsumerStatefulWidget {
  final String userId;
  final String userName;

  const WorkScheduleScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  ConsumerState<WorkScheduleScreen> createState() => _WorkScheduleScreenState();
}

class _WorkScheduleScreenState extends ConsumerState<WorkScheduleScreen> {
  WorkSchedule _schedule = WorkSchedule(
    workHoursEnabled: true,
    shiftStart: const TimeOfDay(hour: 9, minute: 0),
    shiftEnd: const TimeOfDay(hour: 17, minute: 0),
    toleranceMinutes: 15,
    minWorkingHours: 8,
    workDays: {
      'monday': true,
      'tuesday': true,
      'wednesday': true,
      'thursday': true,
      'friday': true,
      'saturday': false,
      'sunday': false,
    },
  );
  bool _isLoading = false;
  bool _isSaving = false;

  Future<void> _pickTime(
    BuildContext context, {
    required TimeOfDay initial,
    required void Function(TimeOfDay) onSelected,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) onSelected(picked);
  }

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    setState(() => _isLoading = true);
    try {
      final schedule = await ref
          .read(workScheduleRepositoryProvider)
          .getEmployeeSchedule(widget.userId);
      // Repository now returns a WorkSchedule object (default or specific)
      if (mounted) {
        setState(() => _schedule = schedule);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading schedule: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveSchedule() async {
    setState(() => _isSaving = true);
    try {
      await ref
          .read(workScheduleRepositoryProvider)
          .setEmployeeSchedule(userId: widget.userId, schedule: _schedule);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Jadwal kerja berhasil disimpan'),
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
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
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
          title: const Text('Jadwal Kerja'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

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
        title: Text('Jadwal Kerja - ${widget.userName}'),
      ),
      body: AnimatedPage(
        child: AppBackground(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Jam Kerja',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _schedule.workHoursEnabled
                            ? 'Jika diaktifkan, karyawan harus mengikuti jam masuk dan keluar. Check-in di luar jam = Terlambat.'
                            : 'Jika dinonaktifkan, karyawan dapat check-in kapan saja tanpa batas waktu.',
                        style: textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: Text(
                          'Aktifkan jam kerja',
                          style: textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : null,
                          ),
                        ),
                        subtitle: Text(
                          _schedule.workHoursEnabled
                              ? 'Mulai & selesai wajib diatur'
                              : 'Check-in bebas kapan saja',
                          style: textTheme.bodySmall?.copyWith(
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                        value: _schedule.workHoursEnabled,
                        onChanged: (value) {
                          setState(() {
                            _schedule = WorkSchedule(
                              workHoursEnabled: value,
                              shiftStart: _schedule.shiftStart,
                              shiftEnd: _schedule.shiftEnd,
                              toleranceMinutes: _schedule.toleranceMinutes,
                              minWorkingHours: _schedule.minWorkingHours,
                              workDays: _schedule.workDays,
                            );
                          });
                        },
                        activeColor: AppColors.accent,
                      ),
                      if (_schedule.workHoursEnabled) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        ListTile(
                          title: Text(
                            'Jam mulai',
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white : null,
                            ),
                          ),
                          trailing: TextButton.icon(
                            onPressed: () => _pickTime(
                              context,
                              initial: _schedule.shiftStart,
                              onSelected: (t) {
                                setState(() {
                                  _schedule = WorkSchedule(
                                    workHoursEnabled: _schedule.workHoursEnabled,
                                    shiftStart: t,
                                    shiftEnd: _schedule.shiftEnd,
                                    toleranceMinutes:
                                        _schedule.toleranceMinutes,
                                    minWorkingHours: _schedule.minWorkingHours,
                                    workDays: _schedule.workDays,
                                  );
                                });
                              },
                            ),
                            icon: const Icon(Icons.access_time),
                            label: Text(
                              '${_schedule.shiftStart.hour.toString().padLeft(2, '0')}:${_schedule.shiftStart.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        ListTile(
                          title: Text(
                            'Jam selesai',
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white : null,
                            ),
                          ),
                          trailing: TextButton.icon(
                            onPressed: () => _pickTime(
                              context,
                              initial: _schedule.shiftEnd,
                              onSelected: (t) {
                                setState(() {
                                  _schedule = WorkSchedule(
                                    workHoursEnabled: _schedule.workHoursEnabled,
                                    shiftStart: _schedule.shiftStart,
                                    shiftEnd: t,
                                    toleranceMinutes:
                                        _schedule.toleranceMinutes,
                                    minWorkingHours: _schedule.minWorkingHours,
                                    workDays: _schedule.workDays,
                                  );
                                });
                              },
                            ),
                            icon: const Icon(Icons.access_time),
                            label: Text(
                              '${_schedule.shiftEnd.hour.toString().padLeft(2, '0')}:${_schedule.shiftEnd.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        ListTile(
                          title: Text(
                            'Toleransi keterlambatan (menit)',
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white : null,
                            ),
                          ),
                          subtitle: Text(
                            '${_schedule.toleranceMinutes} menit setelah jam mulai',
                            style: textTheme.bodySmall?.copyWith(
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          trailing: SizedBox(
                            width: 80,
                            child: TextFormField(
                              initialValue:
                                  _schedule.toleranceMinutes.toString(),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (v) {
                                final n = int.tryParse(v) ?? _schedule.toleranceMinutes;
                                setState(() {
                                  _schedule = WorkSchedule(
                                    workHoursEnabled:
                                        _schedule.workHoursEnabled,
                                    shiftStart: _schedule.shiftStart,
                                    shiftEnd: _schedule.shiftEnd,
                                    toleranceMinutes: n.clamp(0, 120),
                                    minWorkingHours: _schedule.minWorkingHours,
                                    workDays: _schedule.workDays,
                                  );
                                });
                              },
                            ),
                          ),
                        ),
                        ListTile(
                          title: Text(
                            'Jam kerja minimum',
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white : null,
                            ),
                          ),
                          subtitle: Text(
                            'Check-out sebelum ini = Pulang awal',
                            style: textTheme.bodySmall?.copyWith(
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          trailing: SizedBox(
                            width: 80,
                            child: TextFormField(
                              initialValue:
                                  _schedule.minWorkingHours.toString(),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (v) {
                                final n = int.tryParse(v) ?? _schedule.minWorkingHours;
                                setState(() {
                                  _schedule = WorkSchedule(
                                    workHoursEnabled:
                                        _schedule.workHoursEnabled,
                                    shiftStart: _schedule.shiftStart,
                                    shiftEnd: _schedule.shiftEnd,
                                    toleranceMinutes: _schedule.toleranceMinutes,
                                    minWorkingHours: n.clamp(1, 24),
                                    workDays: _schedule.workDays,
                                  );
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Atur Hari Kerja',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pilih hari kerja untuk ${widget.userName}',
                        style: textTheme.bodyMedium?.copyWith(
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildDayToggle('monday', 'Senin', textTheme, isDark),
                      _buildDayToggle('tuesday', 'Selasa', textTheme, isDark),
                      _buildDayToggle('wednesday', 'Rabu', textTheme, isDark),
                      _buildDayToggle('thursday', 'Kamis', textTheme, isDark),
                      _buildDayToggle('friday', 'Jumat', textTheme, isDark),
                      _buildDayToggle('saturday', 'Sabtu', textTheme, isDark),
                      _buildDayToggle('sunday', 'Minggu', textTheme, isDark),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveSchedule,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(
                          _isSaving ? 'Menyimpan...' : 'Simpan Jadwal',
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayToggle(
    String key,
    String label,
    TextTheme textTheme,
    bool isDark,
  ) {
    return SwitchListTile(
      title: Text(
        label,
        style: textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : null,
        ),
      ),
      value: _schedule.workDays[key] ?? false,
      onChanged: (value) {
        setState(() {
          // Create a new map to ensure immutability if needed, though here we just modify the map
          final newWorkDays = Map<String, bool>.from(_schedule.workDays);
          newWorkDays[key] = value;

          _schedule = WorkSchedule(
            workHoursEnabled: _schedule.workHoursEnabled,
            shiftStart: _schedule.shiftStart,
            shiftEnd: _schedule.shiftEnd,
            toleranceMinutes: _schedule.toleranceMinutes,
            minWorkingHours: _schedule.minWorkingHours,
            workDays: newWorkDays,
          );
        });
      },
      activeColor: AppColors.accent,
    );
  }
}
