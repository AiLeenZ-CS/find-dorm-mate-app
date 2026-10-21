// 📄 ไฟล์นี้ทำหน้าที่: ส่วนหัวของหน้ารายละเอียดห้องพัก (ชื่อหอ/ชื่อห้อง/ชิปสถานะห้องว่าง-เต็ม)
// เป็น widget ย่อยที่ room_type_detail_screen.dart เรียกใช้
import 'package:flutter/material.dart';

/// ส่วนหัวของหน้ารายละเอียดห้องพัก: breadcrumb ชื่อหอพัก + ชื่อห้อง + ชิปสถานะห้องว่าง/เต็ม
class RoomHeaderSection extends StatelessWidget {
  final String? dormName;
  final String? roomName;
  final bool isAvailable;

  const RoomHeaderSection({
    super.key,
    this.dormName,
    this.roomName,
    required this.isAvailable,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.apartment, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                dormName ?? 'ข้อมูลหอพัก',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                roomName ?? 'ห้องพัก',
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
                color: isAvailable ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isAvailable ? 'ห้องว่าง' : 'ห้องเต็ม',
                style: TextStyle(
                  color: isAvailable
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
