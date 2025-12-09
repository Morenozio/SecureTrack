import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/user_model.dart';
import '../data/attendance_repository.dart';

final attendanceControllerProvider =
    StateNotifierProvider<AttendanceController, AsyncValue<void>>((ref) {
  final repo = ref.watch(attendanceRepositoryProvider);
  return AttendanceController(repo);
});

class AttendanceController extends StateNotifier<AsyncValue<void>> {
  AttendanceController(this._repo) : super(const AsyncData(null));

  final AttendanceRepository _repo;

  Future<void> checkIn(AppUser user, {String method = 'app'}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.checkIn(
        userId: user.id,
        deviceId: user.deviceId,
        method: method,
      ),
    );
  }

  Future<void> checkOut(AppUser user) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.checkOut(user.id),
    );
  }
}

