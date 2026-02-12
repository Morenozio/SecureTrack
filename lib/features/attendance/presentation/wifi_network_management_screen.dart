import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/animated_page.dart';
import '../../../core/widgets/app_background.dart';
import '../application/wifi_network_controller.dart';
import '../data/wifi_network_repository.dart';

class WifiNetworkManagementScreen extends ConsumerStatefulWidget {
  const WifiNetworkManagementScreen({super.key});

  @override
  ConsumerState<WifiNetworkManagementScreen> createState() =>
      _WifiNetworkManagementScreenState();
}

class _WifiNetworkManagementScreenState
    extends ConsumerState<WifiNetworkManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ssidController = TextEditingController();
  final _bssidController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isAdding = false;

  @override
  void dispose() {
    _ssidController.dispose();
    _bssidController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _showAddDialog() async {
    _ssidController.clear();
    _bssidController.clear();
    _descriptionController.clear();
    _isAdding = false;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah WiFi Network'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _ssidController,
                  decoration: const InputDecoration(
                    labelText: 'SSID (Nama WiFi)',
                    hintText: 'Contoh: Office-WiFi',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'SSID wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bssidController,
                  decoration: const InputDecoration(
                    labelText: 'BSSID (MAC Address Router)',
                    hintText: 'Contoh: aa:bb:cc:dd:ee:ff',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'BSSID wajib diisi';
                    }
                    // Basic BSSID format validation (MAC address format)
                    final bssidPattern = RegExp(
                      r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$',
                    );
                    if (!bssidPattern.hasMatch(value.trim())) {
                      return 'Format BSSID tidak valid (gunakan format MAC: aa:bb:cc:dd:ee:ff)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Deskripsi (Opsional)',
                    hintText: 'Contoh: WiFi Ruang Meeting',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: _isAdding
                ? null
                : () async {
                    if (_formKey.currentState!.validate()) {
                      setState(() => _isAdding = true);
                      try {
                        await ref
                            .read(wifiNetworkControllerProvider.notifier)
                            .addNetwork(
                              ssid: _ssidController.text.trim(),
                              bssid: _bssidController.text.trim(),
                              description:
                                  _descriptionController.text.trim().isEmpty
                                  ? null
                                  : _descriptionController.text.trim(),
                            );

                        if (!mounted) return;

                        // Check if there's an error in the state
                        final state = ref.read(wifiNetworkControllerProvider);
                        if (state.hasError) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: ${state.error}')),
                          );
                        } else {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'WiFi network berhasil ditambahkan',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      } finally {
                        if (mounted) {
                          setState(() => _isAdding = false);
                        }
                      }
                    }
                  },
            child: _isAdding
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Tambah'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteNetwork(String networkId, String ssid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus WiFi Network'),
        content: Text('Apakah Anda yakin ingin menghapus "$ssid"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref
            .read(wifiNetworkControllerProvider.notifier)
            .deleteNetwork(networkId);

        if (!mounted) return;

        final state = ref.read(wifiNetworkControllerProvider);
        if (state.hasError) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${state.error}')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('WiFi network berhasil dihapus')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Widget _buildNetworkCard(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    TextTheme textTheme,
  ) {
    try {
      final data = doc.data();
      if (data.isEmpty) {
        return const SizedBox.shrink();
      }

      final network = WifiNetworkModel.fromMap(doc.id, data);

      return Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.accent.withOpacity(0.15),
            child: const Icon(Icons.wifi, color: AppColors.accent),
          ),
          title: Text(
            network.ssid.isNotEmpty ? network.ssid : 'Unknown',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text('BSSID: ${network.bssid}'),
              if (network.description != null &&
                  network.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(network.description!),
              ],
            ],
          ),
          isThreeLine:
              network.description != null && network.description!.isNotEmpty,
          trailing: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _deleteNetwork(network.id, network.ssid),
            tooltip: 'Hapus',
          ),
        ),
      );
    } catch (e) {
      return Card(
        color: Colors.red.shade50,
        child: ListTile(
          leading: const Icon(Icons.error, color: Colors.red),
          title: const Text('Error loading network'),
          subtitle: Text('$e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wifiRepo = ref.watch(wifiNetworkRepositoryProvider);

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
        title: const Text('Kelola WiFi Networks'),
      ),
      body: AnimatedPage(
        child: SafeArea(
          child: AppBackground(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final button = ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth:
                              190, // cegah Row memberi lebar tak hingga di web
                          minHeight: 40,
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _showAddDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Tambah WiFi'),
                        ),
                      );

                      // Jika ruang sempit (misal mobile), jadikan kolom agar tidak memaksa lebar tak hingga.
                      if (constraints.maxWidth < 400) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'WiFi Networks Terdaftar',
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : null,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: button,
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(
                            child: Text(
                              'WiFi Networks Terdaftar',
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : null,
                              ),
                            ),
                          ),
                          button,
                        ],
                      );
                    },
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: wifiRepo.streamAllNetworks(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: Colors.red,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Error: ${snapshot.error}',
                                  style: textTheme.bodyLarge?.copyWith(
                                    color: Colors.red,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () => setState(() {}),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Refresh'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final docs = snapshot.data?.docs ?? [];

                      late final List<
                        QueryDocumentSnapshot<Map<String, dynamic>>
                      >
                      sortedDocs;
                      try {
                        sortedDocs = docs.toList()
                          ..sort((a, b) {
                            final aSsid = (a.data()['ssid'] ?? '').toString();
                            final bSsid = (b.data()['ssid'] ?? '').toString();
                            return aSsid.compareTo(bSsid);
                          });
                      } catch (e) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: Colors.red,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Gagal memuat data WiFi: $e',
                                  style: textTheme.bodyLarge?.copyWith(
                                    color: Colors.red,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () => setState(() {}),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Coba Lagi'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      if (sortedDocs.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.wifi_off,
                                  size: 64,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black54,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Belum ada WiFi network terdaftar',
                                  style: textTheme.bodyLarge?.copyWith(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tambahkan WiFi network kantor untuk sistem absensi berbasis WiFi',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.black54,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: sortedDocs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return _buildNetworkCard(
                            sortedDocs[index],
                            textTheme,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
