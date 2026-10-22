// 📄 ไฟล์นี้ทำหน้าที่: ชั้น repository ของระบบแจ้งเตือนในแอป (in-app notification) ดึงรายการ/
// จำนวนที่ยังไม่อ่าน และมาร์กอ่านแล้ว ใช้ร่วมกันทั้ง Member และ Owner ผ่าน provider ด้านล่าง
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:find_dorm_mate/core/config/api_config.dart';
import 'package:find_dorm_mate/core/network/api_client.dart';
import '../domain/notification_model.dart';

final notificationRepositoryProvider = Provider(
  (ref) => NotificationRepository(),
);

final notificationListProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) async {
      return ref.read(notificationRepositoryProvider).getMyNotifications();
    });

final unreadNotificationCountProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  return ref.read(notificationRepositoryProvider).getUnreadCount();
});

class NotificationRepository {
  final Dio _dio = ApiClient.instance;
  final String baseUrl = '${ApiConfig.apiUrl}/notifications';

  Future<List<AppNotification>> getMyNotifications() async {
    try {
      final response = await _dio.get(baseUrl);
      final List<dynamic> data = response.data['data'] ?? [];
      return data.map((json) => AppNotification.fromJson(json)).toList();
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'เกิดข้อผิดพลาดในการดึงแจ้งเตือน',
      );
    }
  }

  // 🚀 ไม่ throw ออกไป — badge ตัวเลขโหลดไม่ได้ไม่ควรทำให้หน้าจอหลักพัง แค่โชว์ 0 ไปก่อน
  Future<int> getUnreadCount() async {
    try {
      final response = await _dio.get('$baseUrl/unread-count');
      return response.data['data']?['count'] ?? 0;
    } on DioException catch (_) {
      return 0;
    }
  }

  Future<void> markAsRead(int notificationId) async {
    try {
      await _dio.patch('$baseUrl/$notificationId/read');
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'เกิดข้อผิดพลาดในการมาร์กแจ้งเตือน',
      );
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _dio.patch('$baseUrl/read-all');
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ??
            'เกิดข้อผิดพลาดในการมาร์กแจ้งเตือนทั้งหมด',
      );
    }
  }
}
