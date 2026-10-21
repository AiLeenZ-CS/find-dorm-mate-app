// 📄 ไฟล์นี้ทำหน้าที่: ส่วนแสดงรายการประเภทห้องพักของหอพักนั้นๆ บนหน้ารายละเอียดหอพัก กดแต่ละใบ
// เพื่อไปหน้ารายละเอียดห้อง (เป็น widget ย่อยที่ dorm_detail_screen.dart เรียกใช้)
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:find_dorm_mate/features/dormitory/domain/dorm_detail_model.dart';
import 'package:find_dorm_mate/core/widgets/section_title.dart';
import 'package:find_dorm_mate/core/widgets/soft_card.dart';

/// รายการประเภทห้องพักของหอพักนี้ — กดแต่ละใบเพื่อไปหน้ารายละเอียดห้อง
class DormRoomTypesSection extends StatelessWidget {
  final List<RoomTypeModel> roomTypes;

  const DormRoomTypesSection({super.key, required this.roomTypes});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(
          title: 'ประเภทห้องพักที่มี',
          icon: Icons.meeting_room_outlined,
        ),
        const SizedBox(height: 12),
        if (roomTypes.isEmpty)
          Text(
            'ยังไม่มีข้อมูลห้องพัก',
            style: TextStyle(color: Colors.grey.shade600),
          )
        else
          ...roomTypes.map((room) => _RoomTypeCard(room: room)),
      ],
    );
  }
}

class _RoomTypeCard extends StatelessWidget {
  final RoomTypeModel room;

  const _RoomTypeCard({required this.room});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push('/room/${room.id}'),
          child: SoftCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.name ?? 'ห้องพัก',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.door_front_door_outlined,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'ว่าง ${room.remaining ?? 0} ห้อง',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      room.price != null ? '฿${room.price}/ด.' : '-',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.grey.shade400,
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
