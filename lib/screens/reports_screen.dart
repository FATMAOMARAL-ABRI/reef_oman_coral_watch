import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/coral_report.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Box<CoralReport> _coralBox;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _coralBox = Hive.box<CoralReport>('coral_reports_v2');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildLocal() {
    return ValueListenableBuilder(
      valueListenable: _coralBox.listenable(),
      builder: (context, Box<CoralReport> box, _) {
        final reports = box.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (reports.isEmpty) {
          return const Center(child: Text('No local coral reports yet.'));
        }

        return ListView.builder(
          itemCount: reports.length,
          itemBuilder: (context, i) {
            final r = reports[i];
            Uint8List? thumb;
            if (r.imageBase64.isNotEmpty) {
              try {
                thumb = base64Decode(r.imageBase64);
              } catch (_) {}
            }

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: thumb != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.memory(
                          thumb,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Icon(Icons.image_not_supported),
                title: Text(
                  r.aiScore,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '📍 ${r.latitude.toStringAsFixed(4)}, ${r.longitude.toStringAsFixed(4)}\n'
                  '🕒 ${r.createdAt.toLocal()}',
                ),
                trailing: Text(
                  r.synced ? '✅ Synced' : '⏳ Pending',
                  style: TextStyle(
                    color: r.synced ? Colors.green : Colors.orange,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCloud() {
    final col = FirebaseFirestore.instance.collection('coralReports');
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: col.orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('No cloud coral reports yet.'));
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data();
            final report = CoralReport.fromFirestore(docs[i].id, data);

            Uint8List? thumb;
            if (report.imageBase64.isNotEmpty) {
              try {
                thumb = base64Decode(report.imageBase64);
              } catch (_) {}
            }

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: thumb != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.memory(
                          thumb,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Icon(Icons.image_not_supported),
                title: Text(
                  report.aiScore,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '📍 ${report.latitude.toStringAsFixed(4)}, '
                  '${report.longitude.toStringAsFixed(4)}\n'
                  '🕒 ${report.createdAt.toLocal()}',
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        Material(
          color: primary.withValues(alpha: 0.05),
          child: TabBar(
            controller: _tabController,
            labelColor: primary,
            unselectedLabelColor: primary.withValues(alpha: 0.6),
            tabs: const [
              Tab(icon: Icon(Icons.save), text: 'Local'),
              Tab(icon: Icon(Icons.cloud), text: 'Cloud'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildLocal(),
              _buildCloud(),
            ],
          ),
        ),
      ],
    );
  }
}
