import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Holds the result of a WiFi detection attempt.
class WifiInfo {
  const WifiInfo({this.ssid, this.bssid});
  final String? ssid;
  final String? bssid;

  bool get isComplete =>
      ssid != null && ssid!.isNotEmpty && bssid != null && bssid!.isNotEmpty;
}

/// Service that detects the current WiFi SSID and BSSID.
///
/// On Android 10+, location permission is required to read WiFi info.
/// On web, auto-detection is not available.
class WifiService {
  WifiService(this._networkInfo);

  final NetworkInfo _networkInfo;

  /// Attempts to detect the current WiFi network.
  ///
  /// Returns a [WifiInfo] with ssid/bssid populated on success.
  /// Throws an exception with a user-friendly message on failure.
  Future<WifiInfo> getWifiInfo() async {
    // Web platform does not support WiFi detection
    if (kIsWeb) {
      throw Exception(
        'Auto-detect WiFi tidak tersedia di web. Silakan masukkan manual.',
      );
    }

    // Request location permission (required on Android 10+ for WiFi info)
    final status = await Permission.location.request();

    if (status.isDenied) {
      throw Exception(
        'Izin lokasi ditolak. Izin lokasi diperlukan untuk mendeteksi WiFi. '
        'Silakan masukkan WiFi secara manual.',
      );
    }

    if (status.isPermanentlyDenied) {
      throw Exception(
        'Izin lokasi diblokir secara permanen. '
        'Buka Pengaturan > Aplikasi > SecureTrack > Izin untuk mengaktifkan lokasi, '
        'atau masukkan WiFi secara manual.',
      );
    }

    // Read WiFi info
    String? ssid = await _networkInfo.getWifiName();
    String? bssid = await _networkInfo.getWifiBSSID();

    // Clean up SSID - NetworkInfo returns it wrapped in quotes on some platforms
    if (ssid != null) {
      ssid = ssid.replaceAll('"', '').trim();
      if (ssid == '<unknown ssid>' || ssid.isEmpty) {
        ssid = null;
      }
    }

    // Normalize BSSID to lowercase
    if (bssid != null) {
      bssid = bssid.toLowerCase().trim();
      if (bssid == '02:00:00:00:00:00' || bssid.isEmpty) {
        // This is a dummy BSSID returned when permission is not fully granted
        bssid = null;
      }
    }

    if (ssid == null && bssid == null) {
      throw Exception(
        'WiFi tidak terdeteksi. Pastikan perangkat terhubung ke WiFi, '
        'atau masukkan informasi WiFi secara manual.',
      );
    }

    return WifiInfo(ssid: ssid, bssid: bssid);
  }
}

/// Riverpod provider for [WifiService].
final wifiServiceProvider = Provider<WifiService>((ref) {
  return WifiService(NetworkInfo());
});
