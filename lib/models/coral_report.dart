import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

class CoralReport extends HiveObject {
  String id;
  String imageBase64;
  double latitude;
  double longitude;
  String aiScore; // Healthy / Bleached / Dead / Unknown
  DateTime createdAt;
  String contributorId; // unique deviceId
  String deviceName; // human-readable
  bool gpsVerified;
  bool synced;

  CoralReport({
    required this.id,
    required this.imageBase64,
    required this.latitude,
    required this.longitude,
    required this.aiScore,
    required this.createdAt,
    required this.contributorId,
    required this.deviceName,
    required this.gpsVerified,
    required this.synced,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'imageBase64': imageBase64,
      'lat': latitude,
      'lng': longitude,
      'aiScore': aiScore,
      'createdAt': createdAt.toUtc(),
      'contributorId': contributorId,
      'deviceName': deviceName,
      'gpsVerified': gpsVerified,
    };
  }

  static CoralReport fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final raw = data['createdAt'];
    DateTime created;
    if (raw is Timestamp) {
      created = raw.toDate();
    } else if (raw is DateTime) {
      created = raw;
    } else {
      created = DateTime.now().toUtc();
    }

    return CoralReport(
      id: id,
      imageBase64: data['imageBase64'] as String? ?? '',
      latitude: (data['lat'] as num?)?.toDouble() ?? 0,
      longitude: (data['lng'] as num?)?.toDouble() ?? 0,
      aiScore: data['aiScore'] as String? ?? 'Unknown',
      createdAt: created,
      contributorId: data['contributorId'] as String? ?? 'unknown',
      deviceName: data['deviceName'] as String? ?? 'Unknown Device',
      gpsVerified: data['gpsVerified'] as bool? ?? false,
      synced: true,
    );
  }
}

/// Manual Hive adapter (typeId = 0). Existing data with fewer fields still works.
class CoralReportAdapter extends TypeAdapter<CoralReport> {
  @override
  final int typeId = 0;

  @override
  CoralReport read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return CoralReport(
      id: fields[0] as String,
      imageBase64: fields[1] as String,
      latitude: fields[2] as double,
      longitude: fields[3] as double,
      aiScore: fields[4] as String,
      createdAt: fields[5] as DateTime,
      contributorId: fields[6] as String,
      gpsVerified: fields[7] as bool,
      synced: fields[8] as bool,
      deviceName: fields[9] as String? ??
          'Unknown Device', // new field, default if older record
    );
  }

  @override
  void write(BinaryWriter writer, CoralReport obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.imageBase64)
      ..writeByte(2)
      ..write(obj.latitude)
      ..writeByte(3)
      ..write(obj.longitude)
      ..writeByte(4)
      ..write(obj.aiScore)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.contributorId)
      ..writeByte(7)
      ..write(obj.gpsVerified)
      ..writeByte(8)
      ..write(obj.synced)
      ..writeByte(9)
      ..write(obj.deviceName);
  }
}
