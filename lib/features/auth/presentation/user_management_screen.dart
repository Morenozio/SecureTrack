import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_background.dart';
import '../application/auth_controller.dart';
import '../data/user_providers.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  bool _isProcessing = false;

  Future<void> _changeUserRole(String userId, String currentRole, String newRole) async {
    if (currentRole == newRole) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ubah Role User'),
        content: Text(
          'Apakah Anda yakin ingin mengubah role user menjadi "$newRole"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ubah'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref
            .read(authControllerProvider.notifier)
            .updateUserRole(userId: userId, newRole: newRole);

        if (!mounted) return;

        final state = ref.read(authControllerProvider);
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
              content: Text('Role berhasil diubah'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleActiveStatus({
    required String userId,
    required bool isActive,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isActive ? 'Non-aktifkan karyawan?' : 'Aktifkan karyawan?'),
        content: Text(isActive
            ? 'Karyawan ini tidak akan bisa login.'
            : 'Karyawan ini akan bisa login kembali.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(isActive ? 'Non-aktifkan' : 'Aktifkan'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .setUserActiveStatus(userId: userId, isActive: !isActive);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isActive ? 'Karyawan dinon-aktifkan' : 'Karyawan diaktifkan'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _deleteUser(String userId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus karyawan?'),
        content: Text(
          'Data profil "$name" akan dihapus dari koleksi users (log absensi tetap ada).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    try {
      await ref.read(authControllerProvider.notifier).deleteUserDoc(userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil karyawan dihapus'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _resetPassword(String email) async {
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email kosong'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _isProcessing = true);
    try {
      await ref.read(authControllerProvider.notifier).sendPasswordResetEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Link reset dikirim ke $email'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _showEditUserDialog(
    String userId,
    Map<String, dynamic> data,
  ) async {
    final nameCtrl = TextEditingController(text: data['name'] as String? ?? '');
    final emailCtrl = TextEditingController(text: data['email'] as String? ?? '');
    final contactCtrl = TextEditingController(text: data['contact'] as String? ?? '');
    String role = (data['role'] as String?) ?? 'employee';

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Data Karyawan'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nama'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email (hanya mengubah profil, bukan login)',
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: contactCtrl,
                  decoration: const InputDecoration(labelText: 'Kontak'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(labelText: 'Jabatan / Role'),
                  items: const [
                    DropdownMenuItem(value: 'employee', child: Text('Karyawan')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (val) {
                    if (val != null) role = val;
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  'Catatan: Perubahan email di sini tidak mengubah email login Firebase. '
                  'Gunakan reset password untuk akses login.',
                  style: TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                setState(() => _isProcessing = true);
                try {
                  await ref.read(authControllerProvider.notifier).updateUserProfile(
                        userId: userId,
                        name: nameCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                        contact: contactCtrl.text.trim(),
                        role: role,
                      );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Data karyawan diperbarui'), backgroundColor: Colors.green),
                  );
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isProcessing = false);
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final usersStream = ref.watch(usersCollectionProvider).orderBy('name').snapshots();
    final currentUser = ref.watch(authStateProvider).valueOrNull;

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
        title: const Text('Kelola User'),
      ),
      body: AppBackground(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: usersStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text('Error: ${snapshot.error}'),
              );
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 64,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Belum ada user terdaftar',
                      style: textTheme.bodyLarge?.copyWith(
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              );
            }

            // Separate users by role
            final adminUsers = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            final employeeUsers = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

            for (final doc in docs) {
              final role = doc.data()['role'] as String? ?? 'employee';
              if (role == 'admin') {
                adminUsers.add(doc);
              } else {
                employeeUsers.add(doc);
              }
            }

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_isProcessing) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 12),
                ],
                if (adminUsers.isNotEmpty) ...[
                  Text(
                    'Admin (${adminUsers.length})',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...adminUsers.map((doc) => _buildUserCard(
                        context,
                        doc,
                        textTheme,
                        isDark,
                        currentUser?.uid,
                      )),
                  const SizedBox(height: 24),
                ],
                Text(
                  'Karyawan (${employeeUsers.length})',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : null,
                  ),
                ),
                const SizedBox(height: 12),
                ...employeeUsers.map((doc) => _buildUserCard(
                      context,
                      doc,
                      textTheme,
                      isDark,
                      currentUser?.uid,
                    )),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildUserCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    TextTheme textTheme,
    bool isDark,
    String? currentUserId,
  ) {
    final data = doc.data();
    final userId = doc.id;
    final name = data['name'] as String? ?? '-';
    final email = data['email'] as String? ?? '-';
    final role = data['role'] as String? ?? 'employee';
    final contact = data['contact'] as String?;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final isActive = (data['isActive'] ?? true) as bool;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: role == 'admin'
              ? AppColors.accent.withOpacity(0.15)
              : Colors.blue.withOpacity(0.15),
          child: Icon(
            role == 'admin' ? Icons.admin_panel_settings : Icons.person,
            color: role == 'admin' ? AppColors.accent : Colors.blue,
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Email: $email'),
            if (contact != null && contact.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text('Kontak: $contact'),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Chip(
                  label: Text(role == 'admin' ? 'Admin' : 'Karyawan'),
                  backgroundColor:
                      role == 'admin' ? AppColors.accent.withOpacity(0.15) : Colors.blue.withOpacity(0.15),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(isActive ? 'Aktif' : 'Non-aktif'),
                  backgroundColor:
                      isActive ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                  labelStyle: TextStyle(color: isActive ? Colors.green.shade800 : Colors.red.shade800),
                ),
              ],
            ),
            if (createdAt != null) ...[
              const SizedBox(height: 2),
              Text(
                'Dibuat: ${createdAt.toString().split(' ')[0]}',
                style: textTheme.bodySmall,
              ),
            ],
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _showEditUserDialog(userId, data);
                break;
              case 'toggle_active':
                _toggleActiveStatus(userId: userId, isActive: isActive);
                break;
              case 'reset_password':
                _resetPassword(email);
                break;
              case 'delete':
                if (currentUserId != null && currentUserId == userId) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tidak bisa menghapus akun yang sedang dipakai'),
                      backgroundColor: Colors.red,
                    ),
                  );
                } else {
                  _deleteUser(userId, name);
                }
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('Edit data'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'toggle_active',
              child: Row(
                children: [
                  Icon(isActive ? Icons.pause_circle : Icons.play_circle, size: 20),
                  const SizedBox(width: 8),
                  Text(isActive ? 'Non-aktifkan' : 'Aktifkan'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'reset_password',
              child: Row(
                children: [
                  Icon(Icons.lock_reset, size: 20),
                  SizedBox(width: 8),
                  Text('Reset password'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_forever, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Hapus'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

