// 📄 ไฟล์นี้ทำหน้าที่: ส่วนแสดงรายการรีวิวของหอพักนั้นๆ บนหน้ารายละเอียดหอพัก ดึงข้อมูลผ่าน
// dormReviewsProvider (เป็น widget ย่อยที่ dorm_detail_screen.dart เรียกใช้)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:find_dorm_mate/core/widgets/section_title.dart';
import 'package:find_dorm_mate/core/widgets/soft_card.dart';
import 'package:find_dorm_mate/features/reviews/data/review_repository.dart';
import 'package:find_dorm_mate/features/reviews/presentation/widgets/star_rating_display.dart';

/// รายการรีวิวของหอพักนี้ — ดึงจาก /api/reviews/dorm/:dormId (public)
class DormReviewsSection extends ConsumerWidget {
  final int dormId;

  const DormReviewsSection({super.key, required this.dormId});

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(dormReviewsProvider(dormId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(title: 'รีวิวจากผู้เข้าพัก', icon: Icons.star_outline_rounded),
        const SizedBox(height: 12),
        reviewsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (error, stack) => Text(
            'ดึงรีวิวไม่สำเร็จ',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          data: (result) {
            if (result.reviews.isEmpty) {
              return Text(
                'ยังไม่มีรีวิวสำหรับหอพักนี้',
                style: TextStyle(color: Colors.grey.shade600),
              );
            }

            return Column(
              children: result.reviews
                  .map(
                    (review) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SoftCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.teal.shade50,
                                  backgroundImage:
                                      review.memberProfileImage != null
                                      ? NetworkImage(
                                          review.memberProfileImage!,
                                        )
                                      : null,
                                  child: review.memberProfileImage == null
                                      ? Icon(
                                          Icons.person,
                                          color: Colors.teal.shade700,
                                          size: 18,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        review.memberUsername ?? 'ผู้ใช้',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                      StarRatingDisplay(
                                        rating: (review.rating ?? 0)
                                            .toDouble(),
                                        size: 13,
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  _formatDate(review.reviewedAt),
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            if ((review.comment ?? '').isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                review.comment!,
                                style: TextStyle(
                                  color: Colors.grey.shade800,
                                  fontSize: 13.5,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}
