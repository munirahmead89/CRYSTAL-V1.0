import 'package:connectivity_plus/connectivity_plus.dart';

/// Abstraction over the connectivity plugin.
///
/// The UI and sync engine depend on this interface so that tests can
/// substitute a fake implementation.
abstract interface class ConnectivityService {
  /// Emits `true` when the device is online and `false` when it goes offline.
  Stream<bool> onConnectionChanged();

  Future<bool> isOnline();

  /// Emits the raw list of connectivity results on every change.
  Stream<List<ConnectivityResult>> onConnectivityChanged();
}

class ConnectivityServiceImpl implements ConnectivityService {
  ConnectivityServiceImpl(this._connectivity);

  final Connectivity _connectivity;

  @override
  Stream<bool> onConnectionChanged() {
    return _connectivity.onConnectivityChanged.map(
      (results) => results.any((r) => r != ConnectivityResult.none),
    );
  }

  @override
  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  @override
  Stream<List<ConnectivityResult>> onConnectivityChanged() {
    return _connectivity.onConnectivityChanged;
  }
}
