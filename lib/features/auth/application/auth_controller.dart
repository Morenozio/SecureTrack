import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../data/user_model.dart';

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthController(repo);
});

class AuthController extends StateNotifier<AsyncValue<void>> {
  AuthController(this._repo) : super(const AsyncData(null));

  final AuthRepository _repo;
  AppUser? currentUserCache;

  Future<AppUser> loginAuto({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    late AppUser user;
    state = await AsyncValue.guard(
      () async {
        user = await _repo.loginAuto(email: email, password: password);
      },
    );
    if (state.hasError) {
      throw state.error!;
    }
    currentUserCache = user;
    return user;
  }

  Future<void> adminLogin({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.adminLogin(email: email, password: password),
    );
  }

  Future<AppUser> adminSignUp({
    required String adminCode,
    required String name,
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    try {
      final user = await _repo.adminSignUp(
        adminCode: adminCode,
        name: name,
        email: email,
        password: password,
      );
      state = const AsyncData(null);
      currentUserCache = user;
      return user;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> employeeLogin({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.employeeLogin(email: email, password: password),
    );
  }

  Future<AppUser> employeeSignUp({
    required String name,
    required String email,
    required String password,
    String? contact,
  }) async {
    state = const AsyncLoading();
    try {
      final user = await _repo.employeeSignUp(
        name: name,
        email: email,
        password: password,
        contact: contact,
      );
      state = const AsyncData(null);
      currentUserCache = user;
      return user;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.signOut());
  }
}

