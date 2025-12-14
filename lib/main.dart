import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/coral_report.dart';
import 'services/device_id_service.dart';

// Screens
import 'screens/coral_capture_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/university_sync_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: "AIzaSyAMJG7tD0QpjH_Ogy-ya_au9cSt6KrH-MI",
      appId: "1:255156424192:android:43de1e482d6af5effcd2e5",
      messagingSenderId: "255156424192",
      projectId: "coral-9d647"
    )
  );

  await Hive.initFlutter();
  Hive.registerAdapter(CoralReportAdapter());
  await Hive.openBox<CoralReport>('coral_reports_v2');

  final deviceId = await DeviceIdService.getDeviceId();
  final deviceName = await DeviceIdService.getDeviceName();

  runApp(ReefOmanApp(deviceId: deviceId, deviceName: deviceName));
}

class ReefOmanApp extends StatefulWidget {
  final String deviceId;
  final String deviceName;

  const ReefOmanApp({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  State<ReefOmanApp> createState() => _ReefOmanAppState();
}

class _ReefOmanAppState extends State<ReefOmanApp> {
  int _index = 0;

  late final List<Widget> _screens = [
    CoralCaptureScreen(
      deviceId: widget.deviceId,
      deviceName: widget.deviceName,
    ),
    LeaderboardScreen(
      deviceId: widget.deviceId,
    ),
    const DashboardScreen(),
    const ReportsScreen(),
    const UniversitySyncScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Reef Oman – Coral Watch",
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.brown,
        ),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text("Reef Oman – Coral Watch"),
        ),
        body: _screens[_index],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.camera_alt),
              label: "Capture",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.leaderboard),
              label: "Leaderboard",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart),
              label: "Dashboard",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list),
              label: "Reports",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.school),
              label: "University",
            ),
          ],
        ),
      ),
    );
  }
}
