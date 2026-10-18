import 'package:flutter/material.dart';
import 'package:find_dorm_mate/core/widgets/section_title.dart';
import 'package:find_dorm_mate/core/widgets/soft_card.dart';
import 'package:find_dorm_mate/core/widgets/info_row.dart';

/// ราคา/จำนวนห้องทั้งหมด/ห้องว่างขณะนี้
class RoomInfoSection extends StatelessWidget {
  final double? price;
  final int? totalRooms;
  final int? remainingRooms;
  final bool isAvailable;

  const RoomInfoSection({
    super.key,
    this.price,
    this.totalRooms,
    this.remainingRooms,
    required this.isAvailable,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(
          title: 'ข้อมูลห้องพักเบื้องต้น',
          icon: Icons.info_outline,
        ),
        const SizedBox(height: 12),
        SoftCard(
          child: Column(
            children: [
              InfoRow(
                icon: Icons.payments_outlined,
                label: 'ราคาต่อเดือน',
                value: price != null ? '฿$price' : 'ไม่ระบุ',
                valueColor: Colors.green.shade700,
              ),
              InfoRow(
                icon: Icons.meeting_room_outlined,
                label: 'จำนวนห้องทั้งหมด',
                value: '${totalRooms ?? 0} ห้อง',
              ),
              InfoRow(
                icon: Icons.check_circle_outline,
                label: 'ห้องว่างขณะนี้',
                value: '${remainingRooms ?? 0} ห้อง',
                valueColor: isAvailable
                    ? Colors.green.shade700
                    : Colors.red.shade700,
                showBottomBorder: false,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
