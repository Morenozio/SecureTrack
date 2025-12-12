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
              decoration: const InputDecoration(labelText: 'Catatan'),
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Permohonan cuti dikirim')),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString())),
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
                  return const LinearProgressIndicator();
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Text(
                    'Belum ada permohonan cuti',
                    style: TextStyle(color: isDark ? Colors.white70 : null),
                  );
                }
                return Column(
                  children: docs.map((d) {
                    final data = d.data();
                    final type = data['type'] ?? '-';
                    final status = data['status'] ?? '-';
                    final notes = data['notes'] ?? '';
                    final created = (data['createdAt'] as Timestamp?)?.toDate();
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.event_note),
                        title: Text('$type • ${created ?? '-'}'),
                        subtitle: Text('Status: $status\nCatatan: $notes'),
                        trailing: status == 'Menunggu'
                            ? const Icon(Icons.hourglass_top)
                            : const Icon(Icons.check_circle),
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

