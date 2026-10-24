import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connectivity_service.dart';

final connectivityServiceProvider = Provider<ConnectivityService>(
  (ref) => ConnectivityServiceImpl(Connectivity()),
);

/// Rebuilds whenever the device goes online or offline.
///
/// Emits `null` until the first connectivity check completes.
final isOnlineProvider = StreamProvider<bool>(
  (ref) => ref.watch(connectivityServiceProvider).onConnectionChanged(),
);

/// Emits the active [ConnectivityResult] list whenever the network TYPE
/// changes (WiFi ↔ mobile ↔ none). The home shell listens to this to
/// detect a network switch and redirect the user back to onboarding.
final networkTypeProvider = StreamProvider<List<ConnectivityResult>>(
  (ref) => ref.watch(connectivityServiceProvider).onConnectivityChanged(),
);
