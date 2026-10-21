// 📄 ไฟล์นี้ทำหน้าที่: วิดเจ็ตย่อยแสดงดาวให้คะแนนแบบอ่านอย่างเดียว (กดไม่ได้) ใช้โชว์คะแนน
// เฉลี่ยของหอพักและคะแนนของรีวิวแต่ละรายการในหน้ารายละเอียดหอพัก/หน้ารีวิว
import 'package:flutter/material.dart';

/// แสดงดาวแบบอ่านอย่างเดียว (ไม่กดได้) — ใช้โชว์คะแนนเฉลี่ย/คะแนนรีวิวแต่ละรายการ
class StarRatingDisplay extends StatelessWidget {
  final double rating;
  final double size;
  final Color color;

  const StarRatingDisplay({
    super.key,
    required this.rating,
    this.size = 16,
    this.color = Colors.amber,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        IconData icon;
        if (rating >= starValue) {
          icon = Icons.star_rounded;
        } else if (rating >= starValue - 0.5) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_outline_rounded;
        }
        return Icon(icon, size: size, color: color);
      }),
    );
  }
}
