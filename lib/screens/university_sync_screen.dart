import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../services/university_api_client.dart';

class UniversitySyncScreen extends StatefulWidget {
  const UniversitySyncScreen({super.key});

  @override
  State<UniversitySyncScreen> createState() => _UniversitySyncScreenState();
}

class _UniversitySyncScreenState extends State<UniversitySyncScreen> {
  bool _syncing = false;
  final _client = UniversityApiClient();

  Future<void> _syncToUniversity() async {
    setState(() => _syncing = true);
    try {
      final col = FirebaseFirestore.instance.collection('coralReports');
      final snapshot = await col.get();

      final Map<String, Map<String, int>> aggregated = {};

      for (final d in snapshot.docs) {
        final data = d.data();
        final lat = (data['lat'] as num?)?.toDouble() ?? 0;
        final score = data['aiScore'] as String? ?? 'Unknown';

        final region =
            lat > 23.5 ? 'North' : (lat < 20 ? 'South' : 'Central');

        aggregated.putIfAbsent(region, () => {
              'Healthy': 0,
              'Bleached': 0,
              'Dead': 0,
            });
        aggregated[region]![score] =
            (aggregated[region]![score] ?? 0) + 1;
      }

      await _client.syncAggregatedData(aggregated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Synced to SQU reef DB (mock).')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _shareSummary() async {
    final col = FirebaseFirestore.instance.collection('coralReports');
    final snapshot = await col.get();

    final total = snapshot.docs.length;
    final healthy = snapshot.docs
        .where((d) => (d.data()['aiScore'] as String?) == 'Healthy')
        .length;

    final msg =
        'Reef Oman: $total coral reports submitted, $healthy healthy!';

    await Share.share(msg);
  }

  @override
  Widget build(BuildContext context) {
    final spacing = 16.0;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(spacing),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Sultan Qaboos University API',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color.fromARGB(180, 0, 0, 0)),
            ),
            const Text(
              'Sync Screen',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color.fromARGB(180, 0, 0, 0)),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _syncing ? null : _syncToUniversity,
                icon: const Icon(Icons.cloud_upload),
                label: _syncing
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Sync To University'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _shareSummary,
                icon: const Icon(Icons.share),
                label: const Text('Share Coral Scores'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
