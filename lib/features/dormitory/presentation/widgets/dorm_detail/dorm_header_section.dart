import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:find_dorm_mate/features/dormitory/domain/dorm_detail_model.dart';

/// ส่วนหัวของหน้ารายละเอียดหอพัก: ชื่อ + ชิปประเภทหอพัก + ที่อยู่ + ปุ่มเปิดแผนที่
class DormHeaderSection extends StatelessWidget {
  final DormDetailModel dorm;

  const DormHeaderSection({super.key, required this.dorm});

  String get _displayDormType {
    switch (dorm.dormType) {
      case 'Male':
        return 'หอพักชาย';
      case 'Female':
        return 'หอพักหญิง';
      default:
        return 'หอพักรวม';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                dorm.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _displayDormType,
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        if (dorm.reviewCount > 0) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
              const SizedBox(width: 4),
              Text(
                (dorm.averageRating ?? 0).toStringAsFixed(1),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '(${dorm.reviewCount} รีวิว)',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.location_on, color: colorScheme.error, size: 22),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                dorm.address ?? 'ไม่มีข้อมูลที่อยู่',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _MapButton(dorm: dorm),
          ],
        ),
      ],
    );
  }
}

class _MapButton extends StatelessWidget {
  final DormDetailModel dorm;

  const _MapButton({required this.dorm});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(50),
      onTap: () {
        if (dorm.latitude != null && dorm.longitude != null) {
          context.push(
            '/map',
            extra: {'lat': dorm.latitude, 'lng': dorm.longitude},
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('หอพักนี้ยังไม่ได้ระบุพิกัดบนแผนที่ 📍'),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.map_outlined,
          color: colorScheme.onPrimaryContainer,
          size: 22,
        ),
      ),
    );
  }
}
