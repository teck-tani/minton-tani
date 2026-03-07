import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';
import 'analysis_provider.dart';

// --- Chat Message Model ---

class ChatMessage {
  final String text;
  final bool isUser;
  final bool isLoading;
  final DateTime timestamp;

  const ChatMessage({
    required this.text,
    this.isUser = false,
    this.isLoading = false,
    required this.timestamp,
  });
}

// --- Chat Messages State ---

class CoachMessagesNotifier extends StateNotifier<List<ChatMessage>> {
  CoachMessagesNotifier() : super([]);

  String? _conversationId;
  String? get conversationId => _conversationId;

  void addUserMessage(String text) {
    state = [
      ...state,
      ChatMessage(text: text, isUser: true, timestamp: DateTime.now()),
    ];
  }

  void addLoadingMessage() {
    state = [
      ...state,
      ChatMessage(text: '', isLoading: true, timestamp: DateTime.now()),
    ];
  }

  void replaceLoadingWithResponse(String text, {String? conversationId}) {
    if (conversationId != null) _conversationId = conversationId;
    final updated = state.where((m) => !m.isLoading).toList();
    updated.add(ChatMessage(text: text, timestamp: DateTime.now()));
    state = updated;
  }

  void clear() {
    _conversationId = null;
    state = [];
  }
}

final coachMessagesProvider =
    StateNotifierProvider<CoachMessagesNotifier, List<ChatMessage>>(
  (ref) => CoachMessagesNotifier(),
);

// --- Coach Insights (derived from existing analysis data) ---

class CoachInsights {
  final bool hasData;
  final String? weaknessInsight;
  final List<String> recommendedDrills;
  final String? trendSummary;
  final double? latestScore;

  const CoachInsights({
    this.hasData = false,
    this.weaknessInsight,
    this.recommendedDrills = const [],
    this.trendSummary,
    this.latestScore,
  });
}

final coachInsightsProvider = Provider<CoachInsights>((ref) {
  final latestAsync = ref.watch(latestAnalysisProvider);
  final analysesAsync = ref.watch(analysesProvider);

  return latestAsync.when(
    data: (latest) {
      if (latest == null) return const CoachInsights();

      final result = latest['result'] as Map<String, dynamic>? ?? {};
      final coaching = latest['coaching'] as Map<String, dynamic>? ?? {};

      // Find weakest metric
      final metrics = {
        '팔꿈치 각도': {'value': result['elbowAngle'] ?? 0, 'ideal': 160},
        '어깨 각도': {'value': result['shoulderAngle'] ?? 0, 'ideal': 170},
        '풋워크': {'value': result['footwork'] ?? 0, 'ideal': 85},
        '골반 회전': {'value': result['hipRotation'] ?? 0, 'ideal': 45},
      };

      String? weakness;
      double worstGap = 0;
      metrics.forEach((name, data) {
        final value = (data['value'] as num).toDouble();
        final ideal = (data['ideal'] as num).toDouble();
        final gap = (ideal - value).abs() / ideal;
        if (gap > worstGap) {
          worstGap = gap;
          weakness = '$name ${value.toStringAsFixed(0)}° (권장 ${ideal.toStringAsFixed(0)}°)';
        }
      });

      // Drills from coaching data
      final drills = (coaching['drills'] as List<dynamic>?)
              ?.map((d) => d.toString())
              .toList() ??
          [];

      // Score trend from analyses list
      String? trend;
      final analysesList = analysesAsync.valueOrNull;
      if (analysesList != null) {
        final completed = analysesList
            .where((a) => a['status'] == 'completed')
            .take(5)
            .toList();
        if (completed.length >= 2) {
          final scores = completed
              .map((a) =>
                  ((a['result'] as Map<String, dynamic>?)?['overallScore'] ?? 0)
                      .toDouble())
              .toList();
          final diff = scores.first - scores.last;
          if (diff > 0) {
            trend = '최근 ${completed.length}회 분석 기준 +${diff.toStringAsFixed(1)}점 상승';
          } else if (diff < 0) {
            trend = '최근 ${completed.length}회 분석 기준 ${diff.toStringAsFixed(1)}점 하락';
          } else {
            trend = '최근 ${completed.length}회 분석 기준 점수 유지 중';
          }
        }
      }

      return CoachInsights(
        hasData: true,
        weaknessInsight: weakness != null ? '개선 필요: $weakness' : null,
        recommendedDrills: drills,
        trendSummary: trend,
        latestScore: (result['overallScore'] as num?)?.toDouble(),
      );
    },
    loading: () => const CoachInsights(),
    error: (_, __) => const CoachInsights(),
  );
});

// --- Send Message Action ---

final sendCoachMessageProvider = Provider<Future<void> Function(String)>((ref) {
  return (String message) async {
    final notifier = ref.read(coachMessagesProvider.notifier);
    final authState = ref.read(authProvider);
    final uid = authState.user?.uid;

    if (uid == null) return;

    notifier.addUserMessage(message);
    notifier.addLoadingMessage();

    try {
      final result = await ApiService().sendCoachMessage(
        userId: uid,
        message: message,
        conversationId: notifier.conversationId,
      );
      notifier.replaceLoadingWithResponse(
        result['response'] as String,
        conversationId: result['conversation_id'] as String?,
      );
    } catch (e) {
      debugPrint('Coach message error: $e');
      notifier.replaceLoadingWithResponse(
        '죄송합니다. 응답을 가져오지 못했습니다. 다시 시도해주세요.',
      );
    }
  };
});
