import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

import '../models/coral_report.dart';

class CoralSyncService {
  final FirebaseFirestore firestore;
  final Box<CoralReport> localBox;

  CoralSyncService(this.firestore, this.localBox);

  /// Returns:
  ///   >= 0 : number of successfully synced reports
  ///   -1   : failed due to network/other error (likely offline)
  Future<int> syncPendingReports() async {
    int count = 0;

    for (final report in localBox.values) {
      if (report.synced == true) continue;

      try {
        await firestore
            .collection('coralReports')
            .doc(report.id)
            .set(report.toFirestore(), SetOptions(merge: true));

        report.synced = true;
        await report.save();
        count++;
      } on FirebaseException catch (_) {
        // Probably offline / permission / network issue
        return count == 0 ? -1 : count;
      } catch (_) {
        return count == 0 ? -1 : count;
      }
    }

    return count;
  }
}
