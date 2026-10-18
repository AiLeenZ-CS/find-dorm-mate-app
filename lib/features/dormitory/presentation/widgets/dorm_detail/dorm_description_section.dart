import 'package:flutter/material.dart';
import 'package:find_dorm_mate/core/widgets/section_title.dart';

/// ข้อความแนะนำหอพักแบบยาวที่เจ้าของพิมพ์เอง (Dorm_Description) — ไม่แสดงถ้าไม่มีข้อมูล
class DormDescriptionSection extends StatelessWidget {
  final String description;

  const DormDescriptionSection({super.key, required this.description});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'เกี่ยวกับหอพักนี้', icon: Icons.info_outline),
        const SizedBox(height: 10),
        Text(
          description,
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey.shade800,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}
