import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/animated_page.dart';
import '../../../core/widgets/app_background.dart';
import '../../auth/data/user_providers.dart';
import '../application/leave_controller.dart';
import '../data/leave_repository.dart';

class LeaveInboxScreen extends ConsumerStatefulWidget {
  const LeaveInboxScreen({super.key});

  @override
  ConsumerState<LeaveInboxScreen> createState() => _LeaveInboxScreenState();
}

class _LeaveInboxScreenState extends ConsumerState<LeaveInboxScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'Semua'; // Semua, Menunggu, Diterima, Ditolak

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          switch (_tabController.index) {
            case 0:
              _selectedFilter = 'Semua';
              break;
            case 1:
              _selectedFilter = 'Menunggu';
              break;
            case 2:
              _selectedFilter = 'Diterima';
              break;
            case 3:
              _selectedFilter = 'Ditolak';
              break;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleApprove(String leaveId, String employeeName) async {
    final adminNotesController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Terima Permohonan Cuti - $employeeName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Apakah Anda yakin ingin menerima permohonan cuti ini?'),
            const SizedBox(height: 12),
            TextField(
              controller: adminNotesController,
              decoration: const InputDecoration(
                labelText: 'Catatan Admin (Opsional)',
                hintText: 'Masukkan catatan jika ada...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Terima'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      try {
        await ref
            .read(leaveControllerProvider.notifier)
            .approveLeave(
              leaveId: leaveId,
              adminNotes: adminNotesController.text.trim().isEmpty
                  ? null
                  : adminNotesController.text.trim(),
            );

        if (!mounted) return;

        final state = ref.read(leaveControllerProvider);
        if (state.hasError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${state.error}'),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permohonan cuti diterima'),
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
    }
  }

  Future<void> _handleReject(String leaveId, String employeeName) async {
    final adminNotesController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tolak Permohonan Cuti - $employeeName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Apakah Anda yakin ingin menolak permohonan cuti ini?'),
            const SizedBox(height: 12),
            TextField(
              controller: adminNotesController,
              decoration: const InputDecoration(
                labelText: 'Alasan Penolakan (Opsional)',
                hintText: 'Masukkan alasan penolakan...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
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
            child: const Text('Tolak'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      try {
        await ref
            .read(leaveControllerProvider.notifier)
            .rejectLeave(
              leaveId: leaveId,
              adminNotes: adminNotesController.text.trim().isEmpty
                  ? null
                  : adminNotesController.text.trim(),
            );

        if (!mounted) return;

        final state = ref.read(leaveControllerProvider);
        if (state.hasError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${state.error}'),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permohonan cuti ditolak'),
              backgroundColor: Colors.orange,
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
    }
  }

  Widget _buildLeaveCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, String> userNameById,
    TextTheme textTheme,
    bool isDark,
  ) {
    final data = doc.data();
    final leaveId = doc.id;
    final userId = data['userId'] as String? ?? '-';
    final employeeName = userNameById[userId] ?? userId;
    final type = data['type'] as String? ?? '-';
    final status = data['status'] as String? ?? 'Menunggu';
    final notes = data['notes'] as String? ?? '';
    final adminNotes = data['adminNotes'] as String?;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final processedAt = (data['processedAt'] as Timestamp?)?.toDate();

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
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.15),
          child: Icon(statusIcon, color: statusColor, size: 24),
        ),
        title: Text(
          employeeName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Jenis: $type'),
            Text('Status: $status'),
            if (createdAt != null)
              Text(
                'Diajukan: ${createdAt.toString().split(' ')[0]} ${createdAt.toString().split(' ')[1].substring(0, 5)}',
                style: textTheme.bodySmall,
              ),
          ],
        ),
        trailing: status == 'Menunggu'
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    tooltip: 'Terima',
                    onPressed: () => _handleApprove(leaveId, employeeName),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    tooltip: 'Tolak',
                    onPressed: () => _handleReject(leaveId, employeeName),
                  ),
                ],
              )
            : null,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (notes.isNotEmpty) ...[
                  Text(
                    'Catatan Karyawan:',
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
                      color: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(notes, style: textTheme.bodyMedium),
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
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final leaveRepo = ref.watch(leaveRepositoryProvider);

    // Get stream based on selected filter
    Stream<QuerySnapshot<Map<String, dynamic>>> leavesStream;
    switch (_selectedFilter) {
      case 'Menunggu':
        leavesStream = leaveRepo.streamPendingLeaves();
        break;
      case 'Diterima':
        leavesStream = leaveRepo.streamLeavesByStatus('Diterima');
        break;
      case 'Ditolak':
        leavesStream = leaveRepo.streamLeavesByStatus('Ditolak');
        break;
      default:
        leavesStream = leaveRepo.streamAllLeaves();
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
        title: const Text('Inbox Permohonan Cuti'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Semua'),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [Text('Menunggu')],
              ),
            ),
            Tab(text: 'Diterima'),
            Tab(text: 'Ditolak'),
          ],
        ),
      ),
      body: AnimatedPage(
        child: AppBackground(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: ref.watch(usersCollectionProvider).snapshots(),
            builder: (context, usersSnapshot) {
              final userDocs = usersSnapshot.data?.docs ?? [];
              final Map<String, String> userNameById = {
                for (final doc in userDocs)
                  doc.id: (doc.data()['name'] ?? doc.id).toString(),
              };

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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

                  // Filter by status if needed (for Semua tab, show all)
                  final filteredDocs = _selectedFilter == 'Semua'
                      ? docs
                      : docs.where((doc) {
                          final status =
                              doc.data()['status'] as String? ?? 'Menunggu';
                          return status == _selectedFilter;
                        }).toList();

                  // Note: For tabs other than "Semua", filtering is already done in the stream query
                  // But we keep this as a safety filter

                  // Sort by createdAt descending on client side
                  filteredDocs.sort((a, b) {
                    final aTime = (a.data()['createdAt'] as Timestamp?)
                        ?.toDate();
                    final bTime = (b.data()['createdAt'] as Timestamp?)
                        ?.toDate();
                    if (aTime == null && bTime == null) return 0;
                    if (aTime == null) return 1;
                    if (bTime == null) return -1;
                    return bTime.compareTo(aTime); // Descending
                  });

                  if (filteredDocs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _selectedFilter == 'Menunggu'
                                  ? Icons.inbox_outlined
                                  : Icons.event_busy,
                              size: 64,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _selectedFilter == 'Semua'
                                  ? 'Belum ada permohonan cuti'
                                  : 'Tidak ada permohonan dengan status "$_selectedFilter"',
                              style: textTheme.bodyLarge?.copyWith(
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Summary card
                      Card(
                        color: _selectedFilter == 'Menunggu'
                            ? Colors.orange.withOpacity(0.1)
                            : AppColors.accent.withOpacity(0.1),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(
                                _selectedFilter == 'Menunggu'
                                    ? Icons.pending_actions
                                    : Icons.inbox,
                                color: _selectedFilter == 'Menunggu'
                                    ? Colors.orange
                                    : AppColors.accent,
                                size: 32,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Total: ${filteredDocs.length}',
                                      style: textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : null,
                                      ),
                                    ),
                                    if (_selectedFilter == 'Menunggu')
                                      Text(
                                        '${filteredDocs.length} permohonan menunggu persetujuan',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black87,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...filteredDocs.map(
                        (doc) => _buildLeaveCard(
                          context,
                          doc,
                          userNameById,
                          textTheme,
                          isDark,
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
