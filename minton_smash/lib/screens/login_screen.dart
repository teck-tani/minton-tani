import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: Colors.red),
        );
      }
    });

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background — dark with subtle shuttlecock image
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0A1118),
                  Color(0xFF101922),
                  Color(0xFF0A1118),
                ],
              ),
            ),
          ),

          // Shuttlecock image overlay (faded)
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: Opacity(
              opacity: 0.3,
              child: Icon(
                Icons.sports_tennis,
                size: 200,
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
          ),

          // Gradient overlay from bottom
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.4, 0.7, 1.0],
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    const Color(0xFF101922).withValues(alpha: 0.8),
                    const Color(0xFF101922),
                  ],
                ),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const Spacer(flex: 3),

                  // AI Icon
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFF137FEC).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Color(0xFF137FEC),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  const Text(
                    '생성형 AI 코치',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Subtitle
                  Text(
                    '당신의 배드민턴 폼을 AI로 분석하고\n실력을 향상시키세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),

                  const Spacer(flex: 2),

                  // --- Login Buttons ---
                  // Google
                  _SocialLoginButton(
                    onPressed: authState.isLoading
                        ? null
                        : () => ref.read(authProvider.notifier).signInWithGoogle(),
                    backgroundColor: Colors.white,
                    textColor: const Color(0xFF191919),
                    icon: _googleIcon(),
                    label: 'Google로 시작하기',
                  ),
                  const SizedBox(height: 12),

                  // Apple
                  _SocialLoginButton(
                    onPressed: authState.isLoading
                        ? null
                        : () => ref.read(authProvider.notifier).signInWithApple(),
                    backgroundColor: const Color(0xFF000000),
                    textColor: Colors.white,
                    icon: _appleIcon(),
                    label: 'Apple로 시작하기',
                  ),
                  const SizedBox(height: 20),

                  // Guest
                  TextButton(
                    onPressed: authState.isLoading
                        ? null
                        : () => ref.read(authProvider.notifier).signInAsGuest(),
                    child: Text(
                      '게스트로 둘러보기',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Terms
                  Text(
                    '계속 진행하면 이용약관 및 개인정보처리방침에\n동의하게 됩니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Loading indicator
                  if (authState.isLoading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: CircularProgressIndicator(
                        color: Color(0xFF137FEC),
                        strokeWidth: 2,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- SNS Icon Widgets ---
  static Widget _googleIcon() {
    return const Text(
      'G',
      style: TextStyle(
        color: Color(0xFF4285F4),
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  static Widget _appleIcon() {
    return const Icon(Icons.apple, color: Colors.white, size: 20);
  }
}

class _SocialLoginButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color textColor;
  final Widget icon;
  final String label;

  const _SocialLoginButton({
    required this.onPressed,
    required this.backgroundColor,
    required this.textColor,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
