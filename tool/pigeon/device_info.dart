import 'package:pigeon/pigeon.dart';

/// Runtime device details surfaced to Flutter over a typed platform channel.
///
/// Generated with `flutter pub run pigeon --input tool/pigeon/device_info.dart …`
/// (a pure-Dart Pigeon definition — never shipped to devices).
///
/// NOTE: pigeon 22.7.2 emits Kotlin without a `package` line. After
/// regenerating `DeviceInfoApi.kt` you must prepend
/// `package com.munirwaheed.crystal_messenger` or the Android host layer will
/// not compile (`@ConfigurePigeon` kotlinOptions crashes this pigeon version).
class SystemInfo {
  const SystemInfo({
    required this.fullName,
    required this.platform,
    required this.osVersion,
    required this.appVersion,
    required this.buildNumber,
  });

  final String fullName;

  /// One of `android`, `ios`.
  final String platform;

  final String osVersion;

  /// Human-readable app version (e.g. `1.0.0`).
  final String appVersion;

  /// Build counter (e.g. `1`).
  final String buildNumber;
}

@HostApi()
abstract class DeviceInfoApi {
  @async
  SystemInfo getSystemInfo();
}