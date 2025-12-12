import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../../attendance/application/attendance_controller.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../auth/data/user_providers.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  String? _currentSsid;
  String? _currentBssid;
  bool _isLoadingWifi = false;
  String? _wifiError;
  bool _showManualInput = false;
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _bssidController = TextEditingController();

  @override
  void dispose() {
    _ssidController.dispose();
    _bssidController.dispose();
    super.dispose();
  }

  Future<void> _loadWifiInfo() async {
    // For now, WiFi auto-detect is not available
    // User needs to enter manually or we need to implement platform channel
    setState(() {
      _isLoadingWifi = false;
      _wifiError = 'Auto-detect WiFi tidak tersedia.\nSilakan masukkan SSID dan BSSID secara manual.';
      _showManualInput = true;
    });
  }

  void _applyManualInput() {
    setState(() {
      _currentSsid = _ssidController.text.trim().isEmpty ? null : _ssidController.text.trim();
      _currentBssid = _bssidController.text.trim().isEmpty ? null : _bssidController.text.trim();
      if (_currentSsid != null && _currentBssid != null) {
        _wifiError = null;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadWifiInfo();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.valueOrNull;
    final Stream<QuerySnapshot<Map<String, dynamic>>> logsStream = user == null
        ? Stream<QuerySnapshot<Map<String, dynamic>>>.empty()
        : ref.watch(attendanceRepositoryProvider).streamUserLogs(user.id);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/dashboard/employee');
            }
          },
        ),
        title: const Text('Absensi'),
        actions: [
          IconButton(
            tooltip: 'Riwayat',
            onPressed: () => context.push('/attendance/history'),
            icon: const Icon(Icons.history),
          ),
        ],
      ),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            userAsync.when(
              data: (u) => Text(
                u == null ? 'Tidak ada data user' : 'Halo, ${u.name}',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : null,
                ),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error user: $e'),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Check-in / Check-out', style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : null,
                    )),
                    const SizedBox(height: 10),
                    // WiFi Status Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.blue.withOpacity(0.1)
                            : Colors.blue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark
                              ? Colors.blue.withOpacity(0.3)
                              : Colors.blue.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.wifi,
                                size: 20,
                                color: _currentSsid != null && _currentBssid != null
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Status WiFi',
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : null,
                                ),
                              ),
                              const Spacer(),
                              if (_isLoadingWifi)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              else
                                IconButton(
                                  icon: const Icon(Icons.refresh, size: 18),
                                  onPressed: _loadWifiInfo,
                                  tooltip: 'Refresh',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_wifiError != null)
                            Text(
                              _wifiError!,
                              style: textTheme.bodySmall?.copyWith(
                                color: Colors.red,
                              ),
                            )
                          else if (_currentSsid == null || _currentBssid == null) ...[
                            Text(
                              'Tidak terhubung ke WiFi atau informasi tidak tersedia',
                              style: textTheme.bodySmall?.copyWith(
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_showManualInput) ...[
                              TextField(
                                controller: _ssidController,
                                decoration: const InputDecoration(
                                  labelText: 'SSID (Nama WiFi)',
                                  hintText: 'Masukkan nama WiFi',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _bssidController,
                                decoration: const InputDecoration(
                                  labelText: 'BSSID (MAC Address)',
                                  hintText: 'aa:bb:cc:dd:ee:ff',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: _applyManualInput,
                                icon: const Icon(Icons.check, size: 18),
                                label: const Text('Terapkan'),
                              ),
                            ] else
                              TextButton.icon(
                                onPressed: () => setState(() => _showManualInput = true),
                                icon: const Icon(Icons.edit, size: 18),
                                label: const Text('Masukkan Manual'),
                              ),
                          ] else ...[
                            Text(
                              'SSID: $_currentSsid',
                              style: textTheme.bodySmall?.copyWith(
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'BSSID: $_currentBssid',
                              style: textTheme.bodySmall?.copyWith(
                                color: isDark ? Colors.white70 : Colors.black87,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: (user == null || _currentSsid == null || _currentBssid == null || _isLoadingWifi)
                                ? null
                                : () async {
                                    if (_currentSsid == null || _currentBssid == null || user == null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Tidak dapat membaca informasi WiFi. Pastikan perangkat terhubung ke WiFi.'),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                      return;
                                    }
                                    
                                    await ref.read(attendanceControllerProvider.notifier).checkIn(
                                          user,
                                          ssid: _currentSsid!,
                                          bssid: _currentBssid!,
                                        );
                                    
                                    if (!mounted) return;
                                    final state = ref.read(attendanceControllerProvider);
                                    if (state.hasError) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(state.error.toString()),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Check-in berhasil!'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  },
                            icon: const Icon(Icons.login),
                            label: const Text('Check-in'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: user == null
                                ? null
                                : () async {
                                    await ref.read(attendanceControllerProvider.notifier).checkOut(user);
                                    if (!mounted) return;
                                    final state = ref.read(attendanceControllerProvider);
                                    if (state.hasError) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(state.error.toString()),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Check-out berhasil!'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  },
                            icon: const Icon(Icons.logout),
                            label: const Text('Check-out'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Log Absensi', style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : null,
                    )),
                    const SizedBox(height: 8),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: logsStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(8),
                            child: LinearProgressIndicator(),
                          );
                        }
                        final docs = snapshot.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return const ListTile(
                            title: Text('Belum ada data absensi'),
                          );
                        }
                        return Column(
                          children: docs.map((d) {
                            final data = d.data();
                            final checkIn = (data['checkIn'] as Timestamp?)?.toDate();
                            final checkOut = (data['checkOut'] as Timestamp?)?.toDate();
                            final method = data['method'] ?? '-';
                            final wifiSsid = data['wifiSsid'] as String?;
                            final wifiBssid = data['wifiBssid'] as String?;
                            return ListTile(
                              leading: const Icon(Icons.access_time),
                              title: Text('Metode: $method'),
                              subtitle: Text(
                                'In: ${checkIn ?? '-'}\n'
                                'Out: ${checkOut ?? '-'}'
                                '${wifiSsid != null ? '\nWiFi: $wifiSsid' : ''}'
                                '${wifiBssid != null ? '\nBSSID: $wifiBssid' : ''}',
                              ),
                              isThreeLine: true,
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AttendanceHistoryScreen extends ConsumerWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final Stream<QuerySnapshot<Map<String, dynamic>>> logsStream = user == null
        ? Stream<QuerySnapshot<Map<String, dynamic>>>.empty()
        : ref.watch(attendanceRepositoryProvider).streamUserLogs(user.id);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/dashboard/employee');
            }
          },
        ),
        title: const Text('Riwayat Absensi'),
      ),
      body: AppBackground(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: logsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LinearProgressIndicator();
            }
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Center(child: Text('Belum ada data absensi'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final data = docs[index].data();
                final checkIn = (data['checkIn'] as Timestamp?)?.toDate();
                final checkOut = (data['checkOut'] as Timestamp?)?.toDate();
                final method = data['method'] ?? '-';
                final wifiSsid = data['wifiSsid'] as String?;
                final wifiBssid = data['wifiBssid'] as String?;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.accent.withOpacity(0.15),
                      child: const Icon(Icons.wifi_lock, color: AppColors.accent),
                    ),
                    title: Text('Metode: $method'),
                    subtitle: Text(
                      'In: ${checkIn ?? '-'}\n'
                      'Out: ${checkOut ?? '-'}'
                      '${wifiSsid != null ? '\nWiFi: $wifiSsid' : ''}'
                      '${wifiBssid != null ? '\nBSSID: $wifiBssid' : ''}',
                    ),
                    isThreeLine: true,
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemCount: docs.length,
            );
          },
        ),
      ),
    );
  }
}

class QrBackupScreen extends StatelessWidget {
  const QrBackupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        leading: context.canPop() ? const BackButton() : null,
        title: const Text('QR Backup Mode'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Aktif karena WiFi & GPS gagal', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(
              'Admin harus membuat QR time-limited. Pemindaian akan mencatat device ID, timestamp, admin ID, dan alasan fallback.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Center(
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.accent.withOpacity(0.4)),
                  ),
                  child: const Center(
                    child: Icon(Icons.qr_code_2, size: 120, color: AppColors.accent),
                  ),
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Pemindaian QR (stub). Integrasikan scanner & token signature.')),
                );
                context.go('/attendance');
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan QR'),
            ),
          ],
        ),
      ),
    );
  }
}

