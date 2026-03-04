import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';

final rankingProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .orderBy('stats.bestSmashSpeed', descending: true)
      .limit(50)
      .snapshots()
      .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
});

class RankingScreen extends ConsumerWidget {
  const RankingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final rankingAsync = ref.watch(rankingProvider);
    final currentUid = ref.watch(authProvider).user?.uid;

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
                  Text('랭킹',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor)),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // Ranking list
            Expanded(
              child: rankingAsync.when(
                data: (users) {
                  if (users.isEmpty) return _buildEmpty(context);
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: users.length,
                    itemBuilder: (ctx, i) =>
                        _buildRankCard(context, users[i], i + 1, currentUid),
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

  Widget _buildEmpty(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Symbols.leaderboard, size: 72, color: Colors.grey[400]),
          const SizedBox(height: 20),
          Text(
            '아직 랭킹 데이터가 없습니다',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '스매시 분석을 완료하면\n랭킹에 등록됩니다!',
            style: TextStyle(fontSize: 14, color: Colors.grey[500], height: 1.6),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRankCard(BuildContext context, Map<String, dynamic> user,
      int rank, String? currentUid) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stats = user['stats'] as Map<String, dynamic>? ?? {};
    final displayName = user['displayName'] as String? ?? '사용자';
    final bestSpeed = (stats['bestSmashSpeed'] ?? 0).toDouble();
    final avgSpeed = (stats['avgSmashSpeed'] ?? 0).toDouble();
    final totalAnalyses = (stats['totalAnalyses'] ?? 0);
    final isMe = user['id'] == currentUid;

    // Medal colors for top 3
    Color? medalColor;
    IconData? medalIcon;
    if (rank == 1) {
      medalColor = const Color(0xFFFFD700);
      medalIcon = Symbols.emoji_events;
    } else if (rank == 2) {
      medalColor = const Color(0xFFC0C0C0);
      medalIcon = Symbols.emoji_events;
    } else if (rank == 3) {
      medalColor = const Color(0xFFCD7F32);
      medalIcon = Symbols.emoji_events;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isMe
            ? AppTheme.primaryColor.withOpacity(isDark ? 0.15 : 0.08)
            : (isDark ? const Color(0xFF1C222B) : Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMe
              ? AppTheme.primaryColor.withOpacity(0.4)
              : (isDark ? Colors.white10 : Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          // Rank number or medal
          SizedBox(
            width: 36,
            child: medalIcon != null
                ? Icon(medalIcon, color: medalColor, size: 28, fill: 1)
                : Text(
                    '$rank',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
          ),
          const SizedBox(width: 10),

          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: AppTheme.primaryColor.withOpacity(0.15),
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name + analyses count
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('나', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                Text(
                  '분석 ${totalAnalyses}회 | 평균 ${avgSpeed.toStringAsFixed(0)} km/h',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),

          // Best speed
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${bestSpeed.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: rank <= 3 ? medalColor : AppTheme.primaryColor,
                ),
              ),
              Text('km/h', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            ],
          ),
        ],
      ),
    );
  }
}
