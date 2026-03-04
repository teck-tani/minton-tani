import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/analysis_provider.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';

// ─── Level system helpers ───────────────────────────────────────────
class _LevelInfo {
  final String title;
  final String badge;
  final int level;
  final double progress; // 0.0 ~ 1.0 within current level
  final Color color;

  const _LevelInfo({
    required this.title,
    required this.badge,
    required this.level,
    required this.progress,
    required this.color,
  });
}

_LevelInfo _calculateLevel(Map<String, dynamic> stats) {
  final totalAnalyses = (stats['totalAnalyses'] ?? 0) as int;
  final avgScore = (stats['avgSmashSpeed'] ?? 0).toDouble();

  // XP = analyses * 10 + avgScore bonus
  final xp = totalAnalyses * 10 + avgScore.toInt();

  const levels = [
    // (minXP, level, title, badge, color)
    (0,    1,  '스매시 입문자',    'Lv.1',   Color(0xFF8BC34A)),  // light green
    (50,   2,  '스매시 루키',     'Lv.2',   Color(0xFF4CAF50)),  // green
    (120,  3,  '스매시 챌린저',   'Lv.3',   Color(0xFF00BCD4)),  // cyan
    (200,  4,  '스매시 파이터',   'Lv.4',   Color(0xFF2196F3)),  // blue
    (300,  5,  '파워 스트라이커',  'Lv.5',   Color(0xFF3F51B5)),  // indigo
    (420,  6,  '스매시 슬래셔',   'Lv.6',   Color(0xFF9C27B0)),  // purple
    (560,  7,  '에이스 스매셔',   'Lv.7',   Color(0xFFE91E63)),  // pink
    (720,  8,  '엘리트 스트라이커', 'Lv.8',  Color(0xFFFF5722)),  // deep orange
    (900,  9,  '스매시 레전드',   'Lv.9',   Color(0xFFFF9800)),  // orange
    (1100, 10, '스매시 마스터',   'MASTER', Color(0xFFFFD700)),  // gold
  ];

  for (int i = levels.length - 1; i >= 0; i--) {
    final (minXP, lvl, title, badge, color) = levels[i];
    if (xp >= minXP) {
      final nextXP = i < levels.length - 1 ? levels[i + 1].$1 : minXP;
      final progress = i < levels.length - 1
          ? (xp - minXP) / (nextXP - minXP)
          : 1.0;
      return _LevelInfo(
        title: title,
        badge: badge,
        level: lvl,
        progress: progress.clamp(0.0, 1.0),
        color: color,
      );
    }
  }

  return _LevelInfo(
    title: levels[0].$3,
    badge: levels[0].$4,
    level: 1,
    progress: 0.0,
    color: levels[0].$5,
  );
}

// ─── Daily mission helpers ──────────────────────────────────────────
class _MissionInfo {
  final String focus;
  final String description;
  final IconData icon;
  final Color color;

  const _MissionInfo({
    required this.focus,
    required this.description,
    required this.icon,
    required this.color,
  });
}

_MissionInfo _getDailyMission(Map<String, dynamic>? analysis) {
  if (analysis == null) {
    return const _MissionInfo(
      focus: '첫 스매시 촬영',
      description: '카메라 미러에서 스매시 영상을 촬영해 첫 분석을 시작하세요!',
      icon: Symbols.videocam,
      color: AppTheme.primaryColor,
    );
  }

  final result = analysis['result'] as Map<String, dynamic>? ?? {};
  final elbow = (result['elbowAngle'] ?? 180).toDouble();
  final shoulder = (result['shoulderAngle'] ?? 180).toDouble();
  final footwork = (result['footwork'] ?? 100).toDouble();
  final impact = (result['impactAngle'] ?? 90).toDouble();

  // Find weakest area
  final metrics = {
    'elbow': elbow < 140 ? (140 - elbow) : 0.0,
    'shoulder': shoulder < 160 ? (160 - shoulder) : 0.0,
    'footwork': footwork < 70 ? (70 - footwork) : 0.0,
    'impact': impact < 45 ? (45 - impact).abs() : (impact > 90 ? impact - 90 : 0.0),
  };

  final weakest = metrics.entries.reduce((a, b) => a.value > b.value ? a : b);

  switch (weakest.key) {
    case 'elbow':
      return const _MissionInfo(
        focus: '팔꿈치 각도 개선',
        description: '스매시 시 팔꿈치를 140도 이상으로 펴는 연습을 해보세요.',
        icon: Symbols.fitness_center,
        color: Colors.orange,
      );
    case 'shoulder':
      return const _MissionInfo(
        focus: '어깨 회전 강화',
        description: '어깨 회전 범위를 넓히는 스트레칭과 스윙 연습을 해보세요.',
        icon: Symbols.self_improvement,
        color: Colors.purple,
      );
    case 'footwork':
      return const _MissionInfo(
        focus: '풋워크 훈련',
        description: '스매시 전 체중 이동과 발 위치를 의식하며 연습해보세요.',
        icon: Symbols.directions_run,
        color: Colors.teal,
      );
    case 'impact':
      return const _MissionInfo(
        focus: '타점 최적화',
        description: '셔틀콕을 최고점에서 임팩트하는 타이밍 연습을 해보세요.',
        icon: Symbols.target,
        color: Colors.red,
      );
    default:
      return const _MissionInfo(
        focus: '폼 유지 훈련',
        description: '현재 폼을 유지하면서 스매시 파워를 올려보세요!',
        icon: Symbols.trending_up,
        color: AppTheme.primaryColor,
      );
  }
}

