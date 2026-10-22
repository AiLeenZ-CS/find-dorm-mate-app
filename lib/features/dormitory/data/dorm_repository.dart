// 📄 ไฟล์นี้ทำหน้าที่: Repository ติดต่อ API ของฝั่ง "หอพัก" ทั้งหมด (ดึงรายการหอพัก, รายละเอียดหอ/ห้อง,
// สร้าง/แก้ไขหอพักและห้องพัก) พร้อม Riverpod provider ให้หน้าจอต่างๆ (Home, รายละเอียดหอ/ห้อง, ฝั่งเจ้าของหอ) เรียกใช้
import 'package:dio/dio.dart';
import 'package:find_dorm_mate/features/dormitory/domain/room_type_detail_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:find_dorm_mate/core/config/api_config.dart';
import 'package:find_dorm_mate/core/network/api_client.dart';
import '../domain/dorm_model.dart';
import '../domain/dorm_detail_model.dart';

final dormRepositoryProvider = Provider((ref) => DormRepository());

// สร้าง FutureProvider เพื่อให้ UI ดึงข้อมูลไปแสดงง่ายๆ (จัดการ Loading/Error ให้อัตโนมัติ)
final dormListProvider = FutureProvider<List<DormModel>>((ref) async {
  final repository = ref.read(dormRepositoryProvider);
  return repository.getAllDorms();
});

final roomTypeDetailProvider = FutureProvider.family<RoomTypeDetailModel, int>((
  ref,
  id,
) async {
  return ref.read(dormRepositoryProvider).getRoomTypeById(id);
});

final dormDetailProvider = FutureProvider.family<DormDetailModel, int>((
  ref,
  id,
) async {
  return ref.read(dormRepositoryProvider).getDormById(id);
});

// 🆕 Provider สำหรับดึงหอพักของเจ้าของ (รีเฟรชใหม่ทุกครั้งที่เข้าหน้า)
final ownerDormsProvider = FutureProvider.autoDispose<List<DormModel>>((
  ref,
) async {
  final prefs = await SharedPreferences.getInstance();
  final ownerId = prefs.getInt('member_id');
  // 🚀 ห้าม fallback เป็น ID เดา (เช่น 1) เพราะจะไปดึงข้อมูลของเจ้าของคนอื่นโดยไม่ตั้งใจ
  // ถ้ายังไม่รู้ ownerId แปลว่ายังไม่ได้ login จริงๆ ควรแจ้ง error ให้เห็นชัดแทน
  if (ownerId == null) {
    throw Exception('ไม่พบข้อมูลผู้ใช้ กรุณาเข้าสู่ระบบใหม่');
  }
  return ref.read(dormRepositoryProvider).getDormsByOwner(ownerId);
});

// 🆕 Provider สำหรับดึงสิ่งอำนวยความสะดวก
final dormFacilitiesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  return ref.read(dormRepositoryProvider).getDormFacilities();
});

// 🆕 Provider ดึงสิ่งอำนวยความสะดวกของห้องพัก
final roomFacilitiesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final response = await ApiClient.instance.get(
        '${ApiConfig.apiUrl}/dorms/facilities/room',
      );
      return List<Map<String, dynamic>>.from(response.data['data']);
    });

class DormRepository {
  final Dio _dio = ApiClient.instance;
  final String baseUrl = '${ApiConfig.apiUrl}/dorms';

