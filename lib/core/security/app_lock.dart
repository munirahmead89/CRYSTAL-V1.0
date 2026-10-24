import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
// LocalAuthException / LocalAuthExceptionCode live in the platform interface,
// which `local_auth` does not re-export.
import 'package:local_auth_platform_interface/types/auth_exception.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Why an unlock attempt ended.
enum UnlockOutcome {
  /// Unlocked.
  success,

  /// The user backed out. The app stays locked.
  cancelled,

  /// Biometrics are unavailable (none enrolled, hardware missing, or locked out
  /// after too many failures). The app must fall back rather than lock the user
  /// out of their own messages.
  unavailable,

  /// The prompt itself failed.
  error,
}

/// Owns app-lock state: whether the app is currently locked, and how to unlock.
///
/// ## Why this is a screen and not a prompt
///
/// The previous implementation called `LocalAuthentication.authenticate` from
/// `didChangeAppLifecycleState` and ignored both the result and any exception.
/// That made it fail open in four separate ways: cancelling returned `false`
/// and the code carried on, `LocalAuthException` was swallowed by an empty
/// `catch`, nothing blocked access while the dialog was up, and a cold start
/// never prompted at all because the lifecycle callback only fires on
/// transitions. It was an advisory toast, not a lock.
///
/// ## Why it needs a cooldown
///
/// `AppLifecycleState.resumed` fires far more often than "the user came back":
/// the biometric dialog itself backgrounds the activity, and so does the camera
/// permission prompt, the system share sheet, and any in-app `openAppSettings`.
/// Without a grace period the user is prompted several times per interaction
/// with a camera, which is how a lock becomes something users disable.
///
/// The grace period is driven by the user's own auto-lock setting, so "immediately"
/// and "after 1 hour" both do what they say.
class AppLockController extends ChangeNotifier {
  AppLockController(SharedPreferences prefs, {LocalAuthentication? localAuth})
    : _prefs = prefs,
      _localAuth = localAuth ?? LocalAuthentication(),
      _alwaysUnlocked = false;

  /// A controller that never engages.
  ///
  /// Used when `SharedPreferences` is unavailable — widget tests, or a platform
  /// without the plugin. Making this the provider default means an un-overridden
  /// scope degrades to "no lock" instead of throwing inside the router redirect,
  /// which would take down every screen rather than one feature. `main()` always
  /// supplies real preferences.
  AppLockController.degraded()
    : _prefs = null,
      _localAuth = null,
      _alwaysUnlocked = true;

  final SharedPreferences? _prefs;
  final LocalAuthentication? _localAuth;

  /// When true the lock never engages, whatever [evaluate] is told.
  final bool _alwaysUnlocked;

  static const String _prefsKeyUnlockedAt = 'app_lock.unlocked_at_ms';

  bool _locked = false;
  bool _authenticating = false;
  bool _biometricsAvailable = false;
  String? _lastError;

  /// True when the app must stay behind the lock screen.
  bool get isLocked => _locked;

  /// True while a system prompt is on screen, so the UI does not double-fire.
  bool get isAuthenticating => _authenticating;

  /// False when the device has nothing enrolled, so the UI can warn the user
  /// that enabling the lock will not work.
  bool get biometricsAvailable => _biometricsAvailable;

  /// Human-readable reason the last attempt failed, if any.
  String? get lastError => _lastError;

  /// The auto-lock grace period chosen in settings.
  ///
  /// Read straight out of the stored seconds rather than switched against a
  /// fixed list of cases: the settings screen offers a "15 min" option that the
  /// old switch had no arm for, and any new option would have silently fallen
  /// back to "lock immediately" — the exact opposite of what the user picked.
  /// Negative values are clamped to zero so a corrupted value fails closed.
  Duration get gracePeriod {
    final seconds = _prefs?.getInt(_prefsKeyGrace) ?? 0;
    if (seconds <= 0) return Duration.zero;
    return Duration(seconds: seconds);
  }

  static const String _prefsKeyGrace = 'app_lock.grace_seconds';

  /// Latches the app closed and re-checks hardware support.
  ///
  /// Called on launch and on every background transition. Cheap: only reads
  /// shared preferences after the first call.
  Future<void> evaluate({
    required bool lockEnabled,
    required bool force,
  }) async {
    if (_alwaysUnlocked || !lockEnabled) {
      if (_locked) {
        _locked = false;
        notifyListeners();
      }
      return;
    }

    await refreshBiometricAvailability();

    final shouldLock = force || !_withinGrace();
    if (shouldLock != _locked) {
      _locked = shouldLock;
      notifyListeners();
    }
  }

  bool _withinGrace() {
    final prefs = _prefs;
    if (prefs == null) return false;
    final unlockedAt = prefs.getInt(_prefsKeyUnlockedAt);
    if (unlockedAt == null) return false;
    final elapsed = DateTime.now().millisecondsSinceEpoch - unlockedAt;
    // A clock change can make this negative; treat a future timestamp as expired
    // rather than locking the user out until it catches up.
    if (elapsed < 0) return false;
    return elapsed < gracePeriod.inMilliseconds;
  }

