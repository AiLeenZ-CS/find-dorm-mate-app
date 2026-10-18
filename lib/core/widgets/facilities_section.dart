import 'package:flutter/material.dart';
import 'section_title.dart';

/// สิ่งอำนวยความสะดวก แสดงเป็น Chip ใน Wrap ทั้ง Master (เลือกจากระบบ) และ
/// Custom (พิมพ์เพิ่มเอง) — ใช้ร่วมกันทั้งระดับหอพักและระดับห้องพัก
class FacilitiesSection extends StatelessWidget {
  final String title;
  final List<String> facilities;
  final List<String> customFacilities;

  const FacilitiesSection({
    super.key,
    this.title = 'สิ่งอำนวยความสะดวก',
    required this.facilities,
    required this.customFacilities,
  });

  @override
  Widget build(BuildContext context) {
    final hasAny = facilities.isNotEmpty || customFacilities.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title: title, icon: Icons.weekend_outlined),
        const SizedBox(height: 12),
        if (!hasAny)
          Text(
            'ไม่มีข้อมูลสิ่งอำนวยความสะดวก',
            style: TextStyle(color: Colors.grey.shade600),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...facilities.map((f) => _FacilityChip(label: f, isCustom: false)),
              ...customFacilities.map(
                (f) => _FacilityChip(label: f, isCustom: true),
              ),
            ],
          ),
      ],
    );
  }
}

class _FacilityChip extends StatelessWidget {
  final String label;
  final bool isCustom;

  const _FacilityChip({required this.label, required this.isCustom});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // 🚀 Master ใช้โทนสีหลักของธีม (primary), Custom ใช้โทน tertiary ที่ derive มาจาก
    // seed สีเดียวกัน — ต่างกันชัดแต่ยังเข้าธีมเดียวกันทั้งแอป ไม่ใช่สีลอยๆ ที่ไม่เกี่ยวกัน
    final baseColor = isCustom ? colorScheme.tertiary : colorScheme.primary;

    return Chip(
      avatar: Icon(
        isCustom ? Icons.add_circle : Icons.check_circle,
        size: 16,
        color: baseColor,
      ),
      label: Text(label),
      labelStyle: TextStyle(
        color: baseColor,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: baseColor.withValues(alpha: 0.1),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    );
  }
}
