import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> init() async {
    await _messaging.requestPermission();
   
  }

  // Called when new research findings are available (simulated)
  Future<void> showResearchNotification(String title, String body) async {
    // For now this is just a placeholder; real push comes from FCM backend.
  }
}
