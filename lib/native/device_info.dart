import 'dart:io' show InternetAddressType, NetworkInterface, Platform;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Platform-channel-provided device facts used by the Profile screen and device registration.
///
/// Gracefully degrades to a best-effort Dart fallback when the native plugins
/// are unavailable (desktop, tests, plugin-less hosts) so the UI never breaks
/// when `deviceInfoProvider` resolves to null.
class DeviceInfo {
  const DeviceInfo({
    required this.fullName,
    required this.platform,
    required this.osVersion,
    required this.appVersion,
    required this.buildNumber,
    required this.model,
    required this.manufacturer,
    required this.deviceId,
    required this.locale,
    required this.ipAddress,
  });

  factory DeviceInfo.create({
    required String fullName,
    required String platform,
    required String osVersion,
    required String appVersion,
    required String buildNumber,
    required String model,
    required String manufacturer,
    required String deviceId,
    required String locale,
    String ipAddress = 'Unknown',
  }) {
    return DeviceInfo(
      fullName: fullName,
      platform: platform,
      osVersion: osVersion,
      appVersion: appVersion,
      buildNumber: buildNumber,
      model: model,
      manufacturer: manufacturer,
      deviceId: deviceId,
      locale: locale,
      ipAddress: ipAddress,
    );
  }

  static Future<DeviceInfo?> load() async {
    try {
      final plugin = DeviceInfoPlugin();
      final packageInfo = await PackageInfo.fromPlatform();
      String platform = Platform.operatingSystem;
      String locale = Platform.localeName;
      String model = 'Unknown';
      String manufacturer = 'Unknown';
      String deviceId = 'unknown';
      String osVersion = Platform.operatingSystemVersion;

      if (Platform.isAndroid) {
        final androidInfo = await plugin.androidInfo;
        model = androidInfo.model;
        manufacturer = androidInfo.manufacturer;
        deviceId = androidInfo.id;
        osVersion =
            'Android ${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt})';
      } else if (Platform.isIOS) {
        final iosInfo = await plugin.iosInfo;
        model = iosInfo.model;
        manufacturer = 'Apple';
        deviceId = iosInfo.identifierForVendor ?? 'unknown';
        osVersion = 'iOS ${iosInfo.systemVersion}';
      } else if (Platform.isWindows) {
        final windowsInfo = await plugin.windowsInfo;
        model = windowsInfo.computerName;
        manufacturer = 'Microsoft';
        deviceId = windowsInfo.deviceId;
        osVersion = 'Windows ${windowsInfo.buildNumber}';
      } else if (Platform.isMacOS) {
        final macInfo = await plugin.macOsInfo;
        model = macInfo.model;
        manufacturer = 'Apple';
        deviceId = macInfo.systemGUID ?? 'unknown';
        osVersion = 'macOS ${macInfo.osRelease}';
      } else if (Platform.isLinux) {
        final linuxInfo = await plugin.linuxInfo;
        model = linuxInfo.name;
        manufacturer = 'Linux';
        deviceId = linuxInfo.machineId ?? 'unknown';
        osVersion = 'Linux ${linuxInfo.version}';
      }

      return DeviceInfo(
        fullName: '$manufacturer $model',
        platform: platform,
        osVersion: osVersion,
        appVersion: packageInfo.version,
        buildNumber: packageInfo.buildNumber,
        model: model,
        manufacturer: manufacturer,
        deviceId: deviceId,
        locale: locale,
        ipAddress: await _getLocalIp(),
      );
    } on MissingPluginException {
      return _fallback();
    } on PlatformException {
      return _fallback();
    } catch (_) {
      return _fallback();
    }
  }

  static Future<DeviceInfo?> _fallback() async {
    try {
      final platform = Platform.operatingSystem;
      return DeviceInfo(
        fullName: platform,
        platform: platform,
        osVersion: Platform.operatingSystemVersion,
        appVersion: '1.0.0',
        buildNumber: '1',
        model: 'Unknown',
        manufacturer: 'Unknown',
        deviceId: 'unknown',
        locale: Platform.localeName,
        ipAddress: 'Unknown',
      );
    } catch (_) {
      return null;
    }
  }

  static Future<String> _getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (!address.isLoopback && address.address.isNotEmpty) {
            return address.address;
          }
        }
      }
    } catch (_) {}
    return 'Unknown';
  }

  final String fullName;
  final String platform;
  final String osVersion;
  final String appVersion;
  final String buildNumber;
  final String model;
  final String manufacturer;
  final String deviceId;
  final String locale;
  final String ipAddress;

  String get label => '$fullName · v$appVersion ($buildNumber)';

  Map<String, dynamic> toDeviceRegistrationMap() {
    return {
      'device_model': model,
      'device_os': osVersion,
      'device_manufacturer': manufacturer,
      'device_locale': locale,
      'app_version': appVersion,
    };
  }
}

final deviceInfoProvider = FutureProvider<DeviceInfo?>(
  (ref) => DeviceInfo.load(),
);

/// The device's local IPv4 address (first non-loopback). Used by the About
/// section for debugging connectivity ("which device am I on").
final localIpProvider = FutureProvider<String>((ref) async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    );
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (!address.isLoopback && address.address.isNotEmpty) {
          return address.address;
        }
      }
    }
  } catch (_) {
    // Not available everywhere (tests, some emulators).
  }
  return 'Unknown';
});
