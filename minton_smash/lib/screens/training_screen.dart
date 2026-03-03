import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/analysis_provider.dart';
import '../theme.dart';

class TrainingScreen extends ConsumerWidget {
  const TrainingScreen({super.key});

  static const _drills = [
    // 초급
    {'level': '초급', 'name': '기본 그립 연습', 'description': '포핸드/백핸드 기본 그립을 익히세요.', 'targetReps': 50, 'type': 'grip'},
    {'level': '초급', 'name': '하이 서브 연습', 'description': '높은 궤도의 서브를 정확하게 넣는 연습.', 'targetReps': 30, 'type': 'serve'},
    {'level': '초급', 'name': '풋워크 기초', 'description': '6방향 풋워크 기본 이동 패턴 연습.', 'targetReps': 40, 'type': 'footwork'},
    // 중급
    {'level': '중급', 'name': '스매시 타이밍', 'description': '타점과 팔꿈치 스냅 타이밍을 맞추세요.', 'targetReps': 30, 'type': 'smash'},
    {'level': '중급', 'name': '드롭샷 정밀도', 'description': '네트 근처에 정확히 떨어뜨리는 연습.', 'targetReps': 25, 'type': 'drop'},
    {'level': '중급', 'name': '리시브 반응속도', 'description': '상대 스매시에 대한 리시브 반응 훈련.', 'targetReps': 30, 'type': 'receive'},
    // 고급
    {'level': '고급', 'name': '점프 스매시', 'description': '점프하면서 최대 파워 스매시 연습.', 'targetReps': 20, 'type': 'jumpSmash'},
    {'level': '고급', 'name': '디셉션 샷', 'description': '상대를 속이는 페이크 동작 연습.', 'targetReps': 15, 'type': 'deception'},
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trainingAsync = ref.watch(trainingProgressProvider);

    return SafeArea(
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('훈련 로드맵', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('단계별로 실력을 키워보세요', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                  ],
                ),
              ),

              // Weekly progress summary
              trainingAsync.when(
                data: (progress) => _buildWeeklySummary(context, progress),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 8),

              // Drill sections by level
              ..._buildLevelSections(context, ref, isDark, trainingAsync),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklySummary(BuildContext context, List<Map<String, dynamic>> progress) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final weeklyProgress = progress.where((p) {
      final dateStr = p['date'] as String?;
      if (dateStr == null) return false;
      final date = DateTime.tryParse(dateStr);
      return date != null && date.isAfter(weekAgo);
    }).toList();

    final totalCompleted = weeklyProgress.fold<int>(0, (acc, p) => acc + ((p['completedReps'] as num?)?.toInt() ?? 0));
    final totalDays = weeklyProgress.map((p) => (p['date'] as String?)?.substring(0, 10)).toSet().length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primaryColor.withOpacity(0.15), Colors.transparent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Expanded(
              child: _summaryItem('이번 주 훈련', '$totalDays일', Symbols.calendar_month, isDark),
            ),
            Container(width: 1, height: 40, color: Colors.grey.withOpacity(0.3)),
            Expanded(
              child: _summaryItem('완료 횟수', '$totalCompleted회', Symbols.check_circle, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String label, String value, IconData icon, bool isDark) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 22),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600])),
      ],
    );
  }

  List<Widget> _buildLevelSections(BuildContext context, WidgetRef ref, bool isDark, AsyncValue<List<Map<String, dynamic>>> trainingAsync) {
    final levels = ['초급', '중급', '고급'];
    final levelColors = [Colors.green, Colors.orange, Colors.red];
    final levelIcons = [Symbols.star, Symbols.military_tech, Symbols.diamond];

    return levels.asMap().entries.map((entry) {
      final idx = entry.key;
      final level = entry.value;
      final drills = _drills.where((d) => d['level'] == level).toList();

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Level header with timeline dot
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: levelColors[idx].withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: levelColors[idx], width: 2),
                  ),
                  child: Icon(levelIcons[idx], color: levelColors[idx], size: 16),
                ),
                const SizedBox(width: 10),
                Text(level, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: levelColors[idx])),
              ],
            ),
            const SizedBox(height: 8),

            // Drill cards
            ...drills.map((drill) {
              final completedReps = trainingAsync.whenOrNull(
                data: (progress) {
                  final match = progress.where((p) => p['drillType'] == drill['type']).toList();
                  return match.fold<int>(0, (acc, p) => acc + ((p['completedReps'] as num?)?.toInt() ?? 0));
                },
              ) ?? 0;
              final targetReps = drill['targetReps'] as int;
              final progress = (completedReps / targetReps).clamp(0.0, 1.0);

              return Container(
                margin: const EdgeInsets.only(bottom: 10, left: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C222B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(drill['name'] as String, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black)),
                        ),
                        Text('$completedReps / $targetReps', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(drill['description'] as String, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 6,
                              backgroundColor: levelColors[idx].withOpacity(0.1),
                              valueColor: AlwaysStoppedAnimation(levelColors[idx]),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => _completeDrill(context, drill['type'] as String),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: levelColors[idx].withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Symbols.add, size: 14, color: levelColors[idx]),
                                const SizedBox(width: 2),
                                Text('완료', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: levelColors[idx])),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      );
    }).toList();
  }

  void _completeDrill(BuildContext context, String drillType) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance.collection('trainingProgress').add({
      'userId': uid,
      'date': DateTime.now().toIso8601String(),
      'drillType': drillType,
      'completedReps': 1,
      'duration': 0,
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('훈련 1회 완료!'), duration: Duration(seconds: 1)),
      );
    }
  }
}
