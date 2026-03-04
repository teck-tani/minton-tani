import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../providers/analysis_provider.dart';
import '../theme.dart';
import 'analysis_detail_screen.dart';

class AnalysisHistoryScreen extends ConsumerWidget {
  const AnalysisHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final analysesAsync = ref.watch(analysesProvider);
    final samplesAsync = ref.watch(sampleAnalysesProvider);

    return SafeArea(
      child: Scaffold(
        body: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 48),
                  Text('분석 기록',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor)),
                  IconButton(
                      icon: Icon(Symbols.filter_list, color: textColor),
                      onPressed: () {}),
                ],
              ),
            ),

            // List
            Expanded(
              child: analysesAsync.when(
                data: (analyses) {
                  final samples = samplesAsync.valueOrNull ?? [];
                  if (analyses.isEmpty && samples.isEmpty) return _buildEmpty(context);
                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      // Pro sample analyses at the top
                      ...samples.map((s) => _buildSampleCard(context, s)),
                      // User's own analyses
                      ...analyses.map((a) => _buildAnalysisCard(context, a)),
                    ],
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) => _buildEmpty(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSampleCard(BuildContext context, Map<String, dynamic> sample) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = sample['result'] as Map<String, dynamic>? ?? {};
    final playerName = sample['playerName'] ?? 'Pro Player';
    final playerInfo = sample['playerInfo'] ?? '';
    final score = (result['overallScore'] ?? 0).toDouble();
    final speed = (result['smashSpeed'] ?? 0).toDouble();

    return GestureDetector(
      onTap: () => _showDetail(context, sample),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1A2A4A), const Color(0xFF1C222B)]
                : [const Color(0xFFE8F0FE), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            // Pro badge header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              ),
              child: Row(
                children: [
                  Icon(Symbols.star, color: Colors.amber, size: 18, fill: 1),
                  const SizedBox(width: 6),
                  Text('프로 선수 레퍼런스',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor)),
                  const Spacer(),
                  Text('탭하여 상세 보기',
                      style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                  const SizedBox(width: 4),
                  Icon(Symbols.arrow_forward, size: 14, color: Colors.grey[500]),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Player info row
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppTheme.primaryColor,
                        child: const Icon(Symbols.person, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(playerName,
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black)),
                            if (playerInfo.isNotEmpty)
                              Text(playerInfo,
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey[500])),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Score + speed
                  Row(
                    children: [
                      _scoreCircle(score),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('종합 점수',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600])),
                            Text('${score.toStringAsFixed(1)}점',
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('스매시 속도',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600])),
                          Text('${speed.toStringAsFixed(0)} km/h',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Metrics
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _miniStat('팔꿈치', '${(result['elbowAngle'] ?? 0).toStringAsFixed(0)}°'),
                      _miniStat('어깨', '${(result['shoulderAngle'] ?? 0).toStringAsFixed(0)}°'),
                      _miniStat('풋워크', '${(result['footwork'] ?? 0).toStringAsFixed(0)}점'),
                      _miniStat('타점', '${(result['impactAngle'] ?? 0).toStringAsFixed(0)}°'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Symbols.sports_tennis, size: 72, color: Colors.grey[400]),
          const SizedBox(height: 20),
          Text(
            '아직 분석 기록이 없습니다',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '카메라 미러에서 스매시 영상을 촬영하고\nAI 분석을 받아보세요!',
            style:
                TextStyle(fontSize: 14, color: Colors.grey[500], height: 1.6),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisCard(
      BuildContext context, Map<String, dynamic> analysis) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = analysis['status'] ?? 'processing';
    final result = analysis['result'] as Map<String, dynamic>? ?? {};
    final createdAt = analysis['createdAt'] as String? ?? '';

    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        statusLabel = '완료';
        statusIcon = Symbols.check_circle;
        break;
      case 'failed':
        statusColor = Colors.red;
        statusLabel = '실패';
        statusIcon = Symbols.error;
        break;
      default:
        statusColor = AppTheme.primaryColor;
        statusLabel = '분석중';
        statusIcon = Symbols.hourglass_top;
    }

    final score = (result['overallScore'] ?? 0).toDouble();
    final speed = (result['smashSpeed'] ?? 0).toDouble();

    return GestureDetector(
      onTap: status == 'completed'
          ? () => _showDetail(context, analysis)
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C222B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey.shade200),
        ),
        child: Column(
          children: [
            // Top row: date + status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDate(createdAt),
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[500])),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(statusLabel,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: statusColor)),
                    ],
                  ),
                ),
              ],
            ),

            if (status == 'completed') ...[
              const SizedBox(height: 12),
              // Score + speed row
              Row(
                children: [
                  _scoreCircle(score),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('종합 점수',
                            style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600])),
                        Text('${score.toStringAsFixed(1)}점',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('스매시 속도',
                          style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600])),
                      Text('${speed.toStringAsFixed(0)} km/h',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Metrics row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _miniStat('팔꿈치',
                      '${(result['elbowAngle'] ?? 0).toStringAsFixed(0)}°'),
                  _miniStat('어깨',
                      '${(result['shoulderAngle'] ?? 0).toStringAsFixed(0)}°'),
                  _miniStat('풋워크',
                      '${(result['footwork'] ?? 0).toStringAsFixed(0)}점'),
                  _miniStat('타점',
                      '${(result['impactAngle'] ?? 0).toStringAsFixed(0)}°'),
                ],
              ),
            ],

            if (status == 'processing') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.primaryColor)),
                  const SizedBox(width: 10),
                  Text('AI가 영상을 분석하고 있습니다...',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey[500])),
                ],
              ),
            ],

            if (status == 'failed') ...[
              const SizedBox(height: 12),
              Text('분석에 실패했습니다. 다시 시도해주세요.',
                  style: TextStyle(fontSize: 13, color: Colors.red[300])),
            ],
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, Map<String, dynamic> analysis) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnalysisDetailScreen(analysis: analysis),
      ),
    );
  }

  Widget _scoreCircle(double score, {double size = 48}) {
    Color color;
    if (score >= 80) {
      color = Colors.green;
    } else if (score >= 60) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 4,
            backgroundColor: color.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation(color),
          ),
          Center(
              child: Text('${score.toInt()}',
                  style: TextStyle(
                      fontSize: size * 0.35,
                      fontWeight: FontWeight.bold,
                      color: color))),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      children: [
        Text(value,
            style:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(fontSize: 10, color: Colors.grey[500])),
      ],
    );
  }

  String _formatDate(String isoDate) {
    if (isoDate.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoDate);
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return '방금 전';
      if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
      if (diff.inHours < 24) return '${diff.inHours}시간 전';
      if (diff.inDays < 7) return '${diff.inDays}일 전';

      return '${dt.month}월 ${dt.day}일 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }
}
