import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../providers/analysis_provider.dart';
import '../theme.dart';

class InjuryPreventionScreen extends ConsumerWidget {
  const InjuryPreventionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final alertsAsync = ref.watch(injuryAlertsProvider);

    return SafeArea(
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // AppBar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 48),
                    Text('부상 방지 알림', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                    IconButton(icon: Icon(Symbols.help, color: textColor), onPressed: () {}),
                  ],
                ),
              ),

              // Content
              alertsAsync.when(
                data: (alerts) {
                  if (alerts.isEmpty) return _buildNoAlerts(context);
                  return Column(
                    children: [
                      // Main alert card (first, highest priority)
                      _buildMainAlertCard(context, alerts.first),
                      const SizedBox(height: 16),

                      // Exercises for the alert
                      _buildExercisesSection(context, alerts.first),
                      const SizedBox(height: 16),

                      // Other alerts
                      if (alerts.length > 1) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Icon(Symbols.list, color: textColor, size: 20),
                              const SizedBox(width: 8),
                              Text('기타 알림', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...alerts.skip(1).map((a) => _buildSecondaryAlertCard(context, a)),
                      ],

                      // Pro tip
                      _buildProTip(context, isDark),
                      const SizedBox(height: 40),
                    ],
                  );
                },
                loading: () => const SizedBox(height: 300, child: Center(child: CircularProgressIndicator())),
                error: (_, __) => _buildNoAlerts(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoAlerts(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const SizedBox(height: 60),
          Icon(Symbols.health_and_safety, size: 72, color: Colors.green[400]),
          const SizedBox(height: 20),
          Text(
            '모든 관절 상태가 정상입니다!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '부상 위험이 감지되지 않았습니다.\n스매시 분석을 진행하면 실시간으로\n관절 건강 상태를 모니터링합니다.',
            style: TextStyle(fontSize: 14, color: Colors.grey[500], height: 1.6),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
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
                Expanded(
                  child: Text('꾸준한 스트레칭과 준비운동으로\n부상을 예방하세요!',
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[300] : Colors.grey[700])),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainAlertCard(BuildContext context, Map<String, dynamic> alert) {
    final riskLevel = alert['riskLevel'] ?? 'low';
    Color riskColor;
    String riskLabel;
    switch (riskLevel) {
      case 'high':
        riskColor = Colors.red;
        riskLabel = '고위험 감지';
        break;
      case 'medium':
        riskColor = Colors.orange;
        riskLabel = '주의 필요';
        break;
      default:
        riskColor = Colors.green;
        riskLabel = '양호';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: riskColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: riskColor.withOpacity(0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Risk badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: riskColor, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Symbols.warning, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(riskLabel, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                alert['bodyPart'] ?? '관절',
                style: TextStyle(color: riskColor, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                alert['description'] ?? '',
                style: TextStyle(color: Colors.grey[400], fontSize: 14, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExercisesSection(BuildContext context, Map<String, dynamic> alert) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final exercises = (alert['exercises'] as List<dynamic>?) ?? [];

    if (exercises.isEmpty) return const SizedBox.shrink();

    final exerciseIcons = [Symbols.fitness_center, Symbols.self_improvement, Symbols.directions_run];
    final exerciseBadges = ['유연성', '근력 강화', '밸런스'];
    final exerciseColors = [AppTheme.primaryColor, Colors.orange, Colors.green];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Symbols.medical_services, color: Colors.orange, size: 24),
              const SizedBox(width: 8),
              Text('교정 운동', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
            ],
          ),
          const SizedBox(height: 4),
          Text('관절을 안정시키기 위해 다음 훈련을 수행하세요.', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
          const SizedBox(height: 12),
          ...exercises.asMap().entries.map((entry) {
            final idx = entry.key;
            final name = entry.value.toString();
            final badgeIdx = idx % exerciseBadges.length;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C222B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: exerciseColors[badgeIdx].withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(exerciseIcons[badgeIdx], color: exerciseColors[badgeIdx], size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: exerciseColors[badgeIdx].withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(exerciseBadges[badgeIdx], style: TextStyle(color: exerciseColors[badgeIdx], fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 4),
                          Text(name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                        ],
                      ),
                    ),
                    Icon(Symbols.arrow_forward_ios, size: 16, color: Colors.grey[400]),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSecondaryAlertCard(BuildContext context, Map<String, dynamic> alert) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final riskLevel = alert['riskLevel'] ?? 'low';
    final riskColor = riskLevel == 'high' ? Colors.red : (riskLevel == 'medium' ? Colors.orange : Colors.green);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C222B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: riskColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Symbols.warning, color: riskColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(alert['bodyPart'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black)),
                  const SizedBox(height: 2),
                  Text(alert['description'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[500]), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProTip(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
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
                  Text('프로 팁', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    '운동 전 충분한 워밍업과 스트레칭으로 부상을 예방하세요. 통증이 느껴지면 즉시 운동을 중단하고 전문의 상담을 받으세요.',
                    style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 12, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
