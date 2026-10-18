import 'package:flutter/material.dart';
import 'package:find_dorm_mate/features/dormitory/domain/dorm_model.dart';
import 'package:find_dorm_mate/features/dormitory/widgets/dorm_image_carousel.dart';

/// การ์ดหอพักในหน้า Home — เงานุ่มนวล ขอบโค้งมน ธีมเดียวกับหน้ารายละเอียด
class DormCard extends StatelessWidget {
  final DormModel dorm;
  final String priceDisplay;
  final VoidCallback onTap;

  const DormCard({
    super.key,
    required this.dorm,
    required this.priceDisplay,
    required this.onTap,
  });

  ({Color background, Color text, String label}) _typeStyle(
    ColorScheme colorScheme,
  ) {
    switch (dorm.dormType) {
      case 'Male':
        return (
          background: Colors.blue.shade50,
          text: Colors.blue.shade700,
          label: 'ชาย',
        );
      case 'Female':
        return (
          background: Colors.pink.shade50,
          text: Colors.pink.shade700,
          label: 'หญิง',
        );
      default:
        return (
          background: colorScheme.primaryContainer,
          text: colorScheme.onPrimaryContainer,
          label: 'รวม',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final type = _typeStyle(colorScheme);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DormImageCarousel(imageString: dorm.images, height: 200),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            dorm.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: type.background,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            type.label,
                            style: TextStyle(
                              color: type.text,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            dorm.address ?? 'ไม่มีที่อยู่ระบุ',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (dorm.reviewCount > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Colors.amber.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            dorm.averageRating!.toStringAsFixed(1),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${dorm.reviewCount} รีวิว)',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1),
                    ),
                    Text(
                      'ค่าเช่ารายเดือน',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      priceDisplay,
                      style: TextStyle(
                        fontSize: 17,
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
