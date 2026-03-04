import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color primaryColor = AppTheme.primaryColor;
    Color inactiveColor = isDark ? Colors.grey[500]! : Colors.grey[500]!;

    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return
      Container(
        height: 70 + bottomPadding,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.backgroundDark.withOpacity(0.9) : Colors.white.withOpacity(0.9),
          border: Border(top: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!)),
        ),
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildItem(icon: Symbols.home, label: '홈', index: 0, isActive: currentIndex == 0, color: inactiveColor, activeColor: primaryColor),
              _buildItem(icon: Symbols.fitness_center, label: '훈련', index: 1, isActive: currentIndex == 1, color: inactiveColor, activeColor: primaryColor),

              // Middle elevated 'Analysis' button
              GestureDetector(
                onTap: () => onTap(2),
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        top: -20,
                        left: 0,
                        right: 0,
                        child: Column(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: primaryColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: isDark ? AppTheme.backgroundDark : Colors.white, width: 4),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryColor.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(Symbols.videocam, color: Colors.white, size: 28),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '분석',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              _buildItem(icon: Symbols.smart_toy, label: 'AI코치', index: 3, isActive: currentIndex == 3, color: inactiveColor, activeColor: primaryColor),
              _buildItem(icon: Symbols.leaderboard, label: '랭킹', index: 4, isActive: currentIndex == 4, color: inactiveColor, activeColor: primaryColor),
            ],
          ),
      );
  }

  Widget _buildItem({
    required IconData icon,
    required String label,
    required int index,
    required bool isActive,
    required Color color,
    required Color activeColor,
  }) {
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? activeColor : color,
            size: 24,
            fill: isActive ? 1.0 : 0.0,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isActive ? activeColor : color,
            ),
          ),
        ],
      ),
    );
  }
}
