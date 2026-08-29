import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

enum ConnectionStatus { connected, disconnected, unknown }

class NetworkNotifier extends StateNotifier<ConnectionStatus> {
  final Connectivity _connectivity = Connectivity();

  NetworkNotifier() : super(ConnectionStatus.unknown) {
    _init();
  }

  void _init() async {
    final result = await _connectivity.checkConnectivity();
    _updateStatus(result);

    _connectivity.onConnectivityChanged.listen((result) {
      _updateStatus(result);
    });
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final hasConnection = results.any((r) => r != ConnectivityResult.none);
    state = hasConnection ? ConnectionStatus.connected : ConnectionStatus.disconnected;
  }

  bool get isConnected => state == ConnectionStatus.connected;
}

final networkProvider = StateNotifierProvider<NetworkNotifier, ConnectionStatus>((ref) {
  return NetworkNotifier();
});

final isConnectedProvider = Provider<bool>((ref) {
  return ref.watch(networkProvider) == ConnectionStatus.connected;
});
