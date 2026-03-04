import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../providers/analysis_provider.dart';
import '../theme.dart';
import '../widgets/recording_guide_sheet.dart';
import 'analysis_detail_screen.dart';
import 'smash_recording_screen.dart';

class AnalysisMainScreen extends ConsumerWidget {
  final List<CameraDescription> cameras;

  const AnalysisMainScreen({super.key, required this.cameras});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final filteredAsync = ref.watch(filteredAnalysesProvider);
    final currentSort = ref.watch(analysisSortProvider);
    final currentFilter = ref.watch(analysisFilterProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Text(
                '내 스매시 분석',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),

            // Summary stats
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: _buildSummary(ref, subColor),
            ),

            // Sort & Filter chips
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _sortChip(context, ref, currentSort),
                  const SizedBox(width: 8),
                  _filterChip(context, ref, currentFilter),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Grid
            Expanded(
              child: filteredAsync.when(
                data: (analyses) {
                  if (analyses.isEmpty) {
                    return _buildEmpty(context, textColor, subColor);
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: analyses.length,
                    itemBuilder: (ctx, i) {
                      final analysis = analyses[i];
                      return _buildCard(
                        context,
                        analysis,
                        isDark,
                        textColor,
                        subColor,
                        key: ValueKey(analysis['id'] ?? i),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => _buildEmpty(context, textColor, subColor),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _onRecordTap(context),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Symbols.videocam),
        label: const Text('촬영하기', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildSummary(WidgetRef ref, Color subColor) {
    final analysesAsync = ref.watch(analysesProvider);
    return analysesAsync.when(
      data: (analyses) {
        final total = analyses.length;
        final completed = analyses.where((a) => a['status'] == 'completed').toList();
        double avgScore = 0;
        if (completed.isNotEmpty) {
          final sum = completed.fold<double>(0, (acc, a) {
            return acc + ((a['result'] as Map<String, dynamic>?)?['overallScore'] ?? 0).toDouble();
          });
          avgScore = sum / completed.length;
        }
        return Text(
          '총 $total회 촬영 · 평균 ${avgScore.toStringAsFixed(0)}점',
          style: TextStyle(fontSize: 14, color: subColor),
        );
      },
      loading: () => Text('불러오는 중...', style: TextStyle(fontSize: 14, color: subColor)),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _sortChip(BuildContext context, WidgetRef ref, AnalysisSortOption current) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labels = {
      AnalysisSortOption.newestFirst: '최신순',
      AnalysisSortOption.oldestFirst: '오래된순',
      AnalysisSortOption.scoreHigh: '점수 높은순',
      AnalysisSortOption.scoreLow: '점수 낮은순',
    };

    return PopupMenuButton<AnalysisSortOption>(
      onSelected: (v) => ref.read(analysisSortProvider.notifier).state = v,
      itemBuilder: (_) => labels.entries
          .map((e) => PopupMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      child: Chip(
        avatar: Icon(Symbols.sort, size: 16, color: AppTheme.primaryColor),
        label: Text(labels[current]!, style: const TextStyle(fontSize: 12)),
        backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
        side: BorderSide(color: isDark ? Colors.white24 : Colors.grey[300]!),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  Widget _filterChip(BuildContext context, WidgetRef ref, AnalysisFilterOption current) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labels = {
      AnalysisFilterOption.all: '전체',
      AnalysisFilterOption.completed: '완료',
      AnalysisFilterOption.processing: '분석중',
      AnalysisFilterOption.failed: '실패',
    };

    return PopupMenuButton<AnalysisFilterOption>(
      onSelected: (v) => ref.read(analysisFilterProvider.notifier).state = v,
      itemBuilder: (_) => labels.entries
          .map((e) => PopupMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      child: Chip(
        avatar: Icon(Symbols.filter_list, size: 16, color: AppTheme.primaryColor),
        label: Text(labels[current]!, style: const TextStyle(fontSize: 12)),
        backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
        side: BorderSide(color: isDark ? Colors.white24 : Colors.grey[300]!),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    Map<String, dynamic> analysis,
    bool isDark,
    Color textColor,
    Color subColor, {
    Key? key,
  }) {
    final status = analysis['status'] ?? 'processing';
    final result = analysis['result'] as Map<String, dynamic>? ?? {};
    final createdAt = analysis['createdAt'] as String? ?? '';
    final score = (result['overallScore'] ?? 0).toDouble();

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        statusLabel = '완료';
        break;
      case 'failed':
        statusColor = Colors.red;
        statusLabel = '실패';
        break;
      default:
        statusColor = AppTheme.primaryColor;
        statusLabel = '분석중';
    }

    return GestureDetector(
      key: key,
      onTap: status == 'completed'
          ? () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AnalysisDetailScreen(analysis: analysis)),
              )
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C222B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail placeholder
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : Colors.grey[200],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Center(
                  child: status == 'processing'
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('분석중...', style: TextStyle(fontSize: 11, color: subColor)),
                          ],
                        )
                      : status == 'completed'
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Score display
                                _scoreCircle(score, size: 48),
                                const SizedBox(height: 6),
                                Text(
                                  '${score.toStringAsFixed(0)}점',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                              ],
                            )
                          : Icon(Symbols.error, color: Colors.red[300], size: 32),
                ),
              ),
            ),

            // Bottom info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date
                  Text(
                    _formatDate(createdAt),
                    style: TextStyle(fontSize: 11, color: subColor),
                  ),
                  const SizedBox(height: 4),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
            strokeWidth: 3,
            backgroundColor: color.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation(color),
          ),
          Center(
            child: Text(
              '${score.toInt()}',
              style: TextStyle(
                fontSize: size * 0.32,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, Color textColor, Color subColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Symbols.sports_tennis, size: 72, color: Colors.grey[400]),
            const SizedBox(height: 20),
            Text(
              '첫 스매시를 촬영해보세요!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '아래 촬영하기 버튼을 눌러\n스매시 영상을 분석해보세요',
              style: TextStyle(fontSize: 14, color: subColor, height: 1.6),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _onRecordTap(BuildContext context) async {
    final result = await showRecordingGuideSheet(context);
    if (result == true && context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SmashRecordingScreen(cameras: cameras),
        ),
      );
    }
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

      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }
}
