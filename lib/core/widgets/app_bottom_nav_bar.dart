// 📄 ไฟล์นี้ทำหน้าที่: widget แถบนำทางด้านล่าง (bottom navigation) มาตรฐาน
// ใช้ร่วมกันทั้งฝั่งสมาชิก (MainScreen) และเจ้าของหอ (OwnerMainScreen)
import 'package:flutter/material.dart';

/// แถบนำทางด้านล่างมาตรฐานที่ใช้ร่วมกันทั้งแอป (ฝั่งสมาชิกและเจ้าของหอ)
/// มุมบนโค้งมน + เงานุ่มนวลลอยขึ้น ให้ดูมีมิติ แยกออกจากเนื้อหาด้านบนอย่างชัดเจน
/// แทน NavigationBar เปล่าๆแบบเดิมที่แบนราบไปกับพื้นหลัง
class AppBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Color accentColor;
  final List<NavigationDestination> destinations;

  const AppBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.accentColor,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: NavigationBarTheme(
        data: NavigationBarThemeData(
          height: 68,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          indicatorColor: accentColor.withValues(alpha: 0.14),
          indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              color: selected ? accentColor : Colors.grey.shade500,
            );
          }),
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          elevation: 0,
          destinations: destinations,
        ),
      ),
    );
  }
}
