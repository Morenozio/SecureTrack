import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/wifi_network_repository.dart';

final wifiNetworkControllerProvider =
    StateNotifierProvider<WifiNetworkController, AsyncValue<void>>((ref) {
  final repo = ref.watch(wifiNetworkRepositoryProvider);
  return WifiNetworkController(repo);
});

class WifiNetworkController extends StateNotifier<AsyncValue<void>> {
  WifiNetworkController(this._repo) : super(const AsyncData(null));

  final WifiNetworkRepository _repo;

  Future<void> addNetwork({
    required String ssid,
    required String bssid,
    String? description,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.addNetwork(
        ssid: ssid,
        bssid: bssid,
        description: description,
      ),
    );
  }

  Future<void> deleteNetwork(String networkId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _repo.deleteNetwork(networkId),
    );
  }
}