  /// Probes what the device can actually do, so the settings screen can warn
  /// instead of silently offering a lock that will never fire.
  Future<void> refreshBiometricAvailability() async {
    final localAuth = _localAuth;
    if (localAuth == null) {
      _biometricsAvailable = false;
      return;
    }
    try {
      final supported = await localAuth.isDeviceSupported();
      final canCheck = await localAuth.canCheckBiometrics;
      final enrolled = canCheck
          ? await localAuth.getAvailableBiometrics()
          : <BiometricType>[];
      _biometricsAvailable = supported && (enrolled.isNotEmpty || canCheck);
    } catch (_) {
      _biometricsAvailable = false;
    }
  }

  /// Shows the system prompt and updates the lock state from the outcome.
  ///
  /// Never throws. [Unavailable] deliberately unlocks: a user whose biometric
  /// hardware has failed should not be locked out of their own messages, and a
  /// lock with no way through is worse than no lock.
  Future<UnlockOutcome> unlock() async {
    final localAuth = _localAuth;
    // No auth backend (tests, unsupported platform): report success rather than
    // a failure the caller would render as a stuck lock.
    if (localAuth == null) return UnlockOutcome.success;
    if (_authenticating) return UnlockOutcome.cancelled;
    _authenticating = true;
    _lastError = null;
    notifyListeners();

    try {
      final ok = await localAuth.authenticate(
        localizedReason: 'Unlock Crystal Messenger',
        options: const AuthenticationOptions(
          // Device PIN/pattern/face unlock count too. `biometricOnly: true`
          // meant a user with no enrolled fingerprint got an error instead of an
          // unlock, which the old code swallowed - leaving the app "locked" in a
          // way nothing could open.
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
          sensitiveTransaction: false,
        ),
      );

      if (ok) {
        _recordUnlock();
        return UnlockOutcome.success;
      }
      return UnlockOutcome.cancelled;
    } on LocalAuthException catch (error) {
      // No hardware, none enrolled, or too many failures. These must not leave
      // the user staring at a lock they cannot open.
      _lastError = _describe(error.code);
      if (_isFatal(error.code)) return UnlockOutcome.unavailable;
      return UnlockOutcome.error;
    } catch (error) {
      _lastError = 'Unlock failed.';
      if (kDebugMode) debugPrint('[app-lock] $error');
      return UnlockOutcome.error;
    } finally {
      _authenticating = false;
      notifyListeners();
    }
  }

  /// Latches closed without prompting, e.g. when the user backgrounds the app
  /// with "lock immediately" chosen.
  ///
  /// The unlock timestamp is deliberately *kept*. `lock()` only marks the app
  /// as closed right now; whether the user must authenticate again is decided
  /// by [evaluate] against their grace period. Clearing the timestamp here used
  /// to make [gracePeriod] unreachable — the one thing the user configured could
  /// never take effect, which is why the app re-prompted on every app switch
  /// even after the user picked "5 minutes".
  void lock() {
    if (_alwaysUnlocked || _locked) return;
    _locked = true;
    notifyListeners();
  }

  /// Applies the user's auto-lock choice so [gracePeriod] reflects it.
  ///
  /// The settings screen stores this in `AppUserSettings`, which the lock never
  /// read, while the lock read a `SharedPreferences` key nothing wrote. This is
  /// the bridge: [seconds] is the raw value the settings UI already holds.
  void setGraceSeconds(int seconds) {
    _prefs?.setInt(_prefsKeyGrace, seconds);
    notifyListeners();
  }

  /// Called when the user turns the feature off, so stale state does not linger.
  void disable() {
    _locked = false;
    _prefs?.remove(_prefsKeyUnlockedAt);
    notifyListeners();
  }

  void _recordUnlock() {
    _locked = false;
    _prefs?.setInt(_prefsKeyUnlockedAt, DateTime.now().millisecondsSinceEpoch);
    notifyListeners();
  }

  /// Failures that mean there is nothing to authenticate against, so keeping the
  /// app locked would strand the user with no way in.
  static bool _isFatal(LocalAuthExceptionCode code) =>
      code == LocalAuthExceptionCode.noCredentialsSet ||
      code == LocalAuthExceptionCode.noBiometricsEnrolled ||
      code == LocalAuthExceptionCode.noBiometricHardware;

  static String _describe(LocalAuthExceptionCode code) => switch (code) {
    LocalAuthExceptionCode.noCredentialsSet ||
    LocalAuthExceptionCode.noBiometricsEnrolled =>
      'No screen lock is set up on this device, so the app lock cannot be used.',
    LocalAuthExceptionCode.noBiometricHardware =>
      'This device has no biometric hardware, so the app lock cannot be used.',
    LocalAuthExceptionCode.biometricLockout ||
    LocalAuthExceptionCode.temporaryLockout =>
      'Too many failed attempts. Unlock your device with its PIN first.',
    LocalAuthExceptionCode.timeout => 'Unlock timed out. Try again.',
    _ => 'Unlock failed. Try again.',
  };
}

/// App-lock state.
///
/// Overridden in `main()` with an instance built from the already-loaded
/// `SharedPreferences`. Throwing by default is deliberate: silently constructing
/// a second controller here would give the lock its own private copy of the
/// unlocked timestamp, and the app would appear to lock at random.
final appLockControllerProvider = ChangeNotifierProvider<AppLockController>((
  ref,
) {
  // main() overrides this with a real SharedPreferences-backed controller.
  return AppLockController.degraded();
});
