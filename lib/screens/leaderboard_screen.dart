import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class LeaderboardScreen extends StatelessWidget {
  final String deviceId;

  const LeaderboardScreen({super.key, required this.deviceId});

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.collection('coralReports');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text("No coral reports yet."));
        }

        final Map<String, _LeaderEntry> byDevice = {};

        for (var d in docs) {
          final data = d.data();
          final id = data['contributorId'] as String? ?? 'unknown';
          final name = data['deviceName'] as String? ?? 'Unknown Device';

          if (!byDevice.containsKey(id)) {
            byDevice[id] = _LeaderEntry(
              deviceId: id,
              deviceName: name,
              count: 0,
            );
          }

          byDevice[id] = byDevice[id]!.copyWith(count: byDevice[id]!.count + 1);
        }

        final entries = byDevice.values.toList()
          ..sort((a, b) => b.count.compareTo(a.count));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: entries.length,
          itemBuilder: (_, i) {
            final entry = entries[i];
            final isYou = entry.deviceId == deviceId;

            final titleText =
                isYou ? '${entry.deviceName} (You)' : entry.deviceName;

            final avatarLabel = entry.deviceName.isNotEmpty
                ? entry.deviceName.characters.first.toUpperCase()
                : '?';

            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(avatarLabel),
                ),
                title: Text(
                  titleText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isYou
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ),
                subtitle: Text("Reports: ${entry.count}"),
                trailing: Text("#${i + 1}"),
              ),
            );
          },
        );
      },
    );
  }
}

class _LeaderEntry {
  final String deviceId;
  final String deviceName;
  final int count;

  _LeaderEntry({
    required this.deviceId,
    required this.deviceName,
    required this.count,
  });

  _LeaderEntry copyWith({int? count}) {
    return _LeaderEntry(
      deviceId: deviceId,
      deviceName: deviceName,
      count: count ?? this.count,
    );
  }
}
