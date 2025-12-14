import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceIdService {
  static final DeviceInfoPlugin _plugin = DeviceInfoPlugin();

  /// Unique, stable-ish ID per device for storage (not shown in UI).
  static Future<String> getDeviceId() async {
    try {
      final info = await _plugin.deviceInfo;

      if (info is AndroidDeviceInfo) {
        final base =
            '${info.id}_${info.device}_${info.model}_${info.manufacturer}_${info.hardware}';
        return _hash(base);
      }

      if (info is IosDeviceInfo) {
        final idfv = info.identifierForVendor;
        final base = idfv != null
            ? idfv
            : '${info.name}_${info.model}_${info.systemName}_${info.systemVersion}';
        return _hash(base);
      }

      if (info is WebBrowserInfo) {
        final browser = info.browserName.name;
        final vendor = info.vendor ?? '';
        final ua = info.userAgent ?? '';
        final base = '$browser|$vendor|$ua';
        return _hash(base);
      }

      final base = info.toString();
      return _hash(base);
    } catch (_) {
      return 'device_unknown';
    }
  }

  /// Human-friendly name for display in UI (leaderboard, reports).
  ///
  /// - iOS: this is the user-edited device name from Settings.
  /// - Android: there's no official API for the editable "Device name",
  ///   so we use the model (e.g. "Pixel 7") as a reasonable label.
  static Future<String> getDeviceName() async {
    try {
      final info = await _plugin.deviceInfo;

      if (info is AndroidDeviceInfo) {
        return info.model; // closest thing to a user-facing name
      }

      if (info is IosDeviceInfo) {
        return info.name;
      }

      if (info is WebBrowserInfo) {
        final browser = info.browserName.name;
        return '$browser Browser';
      }

      return 'Unknown Device';
    } catch (_) {
      return 'Unknown Device';
    }
  }

  static String _hash(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }
}
