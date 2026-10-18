import 'package:flutter/material.dart';
import 'package:find_dorm_mate/core/widgets/section_title.dart';
import 'package:find_dorm_mate/core/widgets/soft_card.dart';
import 'package:find_dorm_mate/core/widgets/info_row.dart';

/// ค่ามัดจำ/ค่าประกัน/กฎเรื่องสัตว์เลี้ยง-สูบบุหรี่
class DormCostRulesSection extends StatelessWidget {
  final double? depositFee;
  final double? insuranceFee;
  final bool isPetFriendly;
  final bool isSmokingAllowed;

  const DormCostRulesSection({
    super.key,
    this.depositFee,
    this.insuranceFee,
    this.isPetFriendly = false,
    this.isSmokingAllowed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(
          title: 'ค่าใช้จ่ายและกฎระเบียบ',
          icon: Icons.rule_outlined,
        ),
        const SizedBox(height: 12),
        SoftCard(
          child: Column(
            children: [
              InfoRow(
                icon: Icons.payments_outlined,
                label: 'ค่ามัดจำ',
                value: depositFee != null ? '฿$depositFee' : 'ไม่ระบุ',
              ),
              InfoRow(
                icon: Icons.shield_outlined,
                label: 'ค่าประกัน',
                value: insuranceFee != null ? '฿$insuranceFee' : 'ไม่ระบุ',
              ),
              InfoRow(
                icon: Icons.pets,
                label: 'เลี้ยงสัตว์',
                value: isPetFriendly ? 'อนุญาต' : 'ไม่อนุญาต',
                valueColor: isPetFriendly ? Colors.green.shade700 : null,
              ),
              InfoRow(
                icon: Icons.smoking_rooms_outlined,
                label: 'สูบบุหรี่',
                value: isSmokingAllowed ? 'อนุญาต' : 'ไม่อนุญาต',
                valueColor: isSmokingAllowed ? Colors.green.shade700 : null,
                showBottomBorder: false,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
