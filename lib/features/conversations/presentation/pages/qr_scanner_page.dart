import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/network/supabase_providers.dart';
import '../../../../core/security/device_link_service.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/models/user_profile.dart';
import '../../../../shared/utils/phone_normalizer.dart';
import '../providers/chat_providers.dart';

const _qrScheme = 'crystal';

/// Native camera QR scanner page; pops with the resolved [UserProfile].
class QrScannerPage extends ConsumerWidget {
  const QrScannerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: CrystalColors.black,
      appBar: AppBar(
        title: const Text('Scan QR code'),
        backgroundColor: CrystalColors.black,
      ),
      body: QrScannerPanel(
        onResult: (profile) {
          if (context.mounted) Navigator.of(context).pop(profile);
        },
      ),
    );
  }
}

/// The live camera scanner panel (reused by [/qr-hub] and [/scan]). Resolves
/// `crystal://add?uid=…&phone=…` payloads and hands the [UserProfile] back.
class QrScannerPanel extends ConsumerStatefulWidget {
  const QrScannerPanel({super.key, required this.onResult});

  final ValueChanged<UserProfile> onResult;

  @override
  ConsumerState<QrScannerPanel> createState() => _QrScannerPanelState();
}

class _QrScannerPanelState extends ConsumerState<QrScannerPanel>
    with WidgetsBindingObserver {
  // `autoStart` is false on purpose: the camera is started explicitly by
  // `_startCamera()` only AFTER the permission is granted AND the preview is
  // mounted (post-frame). Mobile scanner is otherwise free to drop a black,
  // camera-off frame while it waits for a permission that never arrives.
  MobileScannerController? _controller;

  /// Camera permission result; null while the initial check is in flight.
  PermissionStatus? _permissionStatus;

  bool _handling = false;
  String? _resolvedPhone;

  /// Whether a first-start failure already triggered its one automatic retry.
  /// Reset only by an explicit user action (Retry / Grant access) so a broken
  /// camera can never loop a recreate-and-restart cycle forever.
  bool _startAutoRetried = false;

  /// A fresh controller every time: mobile_scanner's platform side aborts the
  /// camera stream after a failed start, so only a brand-new controller can
  /// reliably re-open it. Back camera is the scanner default.
  MobileScannerController _newController() => MobileScannerController(
    autoStart: false,
    facing: CameraFacing.back,
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Create the controller after the first frame and kick off the permission
    // flow so no method channel fires before the widget tree is mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller = _newController();
      _refreshPermission(autoRequest: true).ignore();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  /// Pauses/starts the camera with the app lifecycle so the preview never
  /// stays dark (or eats battery) while the app is in the background. Re-checks
  /// the permission on resume — this also auto-recovers when the user grants
  /// the camera in system Settings after choosing "Open Settings".
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _refreshPermission(autoRequest: false).ignore();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _stopCamera().ignore();
    }
  }

  /// Reads (and, on first open / explicit retry, requests) the camera
  /// permission, then starts the scanner when granted.
  Future<void> _refreshPermission({required bool autoRequest}) async {
    var status = await Permission.camera.status;
    if (!mounted) return;
    final needsPrompt = !status.isGranted && !status.isPermanentlyDenied;
    if (needsPrompt && autoRequest) {
      status = await Permission.camera.request();
      if (!mounted) return;
    }
    setState(() => _permissionStatus = status);
    if (status.isGranted) {
      final controller = _controller;
      // A controller that already surfaced an error died on the native side;
      // a plain start() can't revive it, so swap in a fresh one first.
      if (controller != null && controller.value.error != null) {
        _startAutoRetried = false;
        await _recreateController();
      }
      await _startCamera();
    }
  }

  /// Forces a clean restart of the whole camera pipeline: stops the current
  /// stream, disposes the controller, requests/checks permission again and
  /// re-initializes from scratch. Used by the Retry and Grant-access buttons.
  Future<void> _restartCamera() async {
    if (!mounted) return;
    _startAutoRetried = false;
    await _stopCamera();
    await _recreateController();
    if (!mounted) return;
    await _refreshPermission(autoRequest: true);
  }

  /// Starts the native camera. Runs after the current frame so the preview
  /// widget is mounted first; any failure is captured by MobileScanner and
  /// rendered by its `errorBuilder` instead of a black frame.
  Future<void> _startCamera() async {
    final controller = _controller;
    if (!mounted || controller == null) return;
    if (controller.value.isRunning) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _controller != controller) return;
      try {
        await controller.start();
      } catch (_) {
        // Some Android devices fail the very first `start()` after the camera
        // becomes available (mobile_scanner platform race / NPE). A fresh
        // controller almost always recovers — so recreate and retry exactly
        // once; any further failure is left for the Retry button.
        if (!mounted || _controller != controller) return;
        if (_startAutoRetried) return;
        _startAutoRetried = true;
        await _recreateController();
        if (mounted) _startCamera();
      }
    });
  }

  /// Disposes the old scanner and swaps in a new controller + preview. The
  /// preview is keyed on the controller instance (see `build`) so MobileScanner
  /// rebinds to the new one instead of silently keeping the disposed camera.
  Future<void> _recreateController() async {
    final old = _controller;
    final next = _newController();
    _controller = next;
    // Swap atomically so the preview never points at a disposed controller.
    if (mounted) setState(() {});
    try {
      await old?.dispose();
    } catch (_) {}
  }

  Future<void> _stopCamera() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.stop();
    } catch (_) {
      // Not running / already stopped — nothing to do.
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (raw == null) return;

    // A device-link code is handled first and never falls through to the
    // contact-add path: it is a completely different intent, and treating it as
    // an unknown contact would show a misleading "no account" message.
    final linkCode = DeviceLinkService.parseCode(raw);
    if (linkCode != null) {
      await _handleDeviceLink(linkCode);
      return;
    }

    final parsed = _parsePayload(raw);
    final uid = parsed['uid']?.trim() ?? '';
    final phone = normalizePhoneForStorage(parsed['phone']?.trim() ?? '');
    if (uid.isEmpty && phone.isEmpty) {
      _flashUnsupported();
      return;
    }

    _handling = true;
    setState(() => _resolvedPhone = phone.isNotEmpty ? phone : 'pairing…');
    try {
      // Resolve by stable uid when present (survives phone changes); fall
      // back to an exact phone lookup for bare-number / legacy codes.
      final repo = ref.read(peopleRepositoryProvider);
      final profile = uid.isNotEmpty
          ? await repo.fetchProfileById(uid)
          : await repo.fetchProfileByPhone(phone);
      await _stopCamera();
      if (!mounted) return;
      if (profile != null) {
        widget.onResult(profile);
      } else {
        _handling = false;
        setState(() => _resolvedPhone = null);
        await _startCamera();
        _flashNoAccount(uid.isNotEmpty ? uid : phone);
      }
    } catch (_) {
      _handling = false;
      setState(() => _resolvedPhone = null);
      await _startCamera();
      _flashUnsupported();
    }
  }

  /// Consumes a pairing code and signs this device in as the linked account.
  ///
  /// The other device is holding the approval on its own screen, so the user
  /// simply waits here: the realtime channel carries the approved session, and
  /// a table poll covers a dropped socket.
  Future<void> _handleDeviceLink(String code) async {
    if (_handling) return;
    _handling = true;
    setState(() => _resolvedPhone = 'linking…');

    final service = DeviceLinkService(ref.read(supabaseClientProvider));
    try {
      await _stopCamera();
      if (!mounted) return;

      await service.awaitApproval(
        code,
        onStatus: (status) {
          if (mounted) setState(() => _resolvedPhone = status);
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            // Deliberately not "Linked": the account is signed in but nothing
            // has been fetched yet, and the user is about to see an empty chat
            // list if we are not explicit about why.
            content: Text('Linked. Bringing your chats across…'),
            duration: Duration(seconds: 6),
          ),
        );

      // `setSession` has already been applied, and the auth-state stream the
      // router guards on repaints on its own. Invalidating the cached profile
      // rebuilds the shell against the linked account immediately.
      ref.invalidate(ownProfileProvider);

      // Device linking is a credential handoff, not a data copy: the whole
      // payload is the access/refresh token pair. The chats arrive here, by
      // pulling them from the server the new device now shares. Awaiting it
      // before leaving this screen is what makes "it will open with all your
      // chats already there" true rather than a few seconds of empty list.
      try {
        await ref.read(syncServiceProvider).syncInitial();
      } catch (e) {
        // Not fatal: the sync engine retries in the background, and an empty
        // list with the offline banner beats being stuck on this screen.
        if (kDebugMode) debugPrint('[device-link] initial sync failed: $e');
      }
      if (!mounted) return;
      ref.read(chatListProvider.notifier).load(silent: true).ignore();
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } on DeviceLinkException catch (e) {
      if (!mounted) return;
      _handling = false;
      setState(() => _resolvedPhone = null);
      await _startCamera();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red.shade700,
          ),
        );
    } catch (_) {
      if (!mounted) return;
      _handling = false;
      setState(() => _resolvedPhone = null);
      await _startCamera();
      _flashUnsupported();
    }
  }

  /// Accepts `crystal://add?uid=…&phone=…` (or a bare phone number as a
  /// fallback for QR codes minted outside Crystal).
  Map<String, String> _parsePayload(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return const {};
    if (uri.scheme == _qrScheme && uri.host == 'add') {
      return {
        'uid': uri.queryParameters['uid'] ?? '',
        'phone': uri.queryParameters['phone'] ?? '',
      };
    }
    if (raw.contains('@') || raw.contains('.')) return const {};
    if (RegExp(r'^[+0-9 ()-]+$').hasMatch(raw.trim())) {
      return {'phone': raw.trim()};
    }
    return const {};
  }

  void _flashUnsupported() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Not a Crystal contact code'),
          backgroundColor: CrystalColors.green,
        ),
      );
  }

  void _flashNoAccount(String phone) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('No Crystal account for $phone'),
          backgroundColor: CrystalColors.green,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context);
    final status = _permissionStatus;
    if (status == null) {
      // Initial permission check still in flight.
      return const Center(child: CircularProgressIndicator());
    }
    if (!status.isGranted) {
      return _permissionView(status);
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        MobileScanner(
          // Keyed on the controller instance so a recreated controller gets a
          // brand-new preview state — without this, MobileScanner pins its
          // `late final controller` to the first instance and the preview
          // silently keeps the disposed native camera, which ends in an NPE.
          key: ValueKey(_controller),
          controller: _controller,
          onDetect: _onDetect,
          errorBuilder: _cameraErrorView,
          placeholderBuilder: (_) =>
              const Center(child: CircularProgressIndicator()),
        ),
        _scanOverlay(),
        if (_resolvedPhone != null)
          Positioned(
            bottom: 48,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: CrystalColors.green,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                'Contacting $_resolvedPhone…',
                style: const TextStyle(
                  color: CrystalColors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        Positioned(
          bottom: 24,
          left: 24,
          right: 24,
          child: Text(
            'Point the camera at a Crystal QR code',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  /// Rendered by MobileScanner instead of its silent black error placeholder,
  /// so a camera failure is always visible and recoverable.
  Widget _cameraErrorView(BuildContext context, MobileScannerException error) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return _MessagePanel(
      icon: Icons.videocam_off_outlined,
      title: 'Camera unavailable',
      message: denied
          ? 'Camera permission was not granted.'
          : (error.errorDetails?.message?.isNotEmpty == true
                ? error.errorDetails!.message!
                : 'Could not start the camera.'),
      action: FilledButton.icon(
        onPressed: () => _restartCamera().ignore(),
        icon: const Icon(Icons.refresh),
        label: const Text('Retry'),
      ),
    );
  }

  Widget _permissionView(PermissionStatus status) {
    final permanentlyDenied = status.isPermanentlyDenied;
    return _MessagePanel(
      icon: permanentlyDenied
          ? Icons.no_photography_outlined
          : Icons.camera_alt_outlined,
      title: permanentlyDenied
          ? 'Camera access is blocked'
          : 'Camera access needed',
      message:
          'Crystal needs the camera to scan QR codes. '
          '${permanentlyDenied ? 'Enable it in system settings to continue.' : 'Tap below to grant access.'}',
      action: FilledButton.icon(
        onPressed: permanentlyDenied
            ? () => openAppSettings()
            : () => _restartCamera().ignore(),
        icon: Icon(permanentlyDenied ? Icons.settings_outlined : Icons.refresh),
        label: Text(
          permanentlyDenied ? 'Open Settings' : 'Grant camera access',
        ),
      ),
    );
  }

  Widget _scanOverlay() {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            border: Border.all(color: CrystalColors.green, width: 3),
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
    );
  }
}

/// Shared centered message panel (permission prompt / camera error).
class _MessagePanel extends StatelessWidget {
  const _MessagePanel({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: palette.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            action,
          ],
        ),
      ),
    );
  }
}
