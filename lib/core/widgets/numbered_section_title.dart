import 'package:flutter/material.dart';

/// หัวข้อ section แบบมีเลขลำดับ + คำอธิบายย่อย ใช้กับฟอร์มยาวๆ หลายขั้นตอน
/// (เช่น หน้าลงประกาศหอพัก/เพิ่มห้องพัก) ให้ความรู้สึกเป็นขั้นตอนที่ชัดเจน
/// เป็นมืออาชีพกว่า SectionTitle ธรรมดาที่มีแค่ไอคอน+ชื่อ
class NumberedSectionTitle extends StatelessWidget {
  final int step;
  final String title;
  final String? subtitle;
  final Color accentColor;

  const NumberedSectionTitle({
    super.key,
    required this.step,
    required this.title,
    this.subtitle,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(
            '$step',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
