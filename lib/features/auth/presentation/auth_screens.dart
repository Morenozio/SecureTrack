import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../application/auth_controller.dart';
import '../data/user_providers.dart';

class AuthChoiceScreen extends ConsumerStatefulWidget {
  const AuthChoiceScreen({super.key});

  @override
  ConsumerState<AuthChoiceScreen> createState() => _AuthChoiceScreenState();
}

class _AuthChoiceScreenState extends ConsumerState<AuthChoiceScreen> {
  String email = '';
  String password = '';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: context.canPop() ? const BackButton() : null,
        title: const Text(''),
        actions: [
          IconButton(
            tooltip: 'Ganti Tema',
            onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0A0F1F), AppColors.navyDark]
                : [const Color(0xFFF3F6FF), Colors.white],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 32,
                              backgroundColor: isDark 
                                  ? AppColors.accent.withOpacity(0.2) 
                                  : AppColors.navy.withOpacity(0.1),
                              child: Icon(
                                Icons.verified_user, 
                                color: isDark ? AppColors.accent : AppColors.navy, 
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'SecureTrack',
                              style: textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : AppColors.navy,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Secure attendance management system',
                              style: textTheme.bodySmall?.copyWith(
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                      Text(
                        'Login akun Anda',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Masuk dengan email & password. Sistem otomatis mengenali Admin atau Karyawan berdasarkan data di database.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        decoration: const InputDecoration(labelText: 'Email'),
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (v) => setState(() => email = v),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: const InputDecoration(labelText: 'Password'),
                        obscureText: true,
                        onChanged: (v) => setState(() => password = v),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () async {
                                try {
                                  final user = await ref
                                      .read(authControllerProvider.notifier)
                                      .loginAuto(email: email, password: password);
                                  if (!mounted) return;
                                  if (user.role == 'admin') {
                                    context.go('/dashboard/admin');
                                  } else {
                                    context.go('/dashboard/employee');
                                  }
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(content: Text(e.toString())));
                                }
                              },
                        child: isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Masuk'),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Belum punya akun? Daftar di sini:',
                        style: textTheme.bodyMedium?.copyWith(
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => context.push('/auth/signup'),
                        child: const Text('Daftar'),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Karyawan terikat pada perangkat pertama saat login.',
                        style: textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.white70 : AppColors.navy,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class UnifiedSignUpScreen extends ConsumerStatefulWidget {
  const UnifiedSignUpScreen({super.key});

  @override
  ConsumerState<UnifiedSignUpScreen> createState() => _UnifiedSignUpScreenState();
}

class _UnifiedSignUpScreenState extends ConsumerState<UnifiedSignUpScreen> {
  String name = '';
  String email = '';
  String password = '';
  String contact = '';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: context.canPop() ? const BackButton() : null,
        title: const Text('Daftar Akun'),
        actions: [
          IconButton(
            tooltip: 'Ganti Tema',
            onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Daftar Sebagai Karyawan', style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Catatan: Admin account dibuat langsung melalui database atau oleh admin lain.',
              style: textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(labelText: 'Nama'),
              onChanged: (v) => name = v,
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              onChanged: (v) => email = v,
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(labelText: 'Kontak (opsional)'),
              keyboardType: TextInputType.phone,
              onChanged: (v) => contact = v,
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
              onChanged: (v) => password = v,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      // Validate inputs
                      if (name.trim().isEmpty || email.trim().isEmpty || password.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Nama, email, dan password wajib diisi.')),
                        );
                        return;
                      }
                      
                      try {
                        // Sign out any existing session first
                        await ref.read(authControllerProvider.notifier).signOut();
                        
                        final user = await ref.read(authControllerProvider.notifier).employeeSignUp(
                              name: name.trim(),
                              email: email.trim(),
                              password: password,
                              contact: contact.trim(),
                            );
                        if (!mounted) return;
                        // Invalidate user provider to refresh
                        ref.invalidate(currentUserProvider);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Berhasil mendaftar sebagai Karyawan: ${user.name}')),
                        );
                        context.go('/dashboard/employee');
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Daftar'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => context.go('/auth'),
              child: const Text('Sudah punya akun? Masuk'),
            ),
          ],
        ),
      ),
      ),
    );
  }
}


class EmployeeSignUpScreen extends ConsumerStatefulWidget {
  const EmployeeSignUpScreen({super.key});

  @override
  ConsumerState<EmployeeSignUpScreen> createState() => _EmployeeSignUpScreenState();
}

class _EmployeeSignUpScreenState extends ConsumerState<EmployeeSignUpScreen> {
  String name = '';
  String email = '';
  String password = '';
  String contact = '';

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;
    return Scaffold(
      appBar: AppBar(
        leading: context.canPop() ? const BackButton() : null,
        title: const Text('Daftar Karyawan'),
      ),
      body: _AuthForm(
        title: 'Buat Akun Karyawan',
        subtitle: 'Email, password, dan foto profil opsional. Perangkat akan diikat saat login pertama.',
        fields: [
          _AuthField(
            label: 'Nama',
            hint: 'Nama lengkap',
            onChanged: (v) => setState(() => name = v),
          ),
          _AuthField(
            label: 'Email',
            hint: 'nama@perusahaan.com',
            keyboardType: TextInputType.emailAddress,
            onChanged: (v) => setState(() => email = v),
          ),
          _AuthField(
            label: 'Kontak (opsional)',
            hint: 'No. WhatsApp',
            keyboardType: TextInputType.phone,
            onChanged: (v) => setState(() => contact = v),
          ),
          _AuthField(
            label: 'Password',
            hint: 'Minimal 8 karakter',
            obscure: true,
            onChanged: (v) => setState(() => password = v),
          ),
        ],
        primaryActionLabel: 'Daftar',
        onPrimary: () async {
          try {
            await ref.read(authControllerProvider.notifier).employeeSignUp(
                  name: name,
                  email: email,
                  password: password,
                  contact: contact,
                );
            if (!mounted) return;
            context.go('/dashboard/employee');
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.toString())),
            );
          }
        },
        secondaryActionLabel: 'Sudah punya akun? Masuk',
        onSecondary: () => context.go('/auth/employee/login'),
        isLoading: isLoading,
      ),
    );
  }
}

class _AuthForm extends StatelessWidget {
  const _AuthForm({
    required this.title,
    required this.subtitle,
    required this.fields,
    required this.primaryActionLabel,
    required this.onPrimary,
    required this.secondaryActionLabel,
    required this.onSecondary,
    this.isLoading = false,
  });

  final String title;
  final String subtitle;
  final List<_AuthField> fields;
  final String primaryActionLabel;
  final VoidCallback onPrimary;
  final String secondaryActionLabel;
  final VoidCallback onSecondary;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(subtitle, style: textTheme.bodyMedium),
          const SizedBox(height: 20),
          ...fields.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: TextField(
                  obscureText: f.obscure,
                  keyboardType: f.keyboardType,
                  onChanged: f.onChanged,
                  decoration: InputDecoration(
                    labelText: f.label,
                    hintText: f.hint,
                    prefixIcon: f.prefix,
                  ),
                ),
              )),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: isLoading ? null : onPrimary,
            child: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(primaryActionLabel),
          ),
          const SizedBox(height: 10),
          TextButton(onPressed: onSecondary, child: Text(secondaryActionLabel)),
        ],
      ),
    );
  }
}

class _AuthField {
  _AuthField({
    required this.label,
    required this.hint,
    this.obscure = false,
    this.prefix,
    this.keyboardType,
    this.onChanged,
  });

  final String label;
  final String hint;
  final bool obscure;
  final Widget? prefix;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
}

