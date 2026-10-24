import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Per-app data usage reported by Android's own counters.
///
/// ## Why this exists
///
/// The Network usage settings screen used to render hardcoded strings — "1.8 GB
/// total, 200 MB messages, 1.2 GB media" — with no data behind them, next to two
/// switches whose `onChanged` was an empty closure. Fabricated numbers in a
/// storage screen are worse than an empty screen: a user who reads them decides
/// what to delete based on figures that do not describe their device.
///
/// `TrafficStats.getUidRxBytes/TxBytes` is the only per-app figure available
/// without `PACKAGE_USAGE_STATS`, which is a special-access permission a
/// messaging app has no business requesting and which stores reject without a
/// declared core purpose.
///
/// ## What it does and does not cover
///
/// These are the OS counters for this app's UID, so they include every byte the
/// app has ever sent or received: messages, media, avatars, sync. There is no
/// per-category split available at this permission level, so the UI shows one
/// honest total instead of a breakdown it cannot actually measure.
class DataUsage {
  const DataUsage({required this.rxBytes, required this.txBytes});

  final int rxBytes;
  final int txBytes;

  int get totalBytes => rxBytes + txBytes;

  static const DataUsage unknown = DataUsage(rxBytes: 0, txBytes: 0);

  /// Reads the counters. Returns null where unsupported (iOS, web, desktop),
  /// which the UI renders as "not available" rather than a fake zero.
  static Future<DataUsage?> read() async {
    if (!Platform.isAndroid) return null;
    try {
      final result = await const MethodChannel(
        'crystal/network',
      ).invokeMapMethod<String, dynamic>('getDataUsage');
      if (result == null) return null;
      return DataUsage(
        rxBytes: (result['rxBytes'] as num?)?.toInt() ?? 0,
        txBytes: (result['txBytes'] as num?)?.toInt() ?? 0,
      );
    } on MissingPluginException {
      return null;
    } catch (_) {
      // A platform channel failure must never break the settings screen.
      return null;
    }
  }
}

/// Formats a byte count for display.
String formatBytes(int bytes, {int decimals = 1}) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final text = value >= 100 || value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(decimals);
  return '$text ${units[unit]}';
}