// ─── Main screen ────────────────────────────────────────────────────
class BiomechanicsReportScreen extends ConsumerWidget {
  final VoidCallback? onOpenDrawer;

  const BiomechanicsReportScreen({super.key, this.onOpenDrawer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final userName = authState.user?.displayName ?? '사용자';
    final userStats = ref.watch(userStatsProvider);
    final latestAnalysis = ref.watch(latestAnalysisProvider);
    final injuryAlerts = ref.watch(injuryAlertsProvider);
    final analyses = ref.watch(analysesProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ═══ 1. HEADER + LEVEL BADGE ═══
              userStats.when(
                data: (stats) => _buildHeader(context, userName, authState, stats),
                loading: () => _buildHeader(context, userName, authState, {}),
                error: (_, __) => _buildHeader(context, userName, authState, {}),
              ),

              const SizedBox(height: 20),

              // ═══ 2. DAILY MISSION ═══
              latestAnalysis.when(
                data: (analysis) => _buildDailyMission(context, analysis),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => _buildDailyMission(context, null),
              ),

              const SizedBox(height: 20),

              // ═══ 3. STATS CARDS ═══
              userStats.when(
                data: (stats) => _buildStatsRow(context, stats),
                loading: () => _buildStatsRow(context, {}),
                error: (_, __) => _buildStatsRow(context, {}),
              ),

              const SizedBox(height: 20),

              // ═══ 4. GROWTH GRAPH ═══
              analyses.when(
                data: (list) => _buildGrowthGraph(context, list),
                loading: () => _buildLoadingCard(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 20),

              // ═══ 5. LATEST ANALYSIS ═══
              const Text('최근 분석', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              latestAnalysis.when(
                data: (analysis) => analysis != null
                    ? _buildLatestAnalysisCard(context, analysis)
                    : _buildEmptyAnalysisCard(context),
                loading: () => _buildLoadingCard(),
                error: (_, __) => _buildEmptyAnalysisCard(context),
              ),

              const SizedBox(height: 20),

              // ═══ 6. SKILL CATALOG ═══
              _buildSkillCatalog(context),

              const SizedBox(height: 20),

              // ═══ 7. INJURY MONITORING ═══
              Row(
                children: [
                  const Icon(Symbols.health_and_safety, color: Colors.orange, size: 22),
                  const SizedBox(width: 8),
                  const Text('부상 모니터링', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              injuryAlerts.when(
                data: (alerts) => alerts.isEmpty
                    ? _buildHealthyCard(context)
                    : Column(
                        children: alerts.take(3).map((a) => _buildAlertCard(context, a)).toList(),
                      ),
                loading: () => _buildLoadingCard(),
                error: (_, __) => _buildHealthyCard(context),
              ),

              const SizedBox(height: 20),

              // ═══ 8. CTA ═══
              _buildCtaCard(context),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 1. Header with level badge ───────────────────────────────────
  Widget _buildHeader(BuildContext context, String userName, AuthState authState, Map<String, dynamic> stats) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final level = _calculateLevel(stats);

    return Column(
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: onOpenDrawer,
              child: CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                backgroundImage: authState.user?.photoURL != null
                    ? NetworkImage(authState.user!.photoURL!)
                    : null,
                child: authState.user?.photoURL == null
                    ? Icon(Symbols.person, color: AppTheme.primaryColor, size: 28)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '안녕하세요, $userName님',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: level.color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: level.color.withOpacity(0.4)),
                        ),
                        child: Text(
                          level.badge,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: level.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    level.title,
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Symbols.menu, color: isDark ? Colors.white70 : Colors.black54),
              onPressed: onOpenDrawer,
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Level progress bar
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  level.level < 4 ? '다음 레벨까지' : '최고 레벨 달성!',
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[500] : Colors.grey[600]),
                ),
                Text(
                  '${(level.progress * 100).toInt()}%',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: level.color),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: level.progress,
                minHeight: 6,
                backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(level.color),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── 2. Daily Mission ─────────────────────────────────────────────
  Widget _buildDailyMission(BuildContext context, Map<String, dynamic>? analysis) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mission = _getDailyMission(analysis);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            mission.color.withOpacity(isDark ? 0.2 : 0.1),
            mission.color.withOpacity(isDark ? 0.05 : 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: mission.color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: mission.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(mission.icon, color: mission.color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: mission.color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '오늘의 미션',
                        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        mission.focus,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  mission.description,
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[300] : Colors.grey[700]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 3. Stats row ─────────────────────────────────────────────────
  Widget _buildStatsRow(BuildContext context, Map<String, dynamic> stats) {
    return Row(
      children: [
        Expanded(child: _statCard(context, '총 분석', '${stats['totalAnalyses'] ?? 0}', '회', Symbols.analytics, Colors.blue)),
        const SizedBox(width: 10),
        Expanded(child: _statCard(context, '평균 속도', '${(stats['avgSmashSpeed'] ?? 0).toStringAsFixed(0)}', 'km/h', Symbols.speed, Colors.orange)),
        const SizedBox(width: 10),
        Expanded(child: _statCard(context, '최고 속도', '${(stats['bestSmashSpeed'] ?? 0).toStringAsFixed(0)}', 'km/h', Symbols.trophy, Colors.amber)),
      ],
    );
  }

  Widget _statCard(BuildContext context, String title, String value, String unit, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C222B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text('$unit  $title', style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[400] : Colors.grey[600])),
        ],
      ),
    );
  }

  // ─── 4. Growth graph ──────────────────────────────────────────────
  Widget _buildGrowthGraph(BuildContext context, List<Map<String, dynamic>> allAnalyses) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter completed analyses with scores, take recent 10
    final completed = allAnalyses
        .where((a) => a['status'] == 'completed' && a['result'] != null)
        .take(10)
        .toList()
        .reversed
        .toList();

    if (completed.isEmpty) {
      return const SizedBox.shrink();
    }

    // Calculate trend
    String trendText = '';
    if (completed.length >= 2) {
      final latest = ((completed.last['result'] as Map)['overallScore'] ?? 0).toDouble();
      final previous = ((completed[completed.length - 2]['result'] as Map)['overallScore'] ?? 0).toDouble();
      final diff = latest - previous;
      if (diff > 0) {
        trendText = '지난 분석 대비 +${diff.toStringAsFixed(1)}점';
      } else if (diff < 0) {
        trendText = '지난 분석 대비 ${diff.toStringAsFixed(1)}점';
      } else {
        trendText = '지난 분석과 동일';
      }
    }

    final spots = completed.asMap().entries.map((e) {
      final score = ((e.value['result'] as Map)['overallScore'] ?? 0).toDouble();
      return FlSpot(e.key.toDouble(), score);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Symbols.trending_up, color: AppTheme.primaryColor, size: 22),
            const SizedBox(width: 8),
            const Text('스매시 성장 그래프', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        if (trendText.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            trendText,
            style: TextStyle(
              fontSize: 12,
              color: trendText.contains('+') ? Colors.green : (trendText.contains('-') ? Colors.red : Colors.grey),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          height: 180,
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C222B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
          ),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 20,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 20,
                    getTitlesWidget: (value, meta) => Text(
                      '${value.toInt()}',
                      style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= completed.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${value.toInt() + 1}회',
                          style: TextStyle(fontSize: 9, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              minY: 0,
              maxY: 100,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.3,
                  color: AppTheme.primaryColor,
                  barWidth: 3,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) =>
                        FlDotCirclePainter(
                      radius: index == spots.length - 1 ? 5 : 3,
                      color: index == spots.length - 1
                          ? AppTheme.primaryColor
                          : AppTheme.primaryColor.withOpacity(0.6),
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppTheme.primaryColor.withOpacity(0.25),
                        AppTheme.primaryColor.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => isDark ? const Color(0xFF2A3040) : Colors.white,
                  getTooltipItems: (touchedSpots) => touchedSpots
                      .map((s) => LineTooltipItem(
                            '${s.y.toStringAsFixed(1)}점',
                            TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── 5. Latest analysis card ──────────────────────────────────────
  Widget _buildLatestAnalysisCard(BuildContext context, Map<String, dynamic> analysis) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = analysis['result'] as Map<String, dynamic>? ?? {};
    final coaching = analysis['coaching'] as Map<String, dynamic>? ?? {};
    final score = (result['overallScore'] ?? 0).toDouble();
    final speed = (result['smashSpeed'] ?? 0).toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C222B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _scoreCircle(score),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('종합 점수', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                    Text('${score.toStringAsFixed(1)}점', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('스매시 속도', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                  Text('${speed.toStringAsFixed(0)} km/h', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _miniStat('팔꿈치', '${(result['elbowAngle'] ?? 0).toStringAsFixed(0)}°'),
              _miniStat('어깨', '${(result['shoulderAngle'] ?? 0).toStringAsFixed(0)}°'),
              _miniStat('풋워크', '${(result['footwork'] ?? 0).toStringAsFixed(0)}점'),
              _miniStat('타점각도', '${(result['impactAngle'] ?? 0).toStringAsFixed(0)}°'),
            ],
          ),
          if (coaching['summary'] != null && (coaching['summary'] as String).isNotEmpty) ...[
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Symbols.smart_toy, size: 16, color: AppTheme.primaryColor),
                const SizedBox(width: 6),
                Text('AI 코칭', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              coaching['summary'] as String,
              style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _scoreCircle(double score) {
    Color color;
    if (score >= 80) {
      color = Colors.green;
    } else if (score >= 60) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 5,
            backgroundColor: color.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation(color),
          ),
          Center(child: Text('${score.toInt()}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color))),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildEmptyAnalysisCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C222B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Symbols.sports_tennis, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text('아직 분석 데이터가 없습니다', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
          const SizedBox(height: 4),
          Text('카메라 미러에서 스매시 영상을 촬영해보세요!', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ],
      ),
    );
  }

  // ─── 6. Skill Catalog ─────────────────────────────────────────────
  Widget _buildSkillCatalog(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Symbols.sports_tennis, color: AppTheme.primaryColor, size: 22),
            const SizedBox(width: 8),
            const Text('기술 카탈로그', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 130,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _skillCard(
                context,
                name: '스매시',
                icon: Symbols.bolt,
                color: AppTheme.primaryColor,
                isActive: true,
                description: 'AI 분석 가능',
              ),
              _skillCard(
                context,
                name: '드롭샷',
                icon: Symbols.arrow_downward,
                color: Colors.teal,
                isActive: false,
                description: 'Coming Soon',
              ),
              _skillCard(
                context,
                name: '클리어',
                icon: Symbols.arrow_upward,
                color: Colors.orange,
                isActive: false,
                description: 'Coming Soon',
              ),
              _skillCard(
                context,
                name: '서브',
                icon: Symbols.swap_vert,
                color: Colors.purple,
                isActive: false,
                description: 'Coming Soon',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _skillCard(
    BuildContext context, {
    required String name,
    required IconData icon,
    required Color color,
    required bool isActive,
    required String description,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 105,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isActive
            ? color.withOpacity(isDark ? 0.2 : 0.08)
            : (isDark ? const Color(0xFF1C222B) : Colors.grey.shade100),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? color.withOpacity(0.4) : (isDark ? Colors.white10 : Colors.grey.shade300),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                icon,
                color: isActive ? color : Colors.grey,
                size: 32,
              ),
              if (!isActive)
                Icon(Symbols.lock, color: Colors.grey.shade500, size: 16),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isActive
                  ? (isDark ? Colors.white : Colors.black)
                  : Colors.grey,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: TextStyle(
              fontSize: 9,
              color: isActive ? color : Colors.grey,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // ─── 7. Injury alerts ─────────────────────────────────────────────
  Widget _buildAlertCard(BuildContext context, Map<String, dynamic> alert) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final riskLevel = alert['riskLevel'] ?? 'low';
    Color riskColor;
    String riskLabel;
    switch (riskLevel) {
      case 'high':
        riskColor = Colors.red;
        riskLabel = '고위험';
        break;
      case 'medium':
        riskColor = Colors.orange;
        riskLabel = '주의';
        break;
      default:
        riskColor = Colors.green;
        riskLabel = '양호';
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: riskColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: riskColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Symbols.warning, color: riskColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(alert['bodyPart'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: riskColor, borderRadius: BorderRadius.circular(4)),
                      child: Text(riskLabel, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  alert['description'] ?? '',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[300] : Colors.grey[700]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthyCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Symbols.check_circle, color: Colors.green, size: 24),
          const SizedBox(width: 12),
          Text('모든 관절 상태가 정상입니다', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
        ],
      ),
    );
  }

  // ─── 8. CTA card ──────────────────────────────────────────────────
  Widget _buildCtaCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor.withOpacity(0.15), Colors.transparent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
            child: const Icon(Symbols.videocam, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('스매시 분석하기', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black)),
                Text('카메라 미러에서 영상을 촬영하고 AI 분석을 받으세요.', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[300] : Colors.grey[700])),
              ],
            ),
          ),
          const Icon(Symbols.arrow_forward, color: AppTheme.primaryColor),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return const SizedBox(
      height: 100,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
