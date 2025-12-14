import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _dateFilter = '30d'; // 7d, 30d, all

  DateTime _minDate() {
    final now = DateTime.now().toUtc();
    if (_dateFilter == '7d') return now.subtract(const Duration(days: 7));
    if (_dateFilter == '30d') return now.subtract(const Duration(days: 30));
    return DateTime(2000);
  }

  String _regionFromLatLng(double lat, double lng) {
    // Very rough region binning just for assignment
    if (lat > 23.5) return 'North';
    if (lat < 20) return 'South';
    return 'Central';
  }

  @override
  Widget build(BuildContext context) {
    final reportsRef =
        FirebaseFirestore.instance.collection('coralReports');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text('Date range:'),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _dateFilter,
                items: const [
                  DropdownMenuItem(value: '7d', child: Text('Last 7 days')),
                  DropdownMenuItem(value: '30d', child: Text('Last 30 days')),
                  DropdownMenuItem(value: 'all', child: Text('All time')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _dateFilter = v);
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: reportsRef.snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Center(child: Text('No coral reports yet.'));
              }

              final minDate = _minDate();
              final Map<String, Map<String, int>> byRegion = {};

              for (final d in docs) {
                final data = d.data();

                DateTime created;
                final raw = data['createdAt'];
                if (raw is Timestamp) {
                  created = raw.toDate();
                } else if (raw is DateTime) {
                  created = raw;
                } else {
                  continue;
                }
                if (created.isBefore(minDate)) continue;

                final lat = (data['lat'] as num?)?.toDouble() ?? 0;
                final lng = (data['lng'] as num?)?.toDouble() ?? 0;
                final score = data['aiScore'] as String? ?? 'Unknown';

                final region = _regionFromLatLng(lat, lng);
                byRegion.putIfAbsent(region, () => {
                      'Healthy': 0,
                      'Bleached': 0,
                      'Dead': 0,
                    });
                byRegion[region]![score] =
                    (byRegion[region]![score] ?? 0) + 1;
              }

              if (byRegion.isEmpty) {
                return const Center(
                  child: Text('No reports in this date range.'),
                );
              }

              final regions = byRegion.keys.toList()..sort();
              final healthStatuses = ['Healthy', 'Bleached', 'Dead'];

              return Padding(
                padding: const EdgeInsets.all(16),
                child: BarChart(
                  BarChartData(
                    barGroups: List.generate(regions.length, (i) {
                      final region = regions[i];
                      final counts = byRegion[region]!;
                      return BarChartGroupData(
                        x: i,
                        barRods: List.generate(healthStatuses.length, (j) {
                          final status = healthStatuses[j];
                          final count = counts[status] ?? 0;
                          return BarChartRodData(
                            toY: count.toDouble(),
                          );
                        }),
                      );
                    }),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= regions.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                regions[index],
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: true),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
