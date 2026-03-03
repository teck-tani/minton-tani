import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../providers/analysis_provider.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';

class BiomechanicsReportScreen extends ConsumerWidget {
  const BiomechanicsReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final userName = authState.user?.displayName ?? '사용자';
    final userStats = ref.watch(userStatsProvider);
    final latestAnalysis = ref.watch(latestAnalysisProvider);
    final injuryAlerts = ref.watch(injuryAlertsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting header
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                    backgroundImage: authState.user?.photoURL != null
                        ? NetworkImage(authState.user!.photoURL!)
                        : null,
                    child: authState.user?.photoURL == null
                        ? Icon(Symbols.person, color: AppTheme.primaryColor, size: 28)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '안녕하세요, $userName님',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '오늘도 스매시 훈련 파이팅!',
                          style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Symbols.notifications, color: isDark ? Colors.white70 : Colors.black54),
                    onPressed: () {},
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Stats cards
              userStats.when(
                data: (stats) => _buildStatsRow(context, stats),
                loading: () => _buildStatsRow(context, {}),
                error: (_, __) => _buildStatsRow(context, {}),
              ),

              const SizedBox(height: 24),

              // Latest analysis card
              const Text('최근 분석', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              latestAnalysis.when(
                data: (analysis) => analysis != null
                    ? _buildLatestAnalysisCard(context, analysis)
                    : _buildEmptyAnalysisCard(context),
                loading: () => _buildLoadingCard(),
                error: (_, __) => _buildEmptyAnalysisCard(context),
              ),

              const SizedBox(height: 24),

              // Injury monitoring
              Row(
                children: [
                  Icon(Symbols.health_and_safety, color: Colors.orange, size: 22),
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

              const SizedBox(height: 24),

              // Quick action: go to mirror
              Container(
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
                    Icon(Symbols.arrow_forward, color: AppTheme.primaryColor),
                  ],
                ),
              ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

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
          // Key metrics row
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
            Text('AI 코칭', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
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

  Widget _buildLoadingCard() {
    return const SizedBox(
      height: 100,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
