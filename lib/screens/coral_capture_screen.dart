import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../models/coral_report.dart';
import '../services/coral_health_scorer.dart';
import '../services/coral_sync_service.dart';
import '../services/exif_service.dart';
import '../services/location_service.dart';

class CoralCaptureScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;

  const CoralCaptureScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  State<CoralCaptureScreen> createState() => _CoralCaptureScreenState();
}

class _CoralCaptureScreenState extends State<CoralCaptureScreen> {
  final _picker = ImagePicker();
  final _scorer = CoralHealthScorer();

  Uint8List? _imageBytes;
  String _aiScore = '';
  bool _gpsVerified = false;
  bool _loading = false;

  String? _deviceGpsString;
  String? _imageGpsString;

  late CoralSyncService _syncService;

  @override
  void initState() {
    super.initState();
    final box = Hive.box<CoralReport>('coral_reports_v2');
    _syncService = CoralSyncService(FirebaseFirestore.instance, box);
  }

  String _newId() {
    final r = Random();
    return "rep_${DateTime.now().microsecondsSinceEpoch}_${r.nextInt(999999)}";
  }

  Future<void> _pickImage(bool fromCamera) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _imageBytes = null;
      _aiScore = '';
      _gpsVerified = false;
      _deviceGpsString = null;
      _imageGpsString = null;
    });

    try {
      final source = fromCamera ? ImageSource.camera : ImageSource.gallery;
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (picked == null) {
        return;
      }

      final bytes = await picked.readAsBytes();
      final enhanced = await _enhanceUnderwater(bytes);

      setState(() {
        _imageBytes = enhanced;
      });

      await _runAiAndExif(enhanced);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Image error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Uint8List> _enhanceUnderwater(Uint8List bytes) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    final filtered = img.adjustColor(decoded, exposure: 0.5, gamma: 0.9);
    return Uint8List.fromList(img.encodeJpg(filtered, quality: 90));
  }

  Future<void> _runAiAndExif(Uint8List bytes) async {
    try {
      final pos = await LocationService.getCurrentPosition();
      final score = await _scorer.scoreCoral(bytes);

      String? deviceGps;
      bool verified = false;
      String? imageGps;

      if (pos != null) {
        deviceGps =
            '${pos.latitude.toStringAsFixed(6)},${pos.longitude.toStringAsFixed(6)}';

        imageGps = await ExifService.extractGpsString(bytes);

        verified = await ExifService.verifyGpsMatches(
          bytes,
          pos.latitude,
          pos.longitude,
        );
      }

      setState(() {
        _aiScore = score;
        _gpsVerified = verified;
        _deviceGpsString = deviceGps;
        _imageGpsString = imageGps;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('AI/EXIF error: $e')));
    }
  }

  Future<Uint8List> _compress(Uint8List bytes) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    var quality = 90;
    late Uint8List out;

    do {
      out = Uint8List.fromList(img.encodeJpg(decoded, quality: quality));
      quality -= 10;
    } while (out.length > 500 * 1024 && quality > 10);

    return out;
  }

  Future<void> _saveReport() async {
    if (_imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture or select a coral photo.')),
      );
      return;
    }
    if (_aiScore.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI score not ready yet.')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location is required to save a report.'),
          ),
        );
        return;
      }

      final compressed = await _compress(_imageBytes!);
      final base64Img = base64Encode(compressed);

      final report = CoralReport(
        id: _newId(),
        imageBase64: base64Img,
        latitude: pos.latitude,
        longitude: pos.longitude,
        aiScore: _aiScore,
        createdAt: DateTime.now().toUtc(),
        contributorId: widget.deviceId,
        deviceName: widget.deviceName,
        gpsVerified: _gpsVerified,
        synced: false,
      );

      final box = Hive.box<CoralReport>('coral_reports_v2');
      await box.put(report.id, report);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved locally. Use Sync to upload later.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Save error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _syncNow() async {
    setState(() => _loading = true);
    int result;
    try {
      result = await _syncService.syncPendingReports();
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }

    if (result == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No internet connection. Could not sync.'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Synced $result report(s).')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    final mainContent = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Modernized capture area
          AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.brown.withValues(alpha: 0.06),
                      Colors.brown.withValues(alpha: 0.02),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: _imageBytes != null
                    ? Image.memory(
                        _imageBytes!,
                        fit: BoxFit.cover,
                      )
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.camera_alt,
                                size: 40,
                                color:  Colors.brown.withValues(alpha: 0.7)),
                            const SizedBox(height: 8),
                            Text(
                              'Tap Camera or Gallery',
                              style: TextStyle(
                                color: Colors.brown.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : () => _pickImage(true),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : () => _pickImage(false),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_aiScore.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Score: $_aiScore',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('GPS verified: ${_gpsVerified ? 'YES' : 'NO'}'),
                  if (_deviceGpsString != null ||
                      _imageGpsString != null) ...[
                    const SizedBox(height: 4),
                    Text('Device GPS: ${_deviceGpsString ?? 'None'}'),
                    Text('Image GPS:  ${_imageGpsString ?? 'None'}'),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loading ? null : _saveReport,
            icon: const Icon(Icons.save),
            label: const Text('Save Coral Report'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _loading ? null : _syncNow,
            icon: const Icon(Icons.sync),
            label: const Text('Sync Pending Reports'),
          ),
        ],
      ),
    );

    final overlay = _loading
        ? Container(
            color: Colors.black.withValues(alpha: 0.25),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      height: 32,
                      width: 32,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _imageBytes == null
                          ? 'Loading image...'
                          : (_aiScore.isEmpty
                              ? 'Analyzing coral health...'
                              : 'Processing...'),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          )
        : const SizedBox.shrink();

    return Stack(
      children: [
        mainContent,
        if (_loading) overlay,
      ],
    );
  }
}
