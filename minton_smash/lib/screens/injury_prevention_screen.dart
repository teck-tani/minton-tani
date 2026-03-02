import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme.dart';

class InjuryPreventionScreen extends StatelessWidget {
  const InjuryPreventionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color textColor = isDark ? Colors.white : const Color(0xFF0F172A); // slate-900

    return SafeArea(
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Custom Native-like AppBar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Symbols.arrow_back, color: textColor),
                      onPressed: () {},
                    ),
                    Text(
                      '부상 방지 알림',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Symbols.help, color: textColor),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),

              // Main Warning Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B0D0D).withOpacity(0.2), // red-950/20
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Hero Image
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Image.network(
                                'https://lh3.googleusercontent.com/aida-public/AB6AXuD027jZzMq-u-NJYmroB8PSP4SkzqviK-k5z-dZKSbBSv7euhB8pYOC-V8rcNGPyCJ7WiEOiYR0HQuTVLfeBjftfmLigSMVnK9rnk8OpMWR5j0e-0Q89Pk-zs6hfpjkalw-oS-Gd02-QKlgTlLn4IYOVypduzQonIkpNGBO9r-CuHhfW_YXU6EjHpO90hZDWh2zLz-icYEY2hbmKb82j0MXmqu3Ph1mhMqv6A0mdFStHGfqc4NPeB0CXkgnPxv__RTYd-Whmnzp0wI',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          // Gradient Overlay
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.8),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Warning Badge
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.red[600],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Symbols.warning, color: Colors.white, size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    '고위험 감지',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Valgus Pulse Indicator (Simulated)
                          Positioned(
                            top: 100, // Approximate values
                            left: 170,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.red, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.6),
                                    blurRadius: 15,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      // Issue Description
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              '무릎 안쪽 꺾임 (Knee Valgus)',
                              style: TextStyle(
                                color: Color(0xFFF87171), // red-400
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '마지막 스매시 착지 중 무릎이 안쪽으로 꺾이는(Valgus) 현상이 감지되었습니다. 이러한 동작 패턴은 전방 십자 인대(ACL) 부상 위험을 크게 높입니다.',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[600],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('착지 메커니즘 분석', style: TextStyle(fontWeight: FontWeight.bold)),
                                  SizedBox(width: 8),
                                  Icon(Symbols.arrow_forward, size: 18),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Immediate Corrective Exercises Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Symbols.medical_services, color: Colors.orange, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          '즉각적인 교정 운동',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '관절을 안정시키기 위해 다음 훈련을 수행하세요.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Exercise Items
              _buildExerciseCard(
                context: context,
                badgeText: '유연성',
                badgeColor: AppTheme.primaryColor,
                title: '둔근 활성화',
                description: '고관절 내회전을 방지하기 위한 엉덩이 스트레칭.',
                buttonText: '동영상 보기',
                buttonIcon: Symbols.play_circle,
                imgUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuArVezca2t0YEUDICpUz-p1ZwUVgWy0N0hwEne4-JvDK5An4EsnsvwffLHLbmYVm87I960MFe8ANg1pzuZE7dv5lFjCiXIwxMpmmIsbQzqKMJHE9Sz-hPK-iT9WHJYpR3GmjudWNwb7_oN_xQmtfBNDjtk3Xyg1E0JNjLVbFliyj0AVWlu2xjGvXTs-B2fPtxLX6x50FuIQdq1r48gY2-inMt1UUy5MzTxu2V962mSjITL6AIzJ2CFitkDHAdAame_qkfbCH1ybLcQ',
                durationText: '2:30',
              ),

              const SizedBox(height: 12),

              _buildExerciseCard(
                context: context,
                badgeText: '근력 강화',
                badgeColor: Colors.orange,
                title: '싱글 레그 스쿼트',
                description: '한 발 착지 안정성을 키우세요.',
                buttonText: '훈련 시작',
                buttonIcon: Symbols.timer,
                imgUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuATuLhXMfT3EE8Pg_bTjMvlL9XMLMZ-cmo-sGGHdq1GP-MwX7SILwaz8bzTfZr6lpd20XoLKWqRyIsM7_t5XVzNi9O3naaW4OAeE2hYbCDanghNArm80F0ervjjQ_sye_IuVqHxlzb4jPD-Q6RWeXig9ufnwgK4x2oq4M5iaTyZbGWyazVf72_Rfk4bcDkQd-jHK9gR0fQgLdcaOOX-Md1kwXEKmfMRjA4ZHanD26Kl1ZHj3I-EXkHpc6vUVJ_Z23fmm_lJT8ek8lA',
                durationText: '3 세트',
              ),

              const SizedBox(height: 24),

              // Pro Tip Box
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Symbols.info, color: AppTheme.primaryColor, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '프로 팁',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: textColor,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '착지할 때 무릎이 두 번째 발가락과 일직선이 되도록 집중하세요. 무릎이 안쪽으로 쏠리지 않도록 주의해야 합니다.',
                              style: TextStyle(
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExerciseCard({
    required BuildContext context,
    required String badgeText,
    required Color badgeColor,
    required String title,
    required String description,
    required String buttonText,
    required IconData buttonIcon,
    required String imgUrl,
    required String durationText,
  }) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C222B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        color: badgeColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: Icon(buttonIcon, size: 16, color: isDark ? Colors.white : Colors.black),
                    label: Text(
                      buttonText,
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.grey[700] : Colors.grey[100],
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      minimumSize: const Size(0, 32),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 100,
                height: 75,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(imgUrl, fit: BoxFit.cover),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          durationText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
