import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/analysis_provider.dart';
import '../theme.dart';

// ═══════════════════════════════════════════════════════════════════
// Data models
// ═══════════════════════════════════════════════════════════════════

class _Drill {
  final String level;
  final String name;
  final String description;
  final int targetReps;
  final String type;
  final int order; // for roadmap unlock sequence
  final String guide; // short how-to guide
  final String correctTip;
  final String wrongTip;

  const _Drill({
    required this.level,
    required this.name,
    required this.description,
    required this.targetReps,
    required this.type,
    required this.order,
    required this.guide,
    required this.correctTip,
    required this.wrongTip,
  });
}

class _Exercise {
  final String name;
  final String description;
  final String sets;
  final IconData icon;
  final String category; // core, shoulder, legs

  const _Exercise({
    required this.name,
    required this.description,
    required this.sets,
    required this.icon,
    required this.category,
  });
}

class _StretchItem {
  final String name;
  final String duration;
  final IconData icon;

  const _StretchItem({required this.name, required this.duration, required this.icon});
}

// ═══════════════════════════════════════════════════════════════════
// Constants
// ═══════════════════════════════════════════════════════════════════

const _drills = [
  _Drill(level: '초급', name: '기본 그립 연습', description: '포핸드/백핸드 기본 그립을 익히세요.', targetReps: 50, type: 'grip', order: 1,
    guide: '라켓을 악수하듯 가볍게 잡고 포핸드↔백핸드 전환을 반복하세요.',
    correctTip: '손목이 자연스럽게 꺾이는 각도 유지', wrongTip: '라켓을 프라이팬처럼 꽉 쥐기'),
  _Drill(level: '초급', name: '하이 서브 연습', description: '높은 궤도의 서브를 정확하게 넣는 연습.', targetReps: 30, type: 'serve', order: 2,
    guide: '셔틀콕을 허리 아래에서 타격하며, 코트 끝까지 보내세요.',
    correctTip: '팔을 충분히 뻗어 높은 타점 확보', wrongTip: '손목만으로 치기'),
  _Drill(level: '초급', name: '풋워크 기초', description: '6방향 풋워크 기본 이동 패턴 연습.', targetReps: 40, type: 'footwork', order: 3,
    guide: '중앙에서 6방향(전좌, 전우, 좌, 우, 후좌, 후우)으로 이동 후 복귀.',
    correctTip: '항상 중앙으로 빠르게 복귀', wrongTip: '발을 끌며 이동'),
  _Drill(level: '중급', name: '스매시 타이밍', description: '타점과 팔꿈치 스냅 타이밍을 맞추세요.', targetReps: 30, type: 'smash', order: 4,
    guide: '셔틀콕이 최고점에 올 때 팔꿈치를 펴며 스냅을 걸어 타격하세요.',
    correctTip: '몸 앞쪽 최고점에서 임팩트', wrongTip: '셔틀콕이 뒤로 넘어간 후 치기'),
  _Drill(level: '중급', name: '드롭샷 정밀도', description: '네트 근처에 정확히 떨어뜨리는 연습.', targetReps: 25, type: 'drop', order: 5,
    guide: '스매시 모션과 동일하게 시작하되, 임팩트 순간 라켓 속도를 줄이세요.',
    correctTip: '스매시와 같은 준비 동작으로 속이기', wrongTip: '처음부터 느린 동작'),
  _Drill(level: '중급', name: '리시브 반응속도', description: '상대 스매시에 대한 리시브 반응 훈련.', targetReps: 30, type: 'receive', order: 6,
    guide: '무릎을 낮추고 라켓을 앞에 준비, 상대 타격 순간에 집중하세요.',
    correctTip: '무릎을 굽혀 낮은 자세 유지', wrongTip: '서서 팔만 뻗기'),
  _Drill(level: '고급', name: '점프 스매시', description: '점프하면서 최대 파워 스매시 연습.', targetReps: 20, type: 'jumpSmash', order: 7,
    guide: '시저 점프로 공중에서 체중을 실어 최고점에서 스매시하세요.',
    correctTip: '착지 시 왼발(오른손잡이)이 먼저', wrongTip: '점프 없이 제자리에서 치기'),
  _Drill(level: '고급', name: '디셉션 샷', description: '상대를 속이는 페이크 동작 연습.', targetReps: 15, type: 'deception', order: 8,
    guide: '스매시/클리어 동작으로 준비 후 마지막 순간 손목으로 방향 전환.',
    correctTip: '마지막 순간까지 같은 준비 동작', wrongTip: '페이크가 너무 일찍 드러남'),
];

