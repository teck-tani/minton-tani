import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'theme.dart';
import 'screens/injury_prevention_screen.dart';
import 'screens/camera_mirror_screen.dart';
import 'screens/biomechanics_report_screen.dart';
import 'screens/training_screen.dart';
import 'screens/my_page_screen.dart';
import 'screens/login_screen.dart';
import 'widgets/bottom_nav_bar.dart';
import 'providers/auth_provider.dart';
import 'config/social_auth_config.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Camera list as a Riverpod provider
final camerasProvider = Provider<List<CameraDescription>>((ref) => []);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Kakao SDK
  KakaoSdk.init(nativeAppKey: SocialAuthConfig.kakaoNativeAppKey);

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
      overrides: [
        camerasProvider.overrideWithValue(cameras),
      ],
      child: const MintonSmashApp(),
    ),
  );
}

class MintonSmashApp extends StatelessWidget {
  const MintonSmashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Minton Smash',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Routes to LoginScreen or MainLayoutScreen based on auth state
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    switch (authState.status) {
      case AuthStatus.unknown:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case AuthStatus.unauthenticated:
        return const LoginScreen();
      case AuthStatus.authenticated:
        return const MainLayoutScreen();
    }
  }
}

class MainLayoutScreen extends ConsumerStatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  ConsumerState<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends ConsumerState<MainLayoutScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final cameras = ref.watch(camerasProvider);

    final List<Widget> screens = [
      const BiomechanicsReportScreen(),
      const InjuryPreventionScreen(),
      CameraMirrorScreen(cameras: cameras),
      const TrainingScreen(),
      const MyPageScreen(),
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
