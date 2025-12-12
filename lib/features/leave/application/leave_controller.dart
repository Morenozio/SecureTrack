import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/user_model.dart';
import '../data/leave_repository.dart';

final leaveControllerProvider =
    StateNotifierProvider<LeaveController, AsyncValue<void>>((ref) {
  final repo = ref.watch(leaveRepositoryProvider);
  return LeaveController(repo);
});

class LeaveController extends StateNotifier<AsyncValue<void>> {
  LeaveController(this._repo) : super(const AsyncData(null));
  final LeaveRepository _repo;

  Future<void> submit(AppUser user, {required String type, required String notes}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.submitLeave(userId: user.id, type: type, notes: notes),
    );
  }
}






