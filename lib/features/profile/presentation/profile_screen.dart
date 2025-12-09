import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/app_background.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/user_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _contactController;
  bool _initializedFromUser = false;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _contactController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.valueOrNull;

    if (user != null && !_initializedFromUser) {
      _nameController.text = user.name;
      _emailController.text = user.email;
      _contactController.text = user.contact ?? '';
      _initializedFromUser = true;
    }

    return Scaffold(
      appBar: AppBar(
        leading: context.canPop() ? const BackButton() : null,
        title: const Text('Profil'),
        actions: [
          IconButton(
            tooltip: 'Ganti Tema',
            onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
          ),
          IconButton(
            tooltip: 'Keluar',
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).signOut();
              if (context.mounted) context.go('/auth');
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: AppColors.accent.withOpacity(0.2),
                    backgroundImage:
                        (user?.photoUrl ?? '').isNotEmpty ? NetworkImage(user!.photoUrl!) : null,
                    child: (user?.photoUrl ?? '').isEmpty
                        ? const Icon(Icons.person, size: 48, color: AppColors.accent)
                        : null,
                  ),
                  TextButton(
                    onPressed: user == null || _uploadingPhoto
                        ? null
                        : () async {
                            try {
                              await _pickAndUploadPhoto(user.id);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Foto profil diperbarui')),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(content: Text(e.toString())));
                            }
                          },
                    child: _uploadingPhoto
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Ubah foto profil'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Data Pribadi', style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : null,
            )),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(labelText: 'Nama'),
              controller: _nameController,
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(labelText: 'Email'),
              controller: _emailController,
              readOnly: true,
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(labelText: 'Kontak'),
              controller: _contactController,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: user == null
                  ? null
                  : () async {
                      try {
                        await _saveProfile(user.id);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Profil disimpan')),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString())),
                        );
                      }
                    },
              child: const Text('Simpan Perubahan'),
            ),
            const SizedBox(height: 24),
            Text('Pengaturan Tampilan', style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : null,
            )),
            const SizedBox(height: 8),
            _ThemeSelectorCard(),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile(String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'name': _nameController.text.trim(),
      'contact': _contactController.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _pickAndUploadPhoto(String uid) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    setState(() => _uploadingPhoto = true);
    final file = File(picked.path);
    final ref = FirebaseStorage.instance.ref().child('users/$uid/profile.jpg');
    await ref.putFile(file);
    final url = await ref.getDownloadURL();

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'photoUrl': url,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    setState(() => _uploadingPhoto = false);
  }
}

class _ThemeSelectorCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pilih Tema',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : null,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ThemeOptionTile(
                    icon: Icons.light_mode,
                    label: 'Terang',
                    isSelected: themeMode == ThemeMode.light,
                    onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ThemeOptionTile(
                    icon: Icons.dark_mode,
                    label: 'Gelap',
                    isSelected: themeMode == ThemeMode.dark,
                    onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ThemeOptionTile(
                    icon: Icons.settings_suggest,
                    label: 'Sistem',
                    isSelected: themeMode == ThemeMode.system,
                    onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system),
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

class _ThemeOptionTile extends StatelessWidget {
  const _ThemeOptionTile({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedColor = isDark ? AppColors.accent : AppColors.navy;
    final unselectedColor = isDark ? Colors.white70 : colorScheme.onSurface.withOpacity(0.6);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? selectedColor : (isDark ? Colors.white24 : colorScheme.outline.withOpacity(0.3)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? selectedColor : unselectedColor,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? selectedColor : (isDark ? Colors.white : colorScheme.onSurface),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

