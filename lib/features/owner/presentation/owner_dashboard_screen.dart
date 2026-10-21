// 📄 ไฟล์นี้ทำหน้าที่: หน้าหลัก "หอพักของฉัน" ฝั่งเจ้าของหอ (owner) — แสดงรายการหอพักทั้งหมดที่
// เจ้าของคนนี้ลงประกาศไว้ พร้อมสถานะอนุมัติจากแอดมิน และปุ่มไปเพิ่ม/จัดการหอพักแต่ละแห่ง
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../dormitory/data/dorm_repository.dart';
import 'package:find_dorm_mate/core/widgets/loading_view.dart';
import 'package:find_dorm_mate/core/widgets/error_view.dart';
import 'package:find_dorm_mate/core/widgets/notification_bell_button.dart';

const _tealAccent = Colors.teal;

class OwnerDashboardScreen extends ConsumerWidget {
  const OwnerDashboardScreen({super.key});

  // ฟังก์ชันตัวช่วยสำหรับดึงรูปแรกมาแสดงแบบหน้า Home
  String _getFirstImage(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return '';
    try {
      List<dynamic> images = jsonDecode(jsonString);
      if (images.isNotEmpty) {
        return images.first.toString();
      }
    } catch (e) {
      return '';
    }
    return '';
  }

  // 🚀 Backend เก็บ Dorm_Type เป็นภาษาอังกฤษ ('Male'/'Female'/'Mixed') แต่ก่อนหน้านี้
  // โค้ดจุดนี้ดันไปเทียบกับ 'ชาย'/'หญิง' (ภาษาไทย) ทำให้ไม่เคยตรงเงื่อนไขเลยสักครั้ง
  // ป้ายเลยกลายเป็นสีม่วง (ค่า default) ตลอด และข้อความก็โชว์เป็นภาษาอังกฤษดิบๆ
  // ดีไซน์ป้ายนี้ให้เหมือนกับ DormCard ของหน้า Home (User) เป๊ะๆ ต่างกันแค่ label
  ({Color bg, Color text, String label}) _dormTypeInfo(String? type) {
    switch (type) {
      case 'Male':
        return (
          bg: Colors.blue.shade50,
          text: Colors.blue.shade700,
          label: 'หอชาย',
        );
      case 'Female':
        return (
          bg: Colors.pink.shade50,
          text: Colors.pink.shade700,
          label: 'หอหญิง',
        );
      default:
        return (
          bg: Colors.purple.shade50,
          text: Colors.purple.shade700,
          label: 'หอรวม',
        );
    }
  }

  // ฟังก์ชันสร้างป้ายสถานะสวยๆ
  Widget _buildStatusBadge(String? status) {
    Color bgColor;
    Color textColor;
    IconData iconData;
    String textDisplay;

    switch (status?.toLowerCase()) {
      case 'approved':
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        iconData = Icons.check_circle;
        textDisplay = 'อนุมัติแล้ว';
        break;
      case 'rejected':
        bgColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
        iconData = Icons.cancel;
        textDisplay = 'ไม่อนุมัติ / ต้องแก้ไข';
        break;
      case 'pending':
      default:
        bgColor = Colors.orange.shade50;
        textColor = Colors.orange.shade800;
        iconData = Icons.hourglass_top;
        textDisplay = 'รอแอดมินตรวจสอบ';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 16, color: textColor),
          const SizedBox(width: 6),
          Text(
            textDisplay,
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dormsAsyncValue = ref.watch(ownerDormsProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'หอพักของฉัน',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.grey.shade50,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [const NotificationBellButton(color: Colors.black87)],
      ),

      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => context.push('/add-dorm'),
        backgroundColor: _tealAccent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'เพิ่มหอพัก',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),

      body: dormsAsyncValue.when(
        loading: () => const LoadingView(),
        error: (error, stack) => ErrorView(
          message: '$error',
          onRetry: () => ref.invalidate(ownerDormsProvider),
        ),
        data: (dorms) {
          if (dorms.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.apartment, size: 100, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text(
                    'คุณยังไม่มีรายการหอพัก',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'กดปุ่ม "เพิ่มหอพัก" ด้านล่างเพื่อเริ่มลงประกาศ',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(ownerDormsProvider);
            },
            color: _tealAccent,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
              itemCount: dorms.length,
              itemBuilder: (context, index) {
                final dorm = dorms[index];
                final imageUrl = _getFirstImage(dorm.images);
                final typeInfo = _dormTypeInfo(dorm.dormType);

                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => context.push('/dorm/${dorm.id}'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 180,
                            width: double.infinity,
                            color: Colors.grey.shade200,
                            child: imageUrl.isNotEmpty
                                ? Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    cacheWidth: 800,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Center(
                                          child: Icon(
                                            Icons.broken_image,
                                            size: 64,
                                            color: Colors.grey,
                                          ),
                                        ),
                                  )
                                : Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          _tealAccent.shade300,
                                          _tealAccent.shade600,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.apartment,
                                        size: 64,
                                        color: Colors.white54,
                                      ),
                                    ),
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
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
                                        color: typeInfo.bg,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        typeInfo.label,
                                        style: TextStyle(
                                          color: typeInfo.text,
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
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Divider(height: 1),
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'สถานะการแสดงผล:',
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          _buildStatusBadge(dorm.status),
                                        ],
                                      ),
                                    ),
                                    FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: _tealAccent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 10,
                                        ),
                                      ),
                                      onPressed: () =>
                                          context.push('/dorm/${dorm.id}'),
                                      icon: const Icon(Icons.settings, size: 18),
                                      label: const Text('จัดการหอพัก'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
