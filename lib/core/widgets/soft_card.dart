// 📄 ไฟล์นี้ทำหน้าที่: widget การ์ดมาตรฐาน (ขอบโค้งมน + เงานุ่มนวล)
// ใช้ร่วมกันทั้งแอปแทน Card ขอบแข็งๆแบบเดิม ให้ดูโมเดิร์นเป็นแบบเดียวกันทุกหน้า
import 'package:flutter/material.dart';

/// การ์ด Material 3 มาตรฐานที่ใช้ร่วมกันทั้งแอป
/// ขอบโค้งมน + เงานุ่มนวล (soft shadow) แทนเส้นขอบแข็งๆ ให้ดูโมเดิร์นแบบ Airbnb/Agoda
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
