// 📄 ไฟล์นี้ทำหน้าที่: ส่วนหัวของหน้า Home (ทักทายผู้ใช้, ช่องค้นหา, ปุ่มแชท/แจ้งเตือน/แผนที่/ตัวกรอง)
// เป็น widget ย่อยที่ home_screen.dart เรียกใช้
import 'package:flutter/material.dart';
import 'package:find_dorm_mate/core/widgets/notification_bell_button.dart';

/// ส่วนหัวหน้า Home: ทักทาย + ปุ่มแชท/แจ้งเตือน + ช่องค้นหา + ปุ่มแผนที่/ตัวกรอง
/// ออกแบบเป็น "hero" ไล่เฉดสีม่วง ขอบมุมล่างโค้งมน — ปุ่มแชท/แจ้งเตือนอยู่ในเลย์เอาต์
/// Row เดียวกับข้อความทักทาย (ไม่ใช่ลอยทับแบบ Stack เหมือนเดิม) จึงไม่มีทางไปทับกับ
/// ข้อความทักทายได้อีก ไม่ว่าจอจะเล็กแค่ไหน
class HomeSearchHeader extends StatelessWidget {
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onMapTap;
  final VoidCallback onFilterTap;
  final VoidCallback onChatTap;
  final int activeFilterCount;
  final String? username;

  const HomeSearchHeader({
    super.key,
    required this.onSearchChanged,
    required this.onMapTap,
    required this.onFilterTap,
    required this.onChatTap,
    this.activeFilterCount = 0,
    this.username,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple, Colors.deepPurple.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          username != null && username!.isNotEmpty
                              ? 'สวัสดี, $username 👋'
                              : 'ค้นหาหอพักที่ใช่ 🏢',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'หอพักน่าสนใจรอบๆ มหาวิทยาลัย',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _FloatingWhiteIconButton(
                    icon: Icons.chat_bubble_outline,
                    tooltip: 'แชทของฉัน',
                    onTap: onChatTap,
                  ),
                  const SizedBox(width: 10),
                  const NotificationBellButton(
                    floating: true,
                    color: Colors.deepPurple,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: TextField(
                        onChanged: onSearchChanged,
                        decoration: InputDecoration(
                          hintText: 'ค้นหาชื่อหอพัก หรือสิ่งอำนวยความสะดวก...',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(Icons.search, color: colorScheme.primary),
                          filled: true,
                          fillColor: Colors.transparent,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _RoundIconButton(
                    icon: Icons.map_rounded,
                    onTap: onMapTap,
                    background: colorScheme.surface,
                    foreground: colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  _RoundIconButton(
                    icon: Icons.tune_rounded,
                    onTap: onFilterTap,
                    background: colorScheme.primary,
                    foreground: colorScheme.onPrimary,
                    badgeCount: activeFilterCount,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ปุ่มแชทวงกลมสีขาวลอยตัว — ตั้งใจให้หน้าตาเหมือน NotificationBellButton(floating: true)
/// เป๊ะๆ เพื่อให้ดูเป็นคู่กันบนพื้นหลังไล่เฉดสีม่วง
class _FloatingWhiteIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _FloatingWhiteIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.deepPurple),
        tooltip: tooltip,
        onPressed: onTap,
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color background;
  final Color foreground;
  final int badgeCount;

  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    required this.background,
    required this.foreground,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: background,
          borderRadius: BorderRadius.circular(16),
          elevation: 0,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(icon, color: foreground),
            ),
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
