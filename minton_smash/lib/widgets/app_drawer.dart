import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../providers/auth_provider.dart';
import '../providers/analysis_provider.dart';
import '../theme.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final userStats = ref.watch(userStatsProvider);

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Profile header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                    backgroundImage: user?.photoURL != null
                        ? NetworkImage(user!.photoURL!)
                        : null,
                    child: user?.photoURL == null
                        ? Icon(Symbols.person, color: AppTheme.primaryColor, size: 32)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? '사용자',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? (user?.isAnonymous == true ? '게스트 모드' : ''),
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                        const SizedBox(height: 4),
                        _loginMethodBadge(user, isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Divider(color: isDark ? Colors.white10 : Colors.grey.shade200),

            // Stats
            userStats.when(
              data: (stats) => _buildStats(context, stats),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            Divider(color: isDark ? Colors.white10 : Colors.grey.shade200),

            // Menu items
            _buildMenuItem(context, Symbols.notifications, '알림 설정', () {}),
            _buildMenuItem(context, Symbols.dark_mode, '다크모드', () {},
                trailing: Text(isDark ? 'ON' : 'OFF', style: TextStyle(color: Colors.grey[500]))),
            _buildMenuItem(context, Symbols.info, '앱 정보', () {
              showAboutDialog(
                context: context,
                applicationName: 'Minton Smash',
                applicationVersion: '1.0.0',
                children: [const Text('AI 배드민턴 생체역학 분석 앱')],
              );
            }),

            const Spacer(),

            // Logout
            Padding(
              padding: const EdgeInsets.all(16),
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
          ],
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

  Widget _buildStats(BuildContext context, Map<String, dynamic> stats) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statColumn('총 분석', '${stats['totalAnalyses'] ?? 0}회'),
          _statColumn('평균 속도', '${(stats['avgSmashSpeed'] ?? 0).toStringAsFixed(0)}'),
          _statColumn('최고 속도', '${(stats['bestSmashSpeed'] ?? 0).toStringAsFixed(0)}'),
        ],
      ),
    );
  }

  Widget _statColumn(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String title, VoidCallback onTap, {Widget? trailing}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Icon(icon, color: isDark ? Colors.white70 : Colors.black54, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      trailing: trailing ?? Icon(Symbols.arrow_forward_ios, size: 14, color: Colors.grey[400]),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
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
              Navigator.of(context).pop(); // close drawer
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
