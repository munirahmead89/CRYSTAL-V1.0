import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../security/device_identity.dart';

/// The server-registered id of this device, or null while it is unknown.
///
/// The relay's delivery acknowledgement is device-scoped: the server checks that
/// the row it names belongs to the authenticated user and has not been revoked.
/// That makes a locally-minted identifier useless for acknowledgement, which is
/// the point — a client-supplied id is a claim, not proof of device identity.
///
/// The value here is the id `register_device` was called with, echoed back from
/// [registerThisDevice] once the server has accepted it. Until that resolves the
/// provider yields null, and [DeliveryAcknowledgementService] then simply does
/// not acknowledge rather than sending an unverifiable claim.
///
/// Kept in a provider rather than read from [DeviceIdentity] directly so that a
/// guest account, a failed registration and a widget test all degrade to "no
/// acknowledgement" instead of a crash or a silent success.
final registeredDeviceIdProvider = FutureProvider<String?>((ref) async {
  final candidate = await DeviceIdentity.getOrCreate();
  // Without a registered row the server would reject every acknowledgement, so
  // reporting null keeps the ledger entries pending until registration succeeds
  // and lets the retry loop pick them up.
  return _registered ? candidate : null;
});

/// Whether `register_device` has been called for this session.
///
/// Set by the home screen's startup sequence, which owns device registration.
/// Exposed as a plain setter rather than a provider so registration can record
/// success without forcing a rebuild of everything that watches it.
bool _registered = false;

/// Records that the server accepted this device's registration.
void markDeviceRegistered(bool registered) {
  _registered = registered;
}

/// Test seam: forgets the registration result without touching storage.
void resetDeviceRegistration() {
  _registered = false;
}
