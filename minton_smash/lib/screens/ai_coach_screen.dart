import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../providers/coach_provider.dart';
import '../providers/analysis_provider.dart';
import '../theme.dart';

class AICoachScreen extends ConsumerStatefulWidget {
  final VoidCallback? onNavigateToCamera;
  const AICoachScreen({super.key, this.onNavigateToCamera});

  @override
  ConsumerState<AICoachScreen> createState() => _AICoachScreenState();
}

class _AICoachScreenState extends ConsumerState<AICoachScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    _textController.clear();
    final send = ref.read(sendCoachMessageProvider);
    send(text.trim());
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final insights = ref.watch(coachInsightsProvider);
    final messages = ref.watch(coachMessagesProvider);
    final latestAsync = ref.watch(latestAnalysisProvider);

    // Auto-scroll when messages change
    if (messages.isNotEmpty) {
      _scrollToBottom();
    }

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
                  Text('AI 코치',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor)),
                  // Clear chat button
                  messages.isEmpty
                      ? const SizedBox(width: 48)
                      : IconButton(
                          onPressed: () =>
                              ref.read(coachMessagesProvider.notifier).clear(),
                          icon: Icon(Symbols.delete_sweep,
                              color: Colors.grey[500], size: 22),
                          tooltip: '대화 초기화',
                        ),
                ],
              ),
            ),

            // Main content
            Expanded(
              child: latestAsync.when(
                data: (analysis) => analysis == null
                    ? _buildEmptyState(context, isDark)
                    : _buildMainContent(
                        context, isDark, insights, messages, textColor),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) => _buildEmptyState(context, isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Empty state: no analysis data ---
  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Symbols.smart_toy,
                  size: 56, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 24),
            Text(
              'AI 코치를 시작하려면\n영상을 먼저 분석해주세요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '분석 데이터를 기반으로 맞춤형 코칭을 제공합니다',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: widget.onNavigateToCamera,
              icon: const Icon(Symbols.videocam, size: 20),
              label: const Text('영상 분석하러 가기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Main content: insights + chat ---
  Widget _buildMainContent(BuildContext context, bool isDark,
      CoachInsights insights, List<ChatMessage> messages, Color textColor) {
    return Column(
      children: [
        // Insight cards (collapsible when chatting)
        if (messages.isEmpty) ...[
          _buildInsightCards(isDark, insights),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
                height: 1),
          ),
          const SizedBox(height: 12),
          _buildSuggestionChips(isDark),
          const SizedBox(height: 12),
        ],

        // Chat messages
        Expanded(
          child: messages.isEmpty
              ? Center(
                  child: Text(
                    '코치에게 질문해보세요!',
                    style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (ctx, i) =>
                      _buildChatBubble(ctx, messages[i], isDark),
                ),
        ),

        // Chat input
        _buildChatInput(isDark),
      ],
    );
  }

  // --- Insight cards ---
  Widget _buildInsightCards(bool isDark, CoachInsights insights) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        children: [
          if (insights.weaknessInsight != null)
            _insightCard(
              isDark: isDark,
              icon: Symbols.lightbulb,
              color: Colors.amber,
              title: '이번 주 인사이트',
              body: insights.weaknessInsight!,
            ),
          if (insights.recommendedDrills.isNotEmpty)
            _insightCard(
              isDark: isDark,
              icon: Symbols.fitness_center,
              color: Colors.deepOrange,
              title: '추천 훈련',
              body: insights.recommendedDrills.join(', '),
            ),
          if (insights.trendSummary != null)
            _insightCard(
              isDark: isDark,
              icon: Symbols.trending_up,
              color: AppTheme.primaryColor,
              title: '진행 추세',
              body: insights.trendSummary!,
            ),
        ],
      ),
    );
  }

  Widget _insightCard({
    required bool isDark,
    required IconData icon,
    required Color color,
    required String title,
    required String body,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C222B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(body,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Suggestion chips ---
  Widget _buildSuggestionChips(bool isDark) {
    final suggestions = [
      '스매시 파워 올리려면?',
      '자세 교정법',
      '부상 예방 팁',
      '풋워크 개선',
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) => ActionChip(
          label: Text(suggestions[i],
              style: const TextStyle(fontSize: 12)),
          backgroundColor:
              isDark ? const Color(0xFF1C222B) : Colors.grey.shade100,
          side: BorderSide(
              color: isDark ? Colors.white10 : Colors.grey.shade300),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          onPressed: () => _sendMessage(suggestions[i]),
        ),
      ),
    );
  }

  // --- Chat bubbles ---
  Widget _buildChatBubble(
      BuildContext context, ChatMessage message, bool isDark) {
    if (message.isLoading) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _coachAvatar(),
            const SizedBox(width: 8),
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C222B) : Colors.grey.shade100,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.primaryColor),
              ),
            ),
          ],
        ),
      );
    }

    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(message.text,
              style: const TextStyle(color: Colors.white, fontSize: 14)),
        ),
      );
    }

    // AI response
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _coachAvatar(),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              margin: const EdgeInsets.only(bottom: 8, right: 48),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF1C222B) : Colors.grey.shade100,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Text(message.text,
                  style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _coachAvatar() {
    return CircleAvatar(
      radius: 16,
      backgroundColor: AppTheme.primaryColor.withOpacity(0.15),
      child:
          const Icon(Symbols.smart_toy, size: 18, color: AppTheme.primaryColor),
    );
  }

  // --- Chat input ---
  Widget _buildChatInput(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C222B) : Colors.white,
        border:
            Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                textInputAction: TextInputAction.send,
                onSubmitted: _sendMessage,
                decoration: InputDecoration(
                  hintText: '코치에게 질문해보세요...',
                  hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                        color: isDark ? Colors.white10 : Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                        color: isDark ? Colors.white10 : Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide:
                        const BorderSide(color: AppTheme.primaryColor),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: () => _sendMessage(_textController.text),
              icon: const Icon(Symbols.send, color: AppTheme.primaryColor),
              tooltip: '전송',
            ),
          ],
        ),
      ),
    );
  }
}
