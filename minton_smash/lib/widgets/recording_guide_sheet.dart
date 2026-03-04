import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme.dart';
import 'recording_guide_painter.dart';

/// Shows a modal bottom sheet with recording angle guide for badminton smash.
/// Returns true if user tapped "촬영 시작하기".
Future<bool?> showRecordingGuideSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _RecordingGuideContent(),
  );
}

class _RecordingGuideContent extends StatelessWidget {
  const _RecordingGuideContent();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1C222B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Close button
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: Icon(Symbols.close, color: subColor),
              onPressed: () => Navigator.pop(context, false),
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    '정면 또는 측면에 맞춰\n촬영해 주세요',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '대각선 또는 뒷모습을 촬영한 영상은\n진단할 수 없어요.',
                    style: TextStyle(
                      fontSize: 14,
                      color: subColor,
                      height: 1.5,
                    ),
                  ),

                  // Illustration
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 280,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: RecordingGuidePainter(),
                    ),
                  ),

                  // Tips section
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.primaryColor.withOpacity(0.1)
                          : const Color(0xFFF0F7FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Symbols.lightbulb, color: AppTheme.primaryColor, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '촬영 팁',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _tipItem('전신이 보이도록 2~3m 거리에서 촬영', subColor),
                        const SizedBox(height: 8),
                        _tipItem('밝은 곳에서 촬영하면 더 정확해요', subColor),
                        const SizedBox(height: 8),
                        _tipItem('측면 촬영 시 라켓 쪽에서 촬영', subColor),
                        const SizedBox(height: 8),
                        _tipItem('삼각대 사용을 추천합니다', subColor),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Start button
          Padding(
            padding: EdgeInsets.fromLTRB(
              24, 12, 24, MediaQuery.of(context).padding.bottom + 16,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '촬영 시작하기',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tipItem(String text, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('  •  ', style: TextStyle(color: color, fontSize: 14)),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: color, height: 1.4),
          ),
        ),
      ],
    );
  }
}
