// 📄 ไฟล์นี้ทำหน้าที่: หน้าจอรายละเอียดหอพัก (ฝั่งผู้ใช้ทั่วไป) แสดงรูป/ข้อมูล/ค่าใช้จ่าย/ประเภทห้อง/รีวิว
// ของหอพักหนึ่งหอ โดยประกอบจาก widgets ย่อยใน widgets/dorm_detail/ และดึงข้อมูลผ่าน dormDetailProvider
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/dorm_repository.dart';
import 'package:find_dorm_mate/core/widgets/image_sliver_app_bar.dart';
import 'package:find_dorm_mate/core/widgets/facilities_section.dart';
import 'widgets/dorm_detail/dorm_header_section.dart';
import 'widgets/dorm_detail/dorm_description_section.dart';
import 'widgets/dorm_detail/dorm_cost_rules_section.dart';
import 'widgets/dorm_detail/dorm_room_types_section.dart';
import 'widgets/dorm_detail/dorm_reviews_section.dart';
import 'widgets/dorm_detail/dorm_bottom_action_bar.dart';

/// หน้ารายละเอียดหอพัก — Material 3, สไตล์ Airbnb/Agoda
/// โครงสร้างแบ่งเป็น: SliverAppBar รูปภาพ (ยืดหดได้) + เนื้อหาแบบ section การ์ดนุ่มนวล
/// + แถบปุ่ม CTA ยึดด้านล่างจอ (แยก widget ย่อยไว้ใต้ widgets/dorm_detail/ ทั้งหมด)
class DormDetailScreen extends ConsumerWidget {
  final int dormId;
  const DormDetailScreen({super.key, required this.dormId});

  List<String> _parseImages(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return [];
    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.map((e) => e.toString()).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsyncValue = ref.watch(dormDetailProvider(dormId));

    return detailAsyncValue.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => Scaffold(
        appBar: AppBar(title: const Text('รายละเอียดหอพัก')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text(
                  'เกิดข้อผิดพลาด: $err',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (dorm) {
        final imageUrls = _parseImages(dorm.images);
        final hasDescription = (dorm.description ?? '').trim().isNotEmpty;

        return Scaffold(
          extendBodyBehindAppBar: true,
          bottomNavigationBar: DormBottomActionBar(dorm: dorm),
          body: CustomScrollView(
            slivers: [
              ImageSliverAppBar(
                images: imageUrls,
                placeholderIcon: Icons.apartment,
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DormHeaderSection(dorm: dorm),
                      if (hasDescription) ...[
                        const _SectionGap(),
                        DormDescriptionSection(description: dorm.description!),
                      ],
                      const _SectionGap(),
                      DormCostRulesSection(
                        depositFee: dorm.depositFee,
                        insuranceFee: dorm.insuranceFee,
                        isPetFriendly: dorm.isPetFriendly,
                        isSmokingAllowed: dorm.isSmokingAllowed,
                      ),
                      const _SectionGap(),
                      FacilitiesSection(
                        facilities: dorm.facilities,
                        customFacilities: dorm.customFacilities,
                      ),
                      const _SectionGap(),
                      DormRoomTypesSection(roomTypes: dorm.roomTypes),
                      const _SectionGap(),
                      DormReviewsSection(dormId: dorm.id),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// ระยะห่างมาตรฐานระหว่าง section แต่ละส่วน ใช้ร่วมกันเพื่อความสม่ำเสมอ
class _SectionGap extends StatelessWidget {
  const _SectionGap();

  @override
  Widget build(BuildContext context) => const SizedBox(height: 28);
}
