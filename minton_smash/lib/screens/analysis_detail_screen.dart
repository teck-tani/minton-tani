import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../theme.dart';

class AnalysisDetailScreen extends StatefulWidget {
  final Map<String, dynamic> analysis;

  const AnalysisDetailScreen({super.key, required this.analysis});

  @override
  State<AnalysisDetailScreen> createState() => _AnalysisDetailScreenState();
}

class _AnalysisDetailScreenState extends State<AnalysisDetailScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _videoError = false;

  @override
  void initState() {
    super.initState();
    final annotatedUrl = widget.analysis['annotatedVideoUrl'] as String?;
    if (annotatedUrl != null && annotatedUrl.isNotEmpty) {
      _initializeVideo(annotatedUrl);
    }
  }

  Future<void> _initializeVideo(String url) async {
    try {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
      await _videoController!.initialize();
      if (!mounted) {
        _videoController?.dispose();
        _videoController = null;
        return;
      }
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: false,
        looping: false,
        aspectRatio: _videoController!.value.aspectRatio,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppTheme.primaryColor,
          handleColor: AppTheme.primaryColor,
          backgroundColor: Colors.grey,
          bufferedColor: AppTheme.primaryColor.withOpacity(0.3),
        ),
      );
      setState(() {});
    } catch (e) {
      debugPrint('Video init error: $e');
      if (mounted) setState(() => _videoError = true);
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = widget.analysis['result'] as Map<String, dynamic>? ?? {};
    final coaching = widget.analysis['coaching'] as Map<String, dynamic>? ?? {};
    final createdAt = widget.analysis['createdAt'] as String? ?? '';
    final score = (result['overallScore'] ?? 0).toDouble();
    final annotatedUrl = widget.analysis['annotatedVideoUrl'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('분석 상세'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video Player Section
            _buildVideoSection(isDark, annotatedUrl),
            const SizedBox(height: 20),

            // Date
            Text(_formatDate(createdAt),
                style: TextStyle(fontSize: 13, color: Colors.grey[500])),
            const SizedBox(height: 16),

            // Score
            Row(
              children: [
                _scoreCircle(score, size: 64),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('종합 점수',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[500])),
                    Text('${score.toStringAsFixed(1)}점',
                        style: const TextStyle(
                            fontSize: 28, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Metrics
            Text('세부 지표',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black)),
            const SizedBox(height: 12),
            _detailRow(context, '스매시 속도',
                '${(result['smashSpeed'] ?? 0).toStringAsFixed(1)} km/h'),
            _detailRow(context, '타점 각도',
                '${(result['impactAngle'] ?? 0).toStringAsFixed(1)}°'),
            _detailRow(context, '팔꿈치 각도',
                '${(result['elbowAngle'] ?? 0).toStringAsFixed(1)}°'),
            _detailRow(context, '어깨 각도',
                '${(result['shoulderAngle'] ?? 0).toStringAsFixed(1)}°'),
            _detailRow(context, '손목 스냅 속도',
                '${(result['wristSnapSpeed'] ?? 0).toStringAsFixed(0)}'),
            _detailRow(context, '풋워크',
                '${(result['footwork'] ?? 0).toStringAsFixed(1)}점'),
            _detailRow(context, '힙 회전',
                '${(result['hipRotation'] ?? 0).toStringAsFixed(1)}°'),

            // AI Coaching
            if (coaching['summary'] != null &&
                (coaching['summary'] as String).isNotEmpty) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Symbols.smart_toy,
                      color: AppTheme.primaryColor, size: 22),
                  const SizedBox(width: 8),
                  Text('AI 코칭',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black)),
                ],
              ),
              const SizedBox(height: 8),
              Text(coaching['summary'] as String,
                  style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                      height: 1.6)),
            ],

            // Key Points
            if (coaching['keyPoints'] != null &&
                (coaching['keyPoints'] as List).isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('핵심 포인트',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87)),
              const SizedBox(height: 8),
              ...(coaching['keyPoints'] as List).map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Symbols.check,
                            size: 16, color: AppTheme.primaryColor),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(p.toString(),
                                style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.grey[300]
                                        : Colors.grey[700]))),
                      ],
                    ),
                  )),
            ],

            // Drills
            if (coaching['drills'] != null &&
                (coaching['drills'] as List).isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('추천 훈련',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87)),
              const SizedBox(height: 8),
              ...(coaching['drills'] as List).map((d) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Symbols.fitness_center,
                            size: 16, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(d.toString(),
                              style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.grey[300]
                                      : Colors.grey[700])),
                        ),
                      ],
                    ),
                  )),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoSection(bool isDark, String? annotatedUrl) {
    // Video player ready
    if (_chewieController != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: Chewie(controller: _chewieController!),
        ),
      );
    }

    // Video loading
    if (annotatedUrl != null && annotatedUrl.isNotEmpty && !_videoError) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.black26 : Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    // No annotated video
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.black26 : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Symbols.videocam_off, color: Colors.grey[500], size: 48),
            const SizedBox(height: 8),
            Text(
              _videoError ? '영상을 불러올 수 없습니다' : '포즈 분석 영상 없음',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600])),
          Text(value,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
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
