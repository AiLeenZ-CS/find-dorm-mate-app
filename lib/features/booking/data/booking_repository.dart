import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:find_dorm_mate/core/config/api_config.dart';
import 'package:find_dorm_mate/core/network/api_client.dart';

final bookingRepositoryProvider = Provider((ref) => BookingRepository());

// ใบจองของฉัน (ฝั่งสมาชิก)
final myBookingsProvider = FutureProvider.autoDispose<List<dynamic>>((
  ref,
) async {
  return ref.read(bookingRepositoryProvider).getMyBookings();
});

// ใบจองที่เข้ามาที่หอของฉัน (ฝั่งเจ้าของหอ)
final ownerBookingsProvider = FutureProvider.autoDispose<List<dynamic>>((
  ref,
) async {
  return ref.read(bookingRepositoryProvider).getOwnerBookings();
});

class BookingRepository {
  final Dio _dio = ApiClient.instance;
  final String baseUrl = '${ApiConfig.apiUrl}/bookings';

  // 🚀 จองห้องพัก — Backend อ่าน Member_ID จาก JWT token เอง, ตัดสต๊อกทันทีแบบ atomic
  Future<Map<String, dynamic>> createBooking(
    int roomTypeId, {
    String? expectedMoveIn,
    String? noteToOwner,
  }) async {
    try {
      final response = await _dio.post(
        baseUrl,
        data: {
          'roomTypeId': roomTypeId,
          if (expectedMoveIn != null) 'expectedMoveIn': expectedMoveIn,
          if (noteToOwner != null) 'noteToOwner': noteToOwner,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'เกิดข้อผิดพลาดในการจองห้องพัก',
      );
    }
  }

  Future<List<dynamic>> getMyBookings() async {
    try {
      final response = await _dio.get('$baseUrl/my-bookings');
      return response.data['data'] ?? [];
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'ดึงข้อมูลใบจองไม่สำเร็จ',
      );
    }
  }

  Future<void> cancelBooking(int bookingId) async {
    try {
      await _dio.patch('$baseUrl/$bookingId/cancel');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'ยกเลิกใบจองไม่สำเร็จ');
    }
  }

  Future<List<dynamic>> getOwnerBookings() async {
    try {
      final response = await _dio.get('$baseUrl/owner');
      return response.data['data'] ?? [];
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'ดึงข้อมูลใบจองไม่สำเร็จ',
      );
    }
  }

  Future<void> confirmBooking(int bookingId) async {
    try {
      await _dio.patch('$baseUrl/$bookingId/confirm');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'ยืนยันใบจองไม่สำเร็จ');
    }
  }

  Future<void> rejectBooking(int bookingId, {String? reason}) async {
    try {
      await _dio.patch(
        '$baseUrl/$bookingId/reject',
        data: {if (reason != null) 'reason': reason},
      );
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'ปฏิเสธใบจองไม่สำเร็จ');
    }
  }

  // 🚀 เจ้าของหอรายงานผู้ใช้ — ใช้ได้ทั้งใบจองที่ยังรอตอบรับ (Pending) และยืนยันแล้ว (Confirmed)
  // รายงานไปแล้วตอน Pending จะยืนยัน (confirm) ใบจองนั้นไม่ได้อีก ฝั่ง backend เช็คซ้ำอีกชั้น
  Future<void> reportBooking(int bookingId, {String? note}) async {
    try {
      await _dio.post(
        '$baseUrl/$bookingId/report',
        data: {if (note != null && note.isNotEmpty) 'note': note},
      );
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'ส่งรายงานไม่สำเร็จ');
    }
  }
}
