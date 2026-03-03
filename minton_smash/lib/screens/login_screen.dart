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
                  // Kakao
                  _SocialLoginButton(
                    onPressed: authState.isLoading
                        ? null
                        : () => ref.read(authProvider.notifier).signInWithKakao(),
                    backgroundColor: const Color(0xFFFEE500),
                    textColor: const Color(0xFF191919),
                    icon: _kakaoIcon(),
                    label: '카카오로 시작하기',
                  ),
                  const SizedBox(height: 12),

                  // Naver
                  _SocialLoginButton(
                    onPressed: authState.isLoading
                        ? null
                        : () => ref.read(authProvider.notifier).signInWithNaver(),
                    backgroundColor: const Color(0xFF03C75A),
                    textColor: Colors.white,
                    icon: _naverIcon(),
                    label: '네이버로 시작하기',
                  ),
                  const SizedBox(height: 12),

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
  static Widget _kakaoIcon() {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _KakaoLogoPainter()),
    );
  }

  static Widget _naverIcon() {
    return const Text(
      'N',
      style: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    );
  }

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

// Kakao speech-bubble logo painted with CustomPaint
class _KakaoLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF191919)
      ..style = PaintingStyle.fill;

    final path = Path();
    final w = size.width;
    final h = size.height;

    // Simplified Kakao talk bubble shape
    path.addOval(Rect.fromLTWH(w * 0.1, h * 0.1, w * 0.8, h * 0.6));
    // Tail
    path.moveTo(w * 0.3, h * 0.65);
    path.lineTo(w * 0.2, h * 0.85);
    path.lineTo(w * 0.45, h * 0.7);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