const _exercises = [
  _Exercise(name: '플랭크', description: '코어 안정성 강화', sets: '3세트 × 30초', icon: Symbols.fitness_center, category: 'core'),
  _Exercise(name: '러시안 트위스트', description: '회전력 강화', sets: '3세트 × 20회', icon: Symbols.rotate_right, category: 'core'),
  _Exercise(name: '숄더 프레스', description: '어깨 안정화', sets: '3세트 × 15회', icon: Symbols.arrow_upward, category: 'shoulder'),
  _Exercise(name: '외회전 운동', description: '회전근개 강화', sets: '3세트 × 12회', icon: Symbols.sync, category: 'shoulder'),
  _Exercise(name: '스쿼트', description: '하체 파워 강화', sets: '3세트 × 20회', icon: Symbols.directions_run, category: 'legs'),
  _Exercise(name: '런지', description: '풋워크 근력', sets: '3세트 × 15회 (양쪽)', icon: Symbols.sprint, category: 'legs'),
  _Exercise(name: '카프 레이즈', description: '점프력 향상', sets: '3세트 × 25회', icon: Symbols.arrow_upward, category: 'legs'),
];

const _warmupRoutine = [
  _StretchItem(name: '목 돌리기', duration: '30초', icon: Symbols.self_improvement),
  _StretchItem(name: '팔 돌리기 (앞/뒤)', duration: '30초', icon: Symbols.sync),
  _StretchItem(name: '몸통 회전', duration: '30초', icon: Symbols.rotate_right),
  _StretchItem(name: '무릎 높이 올리기', duration: '30초', icon: Symbols.directions_run),
  _StretchItem(name: '점프 스쿼트', duration: '30초', icon: Symbols.sprint),
  _StretchItem(name: '섀도 스윙', duration: '1분', icon: Symbols.sports_tennis),
];

const _cooldownRoutine = [
  _StretchItem(name: '어깨 스트레칭', duration: '30초 (양쪽)', icon: Symbols.self_improvement),
  _StretchItem(name: '삼두근 스트레칭', duration: '30초 (양쪽)', icon: Symbols.fitness_center),
  _StretchItem(name: '허벅지 스트레칭', duration: '30초 (양쪽)', icon: Symbols.accessibility),
  _StretchItem(name: '종아리 스트레칭', duration: '30초 (양쪽)', icon: Symbols.sprint),
  _StretchItem(name: '엉덩이 스트레칭', duration: '30초 (양쪽)', icon: Symbols.airline_seat_recline_normal),
  _StretchItem(name: '심호흡', duration: '1분', icon: Symbols.air),
];

// ═══════════════════════════════════════════════════════════════════
// Main screen
// ═══════════════════════════════════════════════════════════════════

class TrainingScreen extends ConsumerStatefulWidget {
  const TrainingScreen({super.key});

  @override
  ConsumerState<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends ConsumerState<TrainingScreen> {
  // Timer state
  bool _timerRunning = false;
  int _timerSeconds = 0;
  int _currentSet = 1;
  int _currentReps = 0;
  String? _timerDrillType;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer(String drillType) {
    setState(() {
      _timerRunning = true;
      _timerSeconds = 0;
      _currentSet = 1;
      _currentReps = 0;
      _timerDrillType = drillType;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _timerSeconds++);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    if (_timerDrillType != null && _currentReps > 0) {
      _saveTrainingProgress(_timerDrillType!, _currentReps, _timerSeconds);
    }
    setState(() {
      _timerRunning = false;
      _timerDrillType = null;
    });
  }

  void _addRep() {
    setState(() => _currentReps++);
  }

  void _nextSet() {
    setState(() {
      _currentSet++;
      _currentReps = 0;
    });
  }

  Future<void> _saveTrainingProgress(String drillType, int reps, int duration) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance.collection('trainingProgress').add({
      'userId': uid,
      'date': DateTime.now().toIso8601String(),
      'drillType': drillType,
      'completedReps': reps,
      'duration': duration,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$reps회 완료! (${_formatTime(duration)})'), duration: const Duration(seconds: 2)),
      );
    }
  }

  void _completeDrill(String drillType) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance.collection('trainingProgress').add({
      'userId': uid,
      'date': DateTime.now().toIso8601String(),
      'drillType': drillType,
      'completedReps': 1,
      'duration': 0,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('훈련 1회 완료!'), duration: Duration(seconds: 1)),
      );
    }
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trainingAsync = ref.watch(trainingProgressProvider);
    final latestAnalysis = ref.watch(latestAnalysisProvider);

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

