import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'theme.dart';
import 'screens/injury_prevention_screen.dart';
import 'screens/camera_mirror_screen.dart';
import 'screens/biomechanics_report_screen.dart';
import 'widgets/bottom_nav_bar.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Error initializing Firebase: $e');
  }
  
  List<CameraDescription> cameras = [];
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    debugPrint('Error fetching cameras: $e');
  }

  runApp(
    ProviderScope(
      child: MintonSmashApp(cameras: cameras),
    ),
  );
}

class MintonSmashApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  
  const MintonSmashApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Minton Smash',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: MainLayoutScreen(cameras: cameras),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainLayoutScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  
  const MainLayoutScreen({super.key, required this.cameras});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _currentIndex = 0; // Default to 'Home' (the Diagnostic Report Dashboard)

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const BiomechanicsReportScreen(),
      const InjuryPreventionScreen(),
      CameraMirrorScreen(cameras: widget.cameras), // The actual Realtime Mirror Screen
      const Center(child: Text('훈련')),
      const Center(child: Text('마이페이지')),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