  Future<List<DormModel>> getAllDorms() async {
    try {
      final response = await _dio.get(baseUrl);
      final List<dynamic> data = response.data['data'];
      return data.map((json) => DormModel.fromJson(json)).toList();
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'เกิดข้อผิดพลาดในการดึงข้อมูลหอพัก',
      );
    }
  }

  Future<DormDetailModel> getDormById(int id) async {
    try {
      final response = await _dio.get('$baseUrl/$id');
      return DormDetailModel.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'เกิดข้อผิดพลาดในการดึงข้อมูล');
    }
  }

  Future<RoomTypeDetailModel> getRoomTypeById(int id) async {
    try {
      final response = await _dio.get('$baseUrl/room/$id');
      return RoomTypeDetailModel.fromJson(response.data['data']);
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'เกิดข้อผิดพลาดในการดึงข้อมูลห้องพัก',
      );
    }
  }

  // 🆕 ฟังก์ชันสำหรับส่งข้อมูลสร้างหอพักใหม่ (POST)
  Future<void> createDorm(Map<String, dynamic> dormData) async {
    try {
      final response = await _dio.post(baseUrl, data: dormData);

      // Prisma มักจะตอบกลับเป็น 201 (Created) เมื่อสร้างข้อมูลสำเร็จ
      if (response.statusCode == 201 || response.statusCode == 200) {
      } else {
        throw Exception('เซิร์ฟเวอร์ตอบสนองผิดพลาด: ${response.statusCode}');
      }
    } on DioException catch (e) {
      String errorMsg = 'เกิดข้อผิดพลาดในการเชื่อมต่อเซิร์ฟเวอร์';

      if (e.response?.data != null) {
        // เช็คก่อนว่า Backend ส่งกลับมาเป็น JSON (Map) หรือไม่
        if (e.response!.data is Map<String, dynamic>) {
          errorMsg =
              e.response!.data['error'] ??
              e.response!.data['message'] ??
              errorMsg;
        } else {
          errorMsg = 'เซิร์ฟเวอร์ขัดข้อง (Error ${e.response?.statusCode})';
        }
      }
      throw Exception(errorMsg);
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาด: $e');
    }
  }

  // 🆕 ดึงรายการหอพักเฉพาะของ Owner คนนั้นๆ
  Future<List<DormModel>> getDormsByOwner(int ownerId) async {
    try {
      final response = await _dio.get('$baseUrl/owner/$ownerId');
      final List<dynamic> data = response.data['data'];
      return data.map((json) => DormModel.fromJson(json)).toList();
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'เกิดข้อผิดพลาดในการดึงข้อมูล');
    }
  }

  Future<List<Map<String, dynamic>>> getDormFacilities() async {
    try {
      // ชี้ไปที่ Route ที่เราเพิ่งสร้างใน Node.js
      final response = await _dio.get('$baseUrl/facilities/dormitory');
      return List<Map<String, dynamic>>.from(response.data['data']);
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'เกิดข้อผิดพลาดในการดึงสิ่งอำนวยความสะดวก',
      );
    }
  }

  // เพิ่มในคลาส DormRepository
  Future<void> createRoomType(Map<String, dynamic> roomData) async {
    await _dio.post('$baseUrl/room-types', data: roomData);
  }

  // 🆕 แก้ไขข้อมูลประเภทห้องพัก (ไม่รองรับแก้รูปภาพในรอบนี้ เหมือน updateDorm)
  Future<void> updateRoomType(int roomId, Map<String, dynamic> roomData) async {
    try {
      await _dio.patch('$baseUrl/room-types/$roomId', data: roomData);
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'เกิดข้อผิดพลาดในการแก้ไขห้องพัก',
      );
    }
  }

  // 🆕 แก้ไขข้อมูลหอพัก (ตอนนี้รองรับแค่ Dorm_Description)
  Future<void> updateDorm(int dormId, Map<String, dynamic> dormData) async {
    try {
      await _dio.patch('$baseUrl/$dormId', data: dormData);
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'เกิดข้อผิดพลาดในการแก้ไขข้อมูลหอพัก',
      );
    }
  }

  // 🚀 ลบห้องพักประเภทนี้ — backend จะปฏิเสธถ้ามีใบจองสถานะ Pending/Confirmed ของห้องนี้อยู่
  Future<void> deleteRoomType(int roomId) async {
    try {
      await _dio.delete('$baseUrl/room-types/$roomId');
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'เกิดข้อผิดพลาดในการลบห้องพัก',
      );
    }
  }

  // 🚀 ลบหอพักนี้ทั้งหอ — backend จะปฏิเสธถ้ามีใบจองสถานะ Pending/Confirmed ของห้องไหนในหอนี้อยู่
  Future<void> deleteDorm(int dormId) async {
    try {
      await _dio.delete('$baseUrl/$dormId');
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'เกิดข้อผิดพลาดในการลบหอพัก',
      );
    }
  }
}
