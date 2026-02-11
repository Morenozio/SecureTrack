import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/data/user_providers.dart';
import '../application/leave_controller.dart';
import '../data/leave_repository.dart';
import '../../../core/widgets/app_background.dart';

class LeaveRequestScreen extends ConsumerStatefulWidget {
  const LeaveRequestScreen({super.key});

  @override
  ConsumerState<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends ConsumerState<LeaveRequestScreen> {
  String type = 'Sakit';
  String notes = '';
  final TextEditingController _notesController = TextEditingController();
  
  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider).valueOrNull;
    final Stream<QuerySnapshot<Map<String, dynamic>>> leavesStream = user == null
        ? Stream<QuerySnapshot<Map<String, dynamic>>>.empty()
        : ref.watch(leaveRepositoryProvider).streamMyLeave(user.id);
    final leaveState = ref.watch(leaveControllerProvider);

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
        title: const Text('Permohonan Cuti'),
      ),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Ajukan Cuti', style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : null,
            )),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: type,
              items: const [
                DropdownMenuItem(value: 'Sakit', child: Text('Sakit')),
                DropdownMenuItem(value: 'Cuti', child: Text('Cuti')),
                DropdownMenuItem(value: 'Pribadi', child: Text('Pribadi')),
              ],
              onChanged: (v) => setState(() => type = v ?? 'Sakit'),
              decoration: const InputDecoration(labelText: 'Jenis'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Catatan',
                hintText: 'Masukkan alasan atau detail permohonan cuti...',
                helperText: 'Contoh: Sakit demam, Cuti keluarga, dll.',
              ),
              maxLines: 3,
              onChanged: (v) => setState(() => notes = v),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: user == null || leaveState.isLoading
                  ? null
                  : () async {
                      try {
                        await ref
                            .read(leaveControllerProvider.notifier)
                            .submit(user, type: type, notes: notes);
                        if (!mounted) return;
                        // Reset form after successful submission
                        setState(() {
                          type = 'Sakit';
                          notes = '';
                        });
                        _notesController.clear();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Permohonan cuti berhasil dikirim! Status: Menunggu persetujuan admin.'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 3),
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              child: leaveState.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Kirim Permohonan'),
            ),
            const SizedBox(height: 20),
            Text('Riwayat Cuti', style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : null,
            )),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: leavesStream,
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
                        ],
                      ),
                    ),
                  );
                }
                
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_busy,
                            size: 64,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Belum ada permohonan cuti',
                            style: textTheme.bodyLarge?.copyWith(
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                
                // Sort by createdAt descending on client side
                final sortedDocs = docs.toList()
                  ..sort((a, b) {
                    final aTime = (a.data()['createdAt'] as Timestamp?)?.toDate();
                    final bTime = (b.data()['createdAt'] as Timestamp?)?.toDate();
                    if (aTime == null && bTime == null) return 0;
                    if (aTime == null) return 1;
                    if (bTime == null) return -1;
                    return bTime.compareTo(aTime); // Descending
                  });
                
                return Column(
                  children: sortedDocs.map((d) {
                    final data = d.data();
                    final type = data['type'] ?? '-';
                    final status = data['status'] ?? '-';
                    final notes = data['notes'] ?? '';
                    final adminNotes = data['adminNotes'] as String?;
                    final created = (data['createdAt'] as Timestamp?)?.toDate();
                    final processedAt = (data['processedAt'] as Timestamp?)?.toDate();
                    
                    // Determine status color and icon
                    Color statusColor;
                    IconData statusIcon;
                    switch (status) {
                      case 'Diterima':
                        statusColor = Colors.green;
                        statusIcon = Icons.check_circle;
                        break;
                      case 'Ditolak':
                        statusColor = Colors.red;
                        statusIcon = Icons.cancel;
                        break;
                      default:
                        statusColor = Colors.orange;
                        statusIcon = Icons.hourglass_top;
                    }
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: statusColor.withOpacity(0.15),
                          child: Icon(statusIcon, color: statusColor, size: 20),
                        ),
                        title: Text(
                          type,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: statusColor.withOpacity(0.3)),
                              ),
                              child: Text(
                                'Status: $status',
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            if (created != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Diajukan: ${created.toString().split(' ')[0]} ${created.toString().split(' ')[1].substring(0, 5)}',
                                style: textTheme.bodySmall?.copyWith(
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: Icon(
                          status == 'Menunggu'
                              ? Icons.hourglass_top
                              : status == 'Diterima'
                                  ? Icons.check_circle
                                  : Icons.cancel,
                          color: statusColor,
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (notes.isNotEmpty) ...[
                                  Text(
                                    'Catatan Anda:',
                                    style: textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      notes,
                                      style: textTheme.bodyMedium,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                if (adminNotes != null && adminNotes.isNotEmpty) ...[
                                  Text(
                                    'Catatan Admin:',
                                    style: textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: statusColor.withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      adminNotes,
                                      style: textTheme.bodyMedium?.copyWith(color: statusColor),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                if (processedAt != null) ...[
                                  Text(
                                    'Diproses: ${processedAt.toString().split(' ')[0]} ${processedAt.toString().split(' ')[1].substring(0, 5)}',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: isDark ? Colors.white60 : Colors.black54,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

