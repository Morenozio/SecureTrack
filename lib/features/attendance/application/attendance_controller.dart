import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/user_model.dart';
import '../../../core/services/wifi_service.dart';
import '../data/attendance_repository.dart';

final attendanceControllerProvider =
    StateNotifierProvider<AttendanceController, AsyncValue<void>>((ref) {
      final repo = ref.watch(attendanceRepositoryProvider);
      final wifiService = ref.watch(wifiServiceProvider);
      return AttendanceController(repo, wifiService);
    });

class AttendanceController extends StateNotifier<AsyncValue<void>> {
  AttendanceController(this._repo, this._wifiService)
    : super(const AsyncData(null));

  final AttendanceRepository _repo;
  final WifiService _wifiService;

  Future<void> checkIn(AppUser user, {String method = 'wifi'}) async {
    state = const AsyncLoading();

    String ssid = 'manual';
    String bssid = 'manual';

    if (method == 'wifi') {
      try {
        final info = await _wifiService.getWifiInfo();
        if (!info.isComplete) {
          state = AsyncError(
            'Informasi WiFi tidak lengkap. Pastikan koneksi stabil.',
            StackTrace.current,
          );
          return;
        }
        ssid = info.ssid!;
        bssid = info.bssid!;
      } catch (e) {
        // Carry the original error message if it's user-friendly
        final errorMsg = e.toString().contains('Exception:')
            ? e.toString().split('Exception:').last.trim()
            : e.toString();
        state = AsyncError(errorMsg, StackTrace.current);
        return;
      }
    }

    state = await AsyncValue.guard(
      () => _repo.checkIn(
        userId: user.id,
        deviceId: user.deviceId,
        method: method,
        ssid: ssid,
        bssid: bssid,
      ),
    );
  }

  Future<void> checkOut(AppUser user) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.checkOut(user.id));
  }
}
