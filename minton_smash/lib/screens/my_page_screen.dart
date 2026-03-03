import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../providers/auth_provider.dart';
import '../providers/analysis_provider.dart';
import '../theme.dart';

class MyPageScreen extends ConsumerWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final userStats = ref.watch(userStatsProvider);
    final analysesAsync = ref.watch(analysesProvider);

    return SafeArea(
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              // Header
              const Padding(
                padding: EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('마이페이지', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ),
              ),

              // Profile card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C222B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                        backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                        child: user?.photoURL == null
                            ? Icon(Symbols.person, color: AppTheme.primaryColor, size: 36)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.displayName ?? '사용자',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user?.email ?? (user?.isAnonymous == true ? '게스트 모드' : ''),
                              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                            ),
                            const SizedBox(height: 4),
                            _loginMethodBadge(user, isDark),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Stats
              userStats.when(
                data: (stats) => _buildStatsSection(context, stats),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 16),

              // Analysis history
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Icon(Symbols.history, size: 20, color: isDark ? Colors.white70 : Colors.black54),
                      const SizedBox(width: 8),
                      const Text('분석 이력', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              analysesAsync.when(
                data: (analyses) {
                  if (analyses.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text('아직 분석 이력이 없습니다.', style: TextStyle(color: Colors.grey[500])),
                    );
                  }
                  return Column(
                    children: analyses.take(10).map((a) => _buildAnalysisHistoryItem(context, a)).toList(),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
                error: (_, __) => Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('데이터를 불러올 수 없습니다.', style: TextStyle(color: Colors.grey[500])),
                ),
              ),

              const SizedBox(height: 16),

              // Menu items
              _buildMenuItem(context, Symbols.notifications, '알림 설정', () {}),
              _buildMenuItem(context, Symbols.dark_mode, '다크모드', () {}, trailing: Text(isDark ? 'ON' : 'OFF', style: TextStyle(color: Colors.grey[500]))),
              _buildMenuItem(context, Symbols.info, '앱 정보', () {
                showAboutDialog(
                  context: context,
                  applicationName: 'Minton Smash',
                  applicationVersion: '1.0.0',
                  children: [const Text('AI 배드민턴 생체역학 분석 앱')],
                );
              }),

              const SizedBox(height: 16),

              // Logout button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showLogoutDialog(context, ref),
                    icon: const Icon(Symbols.logout, color: Colors.red),
                    label: const Text('로그아웃', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loginMethodBadge(dynamic user, bool isDark) {
    String method = '이메일';
    IconData icon = Symbols.email;
    Color color = AppTheme.primaryColor;

    if (user?.isAnonymous == true) {
      method = '게스트';
      icon = Symbols.person;
      color = Colors.grey;
    } else if (user?.providerData != null) {
      for (final provider in user!.providerData) {
        if (provider.providerId == 'google.com') {
          method = 'Google';
          icon = Symbols.search;
          color = Colors.blue;
          break;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(method, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context, Map<String, dynamic> stats) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C222B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statColumn('총 분석', '${stats['totalAnalyses'] ?? 0}회'),
            Container(width: 1, height: 36, color: Colors.grey.withOpacity(0.3)),
            _statColumn('평균 속도', '${(stats['avgSmashSpeed'] ?? 0).toStringAsFixed(0)} km/h'),
            Container(width: 1, height: 36, color: Colors.grey.withOpacity(0.3)),
            _statColumn('최고 속도', '${(stats['bestSmashSpeed'] ?? 0).toStringAsFixed(0)} km/h'),
          ],
        ),
      ),
    );
  }

  Widget _statColumn(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildAnalysisHistoryItem(BuildContext context, Map<String, dynamic> analysis) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = analysis['status'] ?? 'unknown';
    final result = analysis['result'] as Map<String, dynamic>?;
    final createdAt = analysis['createdAt'] as String? ?? '';
    final dateStr = createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt;

    Color statusColor;
    String statusText;
    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        statusText = '완료';
        break;
      case 'processing':
        statusColor = Colors.orange;
        statusText = '분석중';
        break;
      default:
        statusColor = Colors.red;
        statusText = '실패';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C222B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(Symbols.analytics, color: AppTheme.primaryColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dateStr, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                  if (result != null)
                    Text(
                      '점수: ${(result['overallScore'] ?? 0).toStringAsFixed(0)} | 속도: ${(result['smashSpeed'] ?? 0).toStringAsFixed(0)} km/h',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(statusText, style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String title, VoidCallback onTap, {Widget? trailing}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: ListTile(
        leading: Icon(icon, color: isDark ? Colors.white70 : Colors.black54),
        title: Text(title, style: const TextStyle(fontSize: 15)),
        trailing: trailing ?? Icon(Symbols.arrow_forward_ios, size: 16, color: Colors.grey[400]),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃 하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).signOut();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('로그아웃', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
