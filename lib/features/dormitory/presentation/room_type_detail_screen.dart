import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/dorm_repository.dart';
import 'package:find_dorm_mate/core/widgets/image_sliver_app_bar.dart';
import 'package:find_dorm_mate/core/widgets/facilities_section.dart';
import 'widgets/room_type_detail/room_header_section.dart';
import 'widgets/room_type_detail/room_info_section.dart';
import 'widgets/room_type_detail/room_bottom_action_bar.dart';

/// หน้ารายละเอียดห้องพัก — ธีม Material 3 เดียวกับหน้ารายละเอียดหอพัก
/// (SliverAppBar รูปภาพ + section การ์ดนุ่มนวล + แถบปุ่ม CTA ยึดด้านล่างจอ)
class RoomTypeDetailScreen extends ConsumerWidget {
  final int roomId;
  const RoomTypeDetailScreen({super.key, required this.roomId});

  // 🚀 กันเคสข้อมูลรูปเก่าที่ไม่ได้เป็น JSON array มาตรฐาน (เช่น string คั่นด้วย comma
  // ธรรมดา) ให้ยังพอ parse ออกมาแสดงได้แทนที่จะพังไปเลย
  List<String> _parseImages(String? dataString) {
    if (dataString == null || dataString.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(dataString);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (e) {
      final cleaned = dataString.replaceAll(RegExp(r'[\[\]"]'), '');
      return cleaned
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsyncValue = ref.watch(roomTypeDetailProvider(roomId));

    return roomAsyncValue.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => Scaffold(
        appBar: AppBar(title: const Text('รายละเอียดห้องพัก')),
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
      data: (room) {
        final imageUrls = _parseImages(room.roomImages);
        // 💡 อนุญาตให้เข้าคิวได้แม้ห้องจะเต็มแล้ว แต่ยังคงแสดงสีเพื่อบอกสถานะปัจจุบัน
        final isAvailable =
            room.roomStatus == 'Available' || room.roomStatus == 'ว่าง';

        return Scaffold(
          extendBodyBehindAppBar: true,
          bottomNavigationBar: RoomBottomActionBar(
            roomTypeId: roomId,
            remainingRooms: room.remainingRooms,
            room: room,
          ),
          body: CustomScrollView(
            slivers: [
              ImageSliverAppBar(
                images: imageUrls,
                placeholderIcon: Icons.meeting_room,
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RoomHeaderSection(
                        dormName: room.dormName,
                        roomName: room.name,
                        isAvailable: isAvailable,
                      ),
                      const _SectionGap(),
                      RoomInfoSection(
                        price: room.price,
                        totalRooms: room.totalRooms,
                        remainingRooms: room.remainingRooms,
                        isAvailable: isAvailable,
                      ),
                      const _SectionGap(),
                      FacilitiesSection(
                        title: 'สิ่งอำนวยความสะดวก (ภายในห้อง)',
                        facilities: room.facilities,
                        customFacilities: room.customFacilities,
                      ),
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

/// ระยะห่างมาตรฐานระหว่าง section แต่ละส่วน
class _SectionGap extends StatelessWidget {
  const _SectionGap();

  @override
  Widget build(BuildContext context) => const SizedBox(height: 28);
}
