// 📄 ไฟล์นี้ทำหน้าที่: widget หัวข้อ section มาตรฐาน (ไอคอน + ข้อความ)
// ใช้ร่วมกันทั้งแอปให้ระยะห่าง/ฟอนต์ของหัวข้อ section สม่ำเสมอกัน
import 'package:flutter/material.dart';

/// หัวข้อ section มาตรฐาน (ไอคอน + ข้อความ) ใช้ร่วมกันทั้งแอป
/// เพื่อให้ระยะห่าง/ฟอนต์สม่ำเสมอกัน
class SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? accentColor;

  const SectionTitle({
    super.key,
    required this.title,
    required this.icon,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, size: 20, color: accentColor ?? colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