              // ═══ 1. WEEKLY CALENDAR + STREAK ═══
              trainingAsync.when(
                data: (progress) => _buildWeeklyCalendar(context, progress),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 16),

              // ═══ 2. AI CUSTOM RECOMMENDATION ═══
              latestAnalysis.when(
                data: (analysis) => _buildAiRecommendation(context, analysis),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 16),

              // ═══ 4. TIMER/COUNTER (shown when active) ═══
              if (_timerRunning) _buildTimerPanel(context),
              if (_timerRunning) const SizedBox(height: 16),

              // ═══ 3. SMASH ROADMAP (timeline) ═══
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Symbols.route, color: AppTheme.primaryColor, size: 22),
                    const SizedBox(width: 8),
                    const Text('스매시 로드맵', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              trainingAsync.when(
                data: (progress) => _buildRoadmap(context, progress),
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => _buildRoadmap(context, []),
              ),

              const SizedBox(height: 24),

              // ═══ 6. WARMUP / COOLDOWN ═══
              _buildWarmupCooldown(context),

              const SizedBox(height: 24),

              // ═══ 7. CHALLENGE SYSTEM ═══
              trainingAsync.when(
                data: (progress) => _buildChallenges(context, progress),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 24),

              // ═══ 8. PHYSICAL TRAINING ═══
              _buildPhysicalTraining(context),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 1. Weekly Calendar + Streak ──────────────────────────────────
  Widget _buildWeeklyCalendar(BuildContext context, List<Map<String, dynamic>> progress) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    // Get training dates for the week
    final trainedDates = <String>{};
    for (final p in progress) {
      final dateStr = p['date'] as String?;
      if (dateStr == null) continue;
      trainedDates.add(dateStr.substring(0, 10));
    }

    // Calculate streak
    int streak = 0;
    var checkDate = now;
    while (true) {
      final dateStr = checkDate.toIso8601String().substring(0, 10);
      if (trainedDates.contains(dateStr)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else if (checkDate == now) {
        // Today might not have training yet - check yesterday
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    // Build 7-day view (Mon~Sun of current week)
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final dayLabels = ['월', '화', '수', '목', '금', '토', '일'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C222B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
        ),
        child: Column(
          children: [
            // Streak header
            Row(
              children: [
                Icon(Symbols.local_fire_department,
                    color: streak > 0 ? Colors.orange : Colors.grey, size: 24),
                const SizedBox(width: 8),
                Text(
                  streak > 0 ? '$streak일 연속 훈련 중!' : '오늘 훈련을 시작하세요!',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: streak > 0 ? Colors.orange : (isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Day circles
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(7, (i) {
                final day = weekStart.add(Duration(days: i));
                final dateStr = day.toIso8601String().substring(0, 10);
                final isTrained = trainedDates.contains(dateStr);
                final isToday = dateStr == now.toIso8601String().substring(0, 10);

                return Column(
                  children: [
                    Text(
                      dayLabels[i],
                      style: TextStyle(
                        fontSize: 11,
                        color: isToday ? AppTheme.primaryColor : (isDark ? Colors.grey[500] : Colors.grey[600]),
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isTrained
                            ? Colors.green
                            : (isToday
                                ? AppTheme.primaryColor.withOpacity(0.15)
                                : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100)),
                        shape: BoxShape.circle,
                        border: isToday ? Border.all(color: AppTheme.primaryColor, width: 2) : null,
                      ),
                      child: Center(
                        child: isTrained
                            ? const Icon(Icons.check, color: Colors.white, size: 16)
                            : Text(
                                '${day.day}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isToday ? AppTheme.primaryColor : (isDark ? Colors.grey[500] : Colors.grey[600]),
                                ),
                              ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 2. AI Custom Recommendation ──────────────────────────────────
  Widget _buildAiRecommendation(BuildContext context, Map<String, dynamic>? analysis) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String recommendedDrill;
    String reason;
    IconData icon;

    if (analysis == null) {
      recommendedDrill = '기본 그립 연습';
      reason = '아직 분석 데이터가 없습니다. 기본기부터 시작해보세요!';
      icon = Symbols.smart_toy;
    } else {
      final result = analysis['result'] as Map<String, dynamic>? ?? {};
      final elbow = (result['elbowAngle'] ?? 180).toDouble();
      final footwork = (result['footwork'] ?? 100).toDouble();
      final impact = (result['impactAngle'] ?? 90).toDouble();

      if (elbow < 130) {
        recommendedDrill = '스매시 타이밍';
        reason = '팔꿈치 각도(${elbow.toStringAsFixed(0)}°)가 부족합니다. 스냅 타이밍 연습이 필요해요.';
        icon = Symbols.fitness_center;
      } else if (footwork < 60) {
        recommendedDrill = '풋워크 기초';
        reason = '풋워크 점수(${footwork.toStringAsFixed(0)}점)가 낮습니다. 발 움직임을 개선하세요.';
        icon = Symbols.directions_run;
      } else if (impact < 45 || impact > 80) {
        recommendedDrill = '점프 스매시';
        reason = '타점 각도(${impact.toStringAsFixed(0)}°)를 최적화하세요. 높은 타점 연습이 필요합니다.';
        icon = Symbols.bolt;
      } else {
        recommendedDrill = '디셉션 샷';
        reason = '기본기가 탄탄합니다! 고급 기술에 도전해보세요.';
        icon = Symbols.psychology;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.purple.withOpacity(isDark ? 0.2 : 0.08),
              Colors.blue.withOpacity(isDark ? 0.1 : 0.03),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.purple.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.purple, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.purple,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('AI 추천', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          recommendedDrill,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(reason, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[300] : Colors.grey[700]), maxLines: 2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 3. Smash Roadmap (Timeline) ──────────────────────────────────
  Widget _buildRoadmap(BuildContext context, List<Map<String, dynamic>> progress) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Calculate completed reps per drill
    final completedMap = <String, int>{};
    for (final p in progress) {
      final type = p['drillType'] as String?;
      if (type == null) continue;
      completedMap[type] = (completedMap[type] ?? 0) + ((p['completedReps'] as num?)?.toInt() ?? 0);
    }

    // Determine unlocked drills: a drill is unlocked if previous drill is completed
    bool isUnlocked(int order) {
      if (order <= 1) return true;
      final prevDrill = _drills.firstWhere((d) => d.order == order - 1);
      final prevCompleted = completedMap[prevDrill.type] ?? 0;
      return prevCompleted >= prevDrill.targetReps;
    }

    final levelColors = {'초급': Colors.green, '중급': Colors.orange, '고급': Colors.red};

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: _drills.map((drill) {
          final completed = completedMap[drill.type] ?? 0;
          final isComplete = completed >= drill.targetReps;
          final unlocked = isUnlocked(drill.order);
          final isCurrent = unlocked && !isComplete;
          final drillProgress = (completed / drill.targetReps).clamp(0.0, 1.0);
          final color = levelColors[drill.level] ?? Colors.blue;
          final isLast = drill.order == _drills.length;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline line + dot
                SizedBox(
                  width: 40,
                  child: Column(
                    children: [
                      // Dot
                      Container(
                        width: isCurrent ? 28 : 22,
                        height: isCurrent ? 28 : 22,
                        decoration: BoxDecoration(
                          color: isComplete
                              ? color
                              : (isCurrent ? color.withOpacity(0.2) : Colors.grey.withOpacity(0.2)),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isComplete || isCurrent ? color : Colors.grey.shade400,
                            width: isCurrent ? 3 : 2,
                          ),
                        ),
                        child: Center(
                          child: isComplete
                              ? const Icon(Icons.check, color: Colors.white, size: 14)
                              : (unlocked
                                  ? Text('${drill.order}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color))
                                  : Icon(Symbols.lock, size: 10, color: Colors.grey.shade500)),
                        ),
                      ),
                      // Connecting line
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: isComplete ? color.withOpacity(0.5) : Colors.grey.withOpacity(0.2),
                          ),
                        ),
                    ],
                  ),
                ),
                // Card
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: !unlocked
                          ? (isDark ? Colors.grey.shade900 : Colors.grey.shade100)
                          : (isDark ? const Color(0xFF1C222B) : Colors.white),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCurrent
                            ? color.withOpacity(0.5)
                            : (isDark ? Colors.white10 : Colors.grey.shade200),
                        width: isCurrent ? 2 : 1,
                      ),
                    ),
                    child: Opacity(
                      opacity: unlocked ? 1.0 : 0.5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(drill.level, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(drill.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black)),
                              ),
                              if (isComplete)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                                  child: const Text('완료', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(drill.description, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600])),

                          // ─── 5. Drill Guide (inline) ───
                          if (unlocked && isCurrent) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: color.withOpacity(isDark ? 0.1 : 0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Symbols.menu_book, size: 14, color: color),
                                      const SizedBox(width: 4),
                                      Text('가이드', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(drill.guide, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[300] : Colors.grey[700])),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.check_circle_outline, size: 12, color: Colors.green),
                                      const SizedBox(width: 4),
                                      Expanded(child: Text(drill.correctTip, style: const TextStyle(fontSize: 10, color: Colors.green))),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(Icons.cancel_outlined, size: 12, color: Colors.red),
                                      const SizedBox(width: 4),
                                      Expanded(child: Text(drill.wrongTip, style: const TextStyle(fontSize: 10, color: Colors.red))),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],

                          if (unlocked) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: drillProgress,
                                      minHeight: 6,
                                      backgroundColor: color.withOpacity(0.1),
                                      valueColor: AlwaysStoppedAnimation(color),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('$completed/${drill.targetReps}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                              ],
                            ),
                            if (!isComplete) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  // Quick complete button
                                  GestureDetector(
                                    onTap: () => _completeDrill(drill.type),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Symbols.add, size: 14, color: color),
                                          const SizedBox(width: 2),
                                          Text('1회 완료', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Timer button
                                  GestureDetector(
                                    onTap: () => _startTimer(drill.type),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Symbols.timer, size: 14, color: AppTheme.primaryColor),
                                          const SizedBox(width: 2),
                                          Text('타이머', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── 4. Timer/Counter Panel ───────────────────────────────────────
  Widget _buildTimerPanel(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final drillName = _drills.where((d) => d.type == _timerDrillType).firstOrNull?.name ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryColor.withOpacity(isDark ? 0.25 : 0.12),
              AppTheme.primaryColor.withOpacity(isDark ? 0.1 : 0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.4), width: 2),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Symbols.timer, color: AppTheme.primaryColor, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(drillName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black)),
                ),
                GestureDetector(
                  onTap: _stopTimer,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                    child: const Text('종료', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Timer display
            Text(
              _formatTime(_timerSeconds),
              style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: AppTheme.primaryColor, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 12),
            // Set & rep counters
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    Text('세트', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                    Text('$_currentSet', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  children: [
                    Text('반복', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                    Text('$_currentReps', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _addRep,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(child: Text('+1 반복', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _nextSet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.withOpacity(0.4)),
                    ),
                    child: const Text('다음 세트', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── 6. Warmup / Cooldown ─────────────────────────────────────────
  Widget _buildWarmupCooldown(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Symbols.self_improvement, color: Colors.teal, size: 22),
              const SizedBox(width: 8),
              const Text('워밍업 / 쿨다운', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),

          // Warmup
          _buildRoutineCard(context, '워밍업 루틴', '훈련 전 5분', Colors.orange, Symbols.whatshot, _warmupRoutine),
          const SizedBox(height: 10),
          // Cooldown
          _buildRoutineCard(context, '쿨다운 루틴', '훈련 후 5분', Colors.teal, Symbols.ac_unit, _cooldownRoutine),
        ],
      ),
    );
  }

  Widget _buildRoutineCard(BuildContext context, String title, String subtitle, Color color, IconData icon, List<_StretchItem> items) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      collapsedBackgroundColor: isDark ? const Color(0xFF1C222B) : Colors.white,
      backgroundColor: isDark ? const Color(0xFF1C222B) : Colors.white,
      leading: Icon(icon, color: color, size: 22),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      children: items.map((item) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(item.icon, size: 18, color: color.withOpacity(0.7)),
            const SizedBox(width: 10),
            Expanded(child: Text(item.name, style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87))),
            Text(item.duration, style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600)),
          ],
        ),
      )).toList(),
    );
  }

  // ─── 7. Challenge System ──────────────────────────────────────────
  Widget _buildChallenges(BuildContext context, List<Map<String, dynamic>> progress) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    // Weekly stats
    final weeklyProgress = progress.where((p) {
      final dateStr = p['date'] as String?;
      if (dateStr == null) return false;
      final date = DateTime.tryParse(dateStr);
      return date != null && date.isAfter(weekAgo);
    }).toList();

    final weeklyDays = weeklyProgress.map((p) => (p['date'] as String?)?.substring(0, 10)).toSet().length;
    final weeklyReps = weeklyProgress.fold<int>(0, (acc, p) => acc + ((p['completedReps'] as num?)?.toInt() ?? 0));

    // Calculate streak
    final trainedDates = <String>{};
    for (final p in progress) {
      final dateStr = p['date'] as String?;
      if (dateStr == null) continue;
      trainedDates.add(dateStr.substring(0, 10));
    }
    int streak = 0;
    var checkDate = now;
    while (true) {
      final dateStr = checkDate.toIso8601String().substring(0, 10);
      if (trainedDates.contains(dateStr)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else if (checkDate == now) {
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    final challenges = [
      _ChallengeData(
        title: '주간 5일 훈련',
        description: '이번 주 5일 이상 훈련하기',
        current: weeklyDays,
        target: 5,
        xp: 50,
        icon: Symbols.calendar_month,
        color: AppTheme.primaryColor,
      ),
      _ChallengeData(
        title: '반복 100회 달성',
        description: '이번 주 총 100회 이상 훈련',
        current: weeklyReps.clamp(0, 100),
        target: 100,
        xp: 80,
        icon: Symbols.repeat,
        color: Colors.orange,
      ),
      _ChallengeData(
        title: '7일 연속 훈련',
        description: '연속으로 7일 훈련하기',
        current: streak.clamp(0, 7),
        target: 7,
        xp: 100,
        icon: Symbols.local_fire_department,
        color: Colors.red,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Symbols.emoji_events, color: Colors.amber, size: 22),
              const SizedBox(width: 8),
              const Text('주간 챌린지', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ...challenges.map((c) {
            final isCompleted = c.current >= c.target;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isCompleted
                    ? Colors.amber.withOpacity(isDark ? 0.15 : 0.08)
                    : (isDark ? const Color(0xFF1C222B) : Colors.white),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCompleted
                      ? Colors.amber.withOpacity(0.4)
                      : (isDark ? Colors.white10 : Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: c.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(c.icon, color: c.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(c.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('+${c.xp} XP', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(c.description, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: (c.current / c.target).clamp(0.0, 1.0),
                                  minHeight: 5,
                                  backgroundColor: c.color.withOpacity(0.1),
                                  valueColor: AlwaysStoppedAnimation(isCompleted ? Colors.amber : c.color),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isCompleted ? '달성!' : '${c.current}/${c.target}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isCompleted ? Colors.amber : Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── 8. Physical Training ─────────────────────────────────────────
  Widget _buildPhysicalTraining(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categories = [
      ('코어 강화', 'core', Colors.blue, Symbols.fitness_center),
      ('어깨 안정화', 'shoulder', Colors.orange, Symbols.self_improvement),
      ('하체 파워', 'legs', Colors.green, Symbols.directions_run),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Symbols.exercise, color: Colors.indigo, size: 22),
              const SizedBox(width: 8),
              const Text('체력 훈련', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Text('배드민턴에 필요한 근력과 유연성', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          const SizedBox(height: 12),

          ...categories.map((cat) {
            final (catName, catKey, catColor, catIcon) = cat;
            final catExercises = _exercises.where((e) => e.category == catKey).toList();

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C222B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
              ),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                shape: const RoundedRectangleBorder(side: BorderSide.none),
                leading: Icon(catIcon, color: catColor, size: 20),
                title: Text(catName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black)),
                subtitle: Text('${catExercises.length}가지 운동', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                children: catExercises.map((ex) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: catColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(ex.icon, color: catColor, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ex.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black)),
                            Text(ex.description, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                          ],
                        ),
                      ),
                      Text(ex.sets, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: catColor)),
                    ],
                  ),
                )).toList(),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// Helper class for challenge data
class _ChallengeData {
  final String title;
  final String description;
  final int current;
  final int target;
  final int xp;
  final IconData icon;
  final Color color;

  const _ChallengeData({
    required this.title,
    required this.description,
    required this.current,
    required this.target,
    required this.xp,
    required this.icon,
    required this.color,
  });
}
