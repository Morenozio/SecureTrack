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

  Future<void> checkIn(
    AppUser user, {
    String method = 'wifi',
    String? manualSsid,
    String? manualBssid,
  }) async {
    state = const AsyncLoading();

    String ssid;
    String bssid;

    // Use manual credentials if provided (e.g. from UI when WiFi API fails)
    if (manualSsid != null &&
        manualBssid != null &&
        manualSsid.trim().isNotEmpty &&
        manualBssid.trim().isNotEmpty) {
      ssid = manualSsid.trim();
      bssid = manualBssid.trim().toLowerCase();
    } else if (method == 'wifi') {
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
        final errorMsg = e.toString().contains('Exception:')
            ? e.toString().split('Exception:').last.trim()
            : e.toString();
        state = AsyncError(errorMsg, StackTrace.current);
        return;
      }
    } else {
      state = AsyncError(
        'Informasi WiFi tidak valid. Gunakan masukan manual atau pastikan WiFi terbaca.',
        StackTrace.current,
      );
      return;
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
    try {
      final info = await _wifiService.getWifiInfo();
      if (!info.isComplete) {
        state = AsyncError(
          'Informasi WiFi tidak lengkap. Pastikan koneksi stabil.',
          StackTrace.current,
        );
        return;
      }
      state = await AsyncValue.guard(
        () => _repo.checkOut(user.id, ssid: info.ssid!, bssid: info.bssid!),
      );
    } catch (e) {
      final errorMsg = e.toString().contains('Exception:')
          ? e.toString().split('Exception:').last.trim()
          : e.toString();
      state = AsyncError(errorMsg, StackTrace.current);
    }
  }
}
