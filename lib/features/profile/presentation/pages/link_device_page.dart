import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/security/device_link_service.dart';
import '../../../../core/network/supabase_providers.dart';
import '../../../../app/theme/app_theme.dart';

/// "Link a device" — the WhatsApp Web pairing screen.
///
/// This device (already signed in) shows a QR containing a short-lived,
/// single-use code. The other device scans it, and once the user confirms here
/// the other device comes up as the same profile.
///
/// The security property the countdown advertises: the code is worthless after
/// two minutes, so a photographed screen cannot be used later.
class LinkDevicePage extends ConsumerStatefulWidget {
  const LinkDevicePage({super.key});

  @override
  ConsumerState<LinkDevicePage> createState() => _LinkDevicePageState();
}

class _LinkDevicePageState extends ConsumerState<LinkDevicePage> {
  DeviceLinkService? _service;
  String? _code;
  DateTime? _expiresAt;
  Timer? _ticker;
  Duration _remaining = Duration.zero;
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    // Revoke any outstanding code so a code the user abandoned cannot be
    // approved later.
    if (_code != null) _service?.revoke(_code!).ignore();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final service = DeviceLinkService(ref.read(supabaseClientProvider));
    try {
      final code = await service.createLinkRequest();
      if (!mounted) return;
      setState(() {
        _service = service;
        _code = code;
        _expiresAt = DateTime.now().add(DeviceLinkService.codeLifetime);
        _remaining = DeviceLinkService.codeLifetime;
        _busy = false;
      });
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        final expires = _expiresAt;
        if (expires == null || !mounted) return;
        final left = expires.difference(DateTime.now());
        setState(() => _remaining = left.isNegative ? Duration.zero : left);
        if (left.isNegative) {
          _ticker?.cancel();
          _refresh();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  Future<void> _refresh() async {
    _ticker?.cancel();
    _code = null;
    await _start();
  }

  Future<void> _approve() async {
    final code = _code;
    final service = _service;
    if (code == null || service == null) return;
    try {
      await service.approve(code);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Device linked')));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final code = _code;

    return Scaffold(
      appBar: AppBar(title: const Text('Link a device')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Scan this with the other device',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'It will open as this account, with all your chats, '
                  'contacts and settings already there.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                if (_busy)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_error != null)
                  Column(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: theme.colorScheme.error,
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _refresh,
                        child: const Text('Try again'),
                      ),
                    ],
                  )
                else if (code != null) ...[
                  // The countdown is the visible reminder that the code is
                  // single-use and short-lived, which is what makes showing it
                  // on screen safe.
                  _CountdownRing(remaining: _remaining),
                  const SizedBox(height: 16),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: CrystalColors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: QrImageView(
                        data: DeviceLinkService.qrPayloadFor(code),
                        version: QrVersions.auto,
                        size: 220,
                        gapless: true,
                        backgroundColor: CrystalColors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _remaining == Duration.zero ? null : _approve,
                    icon: const Icon(Icons.check),
                    label: const Text('That is my device'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _refresh,
                    child: const Text('Show a new code'),
                  ),
                ],
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Only approve a device you are looking at. The code '
                          'stops working when the timer runs out.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Expiry countdown rendered as a ring around the QR's heading.
class _CountdownRing extends StatelessWidget {
  const _CountdownRing({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = DeviceLinkService.codeLifetime.inSeconds;
    final left = remaining.inSeconds.clamp(0, total);
    final expired = left <= 0;

    return Column(
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: total == 0 ? 0 : left / total,
                strokeWidth: 4,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(
                  expired ? theme.colorScheme.error : theme.colorScheme.primary,
                ),
              ),
              Text(
                expired ? '0' : '$left',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: expired ? theme.colorScheme.error : null,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          expired ? 'Code expired' : 'seconds left',
          style: theme.textTheme.labelMedium?.copyWith(
            color: expired ? theme.colorScheme.error : null,
          ),
        ),
      ],
    );
  }
}
