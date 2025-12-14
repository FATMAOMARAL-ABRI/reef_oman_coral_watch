import 'dart:typed_data';

import 'package:exif/exif.dart';

class ExifService {
  /// Compare GPS string from EXIF with GPS string from device.
  ///
  /// "Verified" means:
  ///   format(EXIF lat,lng) == format(device lat,lng)
  /// using 6 decimal places.
  static Future<bool> verifyGpsMatches(
    Uint8List imageBytes,
    double deviceLat,
    double deviceLng,
  ) async {
    try {
      final gps = await _extractGps(imageBytes);
      if (gps == null) {
        // No GPS in EXIF -> cannot verify
        return false;
      }

      // Ignore bogus 0,0 coordinates
      if (gps.lat == 0 && gps.lng == 0) {
        return false;
      }

      final imageGpsString = _formatGps(gps.lat, gps.lng);
      final deviceGpsString = _formatGps(deviceLat, deviceLng);

      // For debugging, you can print in console if needed:
      // print('EXIF GPS:   $imageGpsString');
      // print('Device GPS: $deviceGpsString');

      return imageGpsString == deviceGpsString;
    } catch (_) {
      return false;
    }
  }

  /// Returns the EXIF GPS string "lat,lng" if available, else null.
  static Future<String?> extractGpsString(Uint8List bytes) async {
    final gps = await _extractGps(bytes);
    if (gps == null) return null;
    if (gps.lat == 0 && gps.lng == 0) return null;
    return _formatGps(gps.lat, gps.lng);
  }

  /// Extract GPS (lat/lng in degrees) from EXIF if present.
  static Future<_ExifGps?> _extractGps(Uint8List bytes) async {
    final tags = await readExifFromBytes(bytes);

    // Try common key patterns
    final latTag = tags['GPS GPSLatitude'] ??
        tags['GPSLatitude'] ??
        tags['GPS Latitude'];
    final lngTag = tags['GPS GPSLongitude'] ??
        tags['GPSLongitude'] ??
        tags['GPS Longitude'];

    if (latTag == null || lngTag == null) {
      return null;
    }

    final latValues = latTag.values;
    final lngValues = lngTag.values;

    double lat = _convertToDegrees(latValues);
    double lng = _convertToDegrees(lngValues);

    // Handle N/S/E/W
    final latRefTag = tags['GPS GPSLatitudeRef'] ?? tags['GPSLatitudeRef'];
    final lngRefTag = tags['GPS GPSLongitudeRef'] ?? tags['GPSLongitudeRef'];

    final latRef = latRefTag?.printable.toUpperCase() ?? 'N';
    final lngRef = lngRefTag?.printable.toUpperCase() ?? 'E';

    if (latRef.contains('S')) lat = -lat;
    if (lngRef.contains('W')) lng = -lng;

    return _ExifGps(lat: lat, lng: lng);
  }

  /// Convert EXIF GPS array of rationals (e.g. ["23/1", "30/1", "1234/100"])
  static double _convertToDegrees(dynamic values) {
    if (values is! List || values.length < 3) return 0;

    final d = _ratioToDouble(values[0]);
    final m = _ratioToDouble(values[1]);
    final s = _ratioToDouble(values[2]);

    return d + (m / 60.0) + (s / 3600.0);
  }

  /// Convert an EXIF rational (like "34/1") to double.
  static double _ratioToDouble(dynamic v) {
    if (v == null) return 0;

    if (v is num) return v.toDouble();

    final str = v.toString();
    if (str.contains('/')) {
      final parts = str.split('/');
      if (parts.length == 2) {
        final numStr = double.tryParse(parts[0]) ?? 0;
        final denStr = double.tryParse(parts[1]) ?? 1;
        if (denStr == 0) return 0;
        return numStr / denStr;
      }
    }

    return double.tryParse(str) ?? 0;
  }

  /// Format lat/lng into a fixed string so EXIF + device are comparable.
  static String _formatGps(double lat, double lng) {
    return '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';
  }
}

class _ExifGps {
  final double lat;
  final double lng;

  _ExifGps({required this.lat, required this.lng});
}
