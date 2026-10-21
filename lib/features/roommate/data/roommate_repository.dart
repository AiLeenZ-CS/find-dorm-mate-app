// 📄 ไฟล์นี้ทำหน้าที่: Repository หลักของฟีเจอร์หารูมเมท — เรียก REST API (Node.js backend)
// สำหรับสร้าง/แก้ไข/ลบประกาศ, ส่ง-อนุมัติ-ยกเลิกคำขอจับคู่, และดึงประกาศของฉัน/ที่จับคู่แล้ว
// รวม Riverpod providers ที่หน้าจอต่างๆ ในฟีเจอร์นี้เรียกใช้
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:find_dorm_mate/core/config/api_config.dart';
import 'package:find_dorm_mate/core/network/api_client.dart';
import '../domain/roommate_post_model.dart';

final roommateRepositoryProvider = Provider((ref) => RoommateRepository());

// 🚀 Provider สำหรับดึงประกาศทั้งหมด (หน้า Feed หลัก)
final roommateListProvider = FutureProvider<List<RoommatePostModel>>((
  ref,
) async {
  return ref.read(roommateRepositoryProvider).getAllPosts();
});

// 🚀 Provider สำหรับดึงประกาศเฉพาะของหอพักนั้นๆ
final roommateListByDormProvider =
    FutureProvider.family<List<RoommatePostModel>, int>((ref, dormId) async {
      return ref.read(roommateRepositoryProvider).getPostsByDorm(dormId);
    });

// 🆕 Provider ดึงประกาศทั้งหมดที่ตัวเองสร้าง (ทุกสถานะ รวมที่จับคู่ครบแล้ว/ปิดจากหน้ารวมไปแล้ว)
final myRoommatePostsProvider =
    FutureProvider.autoDispose<List<RoommatePostModel>>((ref) async {
      return ref.read(roommateRepositoryProvider).getMyPosts();
    });

// 🆕 Provider ดึงประกาศที่ตัวเองจับคู่สำเร็จ (ในฐานะผู้ขอ) — ไม่ระบุ status จะได้แค่ที่
// Matched แล้วเท่านั้น (ใช้กับแท็บ "จับคู่แล้ว")
final myMatchedRoommatePostsProvider =
    FutureProvider.autoDispose<List<RoommatePostModel>>((ref) async {
      return ref.read(roommateRepositoryProvider).getMyMatchedPosts();
    });

// 🆕 Provider ดูประวัติคำขอจับคู่ "ของฉัน" (ในฐานะผู้ขอ) กรองตามสถานะได้ — ใช้กับแท็บ
// "ที่ฉันจับคู่ด้วย" ที่มีตัวกรองสถานะ ส่ง status: 'All' เพื่อดูทุกสถานะ
final myMatchHistoryProvider =
    FutureProvider.autoDispose.family<List<RoommatePostModel>, String>((
      ref,
      status,
    ) async {
      return ref
          .read(roommateRepositoryProvider)
          .getMyMatchedPosts(status: status);
    });

// 🆕 Provider เช็คสถานะคำขอจับคู่ของ "ตัวเอง" สำหรับประกาศนี้ (null = ยังไม่เคยส่งคำขอ)
final myMatchRequestStatusProvider =
    FutureProvider.family.autoDispose<Map<String, dynamic>?, int>((
      ref,
      postId,
    ) async {
      return ref.read(roommateRepositoryProvider).getMyRequestStatus(postId);
    });

// 🆕 Provider ดึงรายการคำขอจับคู่ที่เข้ามาที่ประกาศของตัวเอง (สำหรับเจ้าของประกาศ)
// คืนค่าเป็น { matches: [...], post: { Post_Status, Req_Persons, Matched_Count } }
// เพื่อให้หน้าจอโชว์ความคืบหน้า/สถานะปิดประกาศได้โดยไม่ต้องยิง API แยก
final postMatchRequestsProvider =
    FutureProvider.family.autoDispose<Map<String, dynamic>, int>((
      ref,
      postId,
    ) async {
      return ref.read(roommateRepositoryProvider).getPostMatchRequests(postId);
    });

// 🆕 Provider ดึงรายชื่อสมาชิกที่จับคู่แล้วในประกาศนี้ (เจ้าของ + คนที่ Matched) — เข้าถึงได้
// ทั้งเจ้าของประกาศและสมาชิกที่จับคู่ด้วย คืนค่าเป็น { owner: {...}, members: [...] }
final postMembersProvider =
    FutureProvider.family.autoDispose<Map<String, dynamic>, int>((
      ref,
      postId,
    ) async {
      return ref.read(roommateRepositoryProvider).getPostMembers(postId);
    });

// 🆕 Provider รายการคำขอจับคู่ทั้งหมดที่ฉันเกี่ยวข้อง (ส่งไปเอง + ส่งมาที่ประกาศของฉัน) —
// ใช้ทำแท็บ "แชทเดี่ยว" ในหน้า "แชทของฉัน"
final myMatchRequestsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      return ref.read(roommateRepositoryProvider).getMyMatchRequests();
    });

class RoommateRepository {
  final Dio _dio = ApiClient.instance;
  final String baseUrl = '${ApiConfig.apiUrl}/roommates';

  // -----------------------------------------------------
  // 🆕 1. ฟังก์ชันสร้างประกาศหารูมเมทใหม่
  // -----------------------------------------------------
  Future<void> createRoommatePost({
    required int dormId,
    required int roomTypeId,
    required int reqPersons,
    required String reqGender,
    required String reqAgeRange,
    required String sleepTime,
    required String smokingAllowed,
    required String petAllowed,
    required String cleanliness,
    String? additionalNotes,
    // 🚀 ส่งมาเมื่อสร้างประกาศจากปุ่ม "ประกาศหารูมเมท" บนใบจองที่ยืนยันแล้ว —
    // Backend จะยึด Dorm/Room จากใบจองจริงและ flag ประกาศนี้ว่า "มีห้องแล้ว"
    int? bookingId,
  }) async {
    try {
      // 🚀 Backend อ่าน Member_ID จาก JWT token เอง (แนบให้อัตโนมัติผ่าน ApiClient)
      // แพ็คข้อมูลให้ Key ตรงกับ req.body ของฝั่ง Node.js
      final data = {
        "Dorm_ID": dormId,
        "Room_Type_ID": roomTypeId,
        "Req_Persons": reqPersons,
        "Req_Gender": reqGender,
        "Req_Age_Range": reqAgeRange,
        "Sleep_Time": sleepTime,
        "Smoking_Allowed": smokingAllowed,
        "Pet_Allowed": petAllowed,
        "Cleanliness": cleanliness,
        "Additional_Notes": additionalNotes,
        if (bookingId != null) "Booking_ID": bookingId,
      };

      // ยิง API ด้วย Method POST
      final response = await _dio.post(baseUrl, data: data);

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception('สร้างประกาศไม่สำเร็จ');
      }
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'เกิดข้อผิดพลาดในการสร้างประกาศ',
      );
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดของระบบ: $e');
    }
  }

  // -----------------------------------------------------
  // 2. ฟังก์ชันดึงประกาศทั้งหมด
  // -----------------------------------------------------
  Future<List<RoommatePostModel>> getAllPosts() async {
    try {
      final response = await _dio.get(baseUrl);

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((json) => RoommatePostModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load roommate posts');
      }
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'เกิดข้อผิดพลาดในการดึงข้อมูลรูมเมท',
      );
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดของระบบ: $e');
    }
  }

  // -----------------------------------------------------
  // 3. ฟังก์ชันดึงประกาศตาม ID หอพัก
  // -----------------------------------------------------
  Future<List<RoommatePostModel>> getPostsByDorm(int dormId) async {
    try {
      final response = await _dio.get('$baseUrl?dormId=$dormId');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((json) => RoommatePostModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load roommate posts');
      }
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ??
            'เกิดข้อผิดพลาดในการดึงข้อมูลรูมเมทของหอพักนี้',
      );
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดของระบบ: $e');
    }
  }

  // -----------------------------------------------------
  // 🆕 3.5. ประกาศของฉัน (ทุกสถานะ) + ประกาศที่ฉันจับคู่สำเร็จ
  // -----------------------------------------------------
  Future<List<RoommatePostModel>> getMyPosts() async {
    try {
      final response = await _dio.get('$baseUrl/my-posts');
      final List<dynamic> data = response.data['data'] ?? [];
      return data.map((json) => RoommatePostModel.fromJson(json)).toList();
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'เกิดข้อผิดพลาดในการดึงประกาศของฉัน',
      );
    }
  }

  Future<List<RoommatePostModel>> getMyMatchedPosts({String? status}) async {
    try {
      final response = await _dio.get(
        '$baseUrl/my-matched-posts',
        queryParameters: status != null ? {'status': status} : null,
      );
      final List<dynamic> data = response.data['data'] ?? [];
      return data.map((json) => RoommatePostModel.fromJson(json)).toList();
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'เกิดข้อผิดพลาดในการดึงประกาศที่จับคู่',
      );
    }
  }

  // -----------------------------------------------------
  // 🆕 4. ผู้ขอ: ส่งคำขอจับคู่ไปยังประกาศ
  // -----------------------------------------------------
  Future<void> sendMatchRequest(int postId, {String? message}) async {
    try {
      await _dio.post(
        '$baseUrl/$postId/matches',
        data: {if (message != null) 'message': message},
      );
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'เกิดข้อผิดพลาดในการส่งคำขอจับคู่',
      );
    }
  }

  // -----------------------------------------------------
  // 🆕 5. ผู้ขอ: เช็คสถานะคำขอของตัวเองสำหรับประกาศนี้
  // -----------------------------------------------------
  Future<Map<String, dynamic>?> getMyRequestStatus(int postId) async {
    try {
      final response = await _dio.get('$baseUrl/$postId/my-request-status');
      return response.data['data'];
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'เกิดข้อผิดพลาดในการดึงสถานะคำขอ',
      );
    }
  }

  // -----------------------------------------------------
  // 🆕 6. เจ้าของประกาศ: ดูรายการคำขอจับคู่ (พร้อมโปรไฟล์ผู้ขอ + ความคืบหน้าของประกาศ)
  // -----------------------------------------------------
  Future<Map<String, dynamic>> getPostMatchRequests(int postId) async {
    try {
      final response = await _dio.get('$baseUrl/$postId/matches');
      return {
        'matches': List<Map<String, dynamic>>.from(response.data['data'] ?? []),
        'post': response.data['post'] as Map<String, dynamic>?,
      };
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'เกิดข้อผิดพลาดในการดึงคำขอจับคู่',
      );
    }
  }

  // -----------------------------------------------------
  // 🆕 6.5 รายชื่อสมาชิกที่จับคู่แล้วในประกาศนี้ (เจ้าของ + Matched) — เข้าถึงได้ทั้งเจ้าของ
  // ประกาศและสมาชิกที่จับคู่ด้วย ต่างจาก getPostMatchRequests ที่เจ้าของประกาศดูได้อย่างเดียว
  // -----------------------------------------------------
  Future<Map<String, dynamic>> getPostMembers(int postId) async {
    try {
      final response = await _dio.get('$baseUrl/$postId/members');
      return Map<String, dynamic>.from(response.data['data'] ?? {});
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'เกิดข้อผิดพลาดในการดึงรายชื่อสมาชิก',
      );
    }
  }

  // -----------------------------------------------------
  // 🆕 7. เจ้าของประกาศ: อนุมัติ/ปฏิเสธคำขอจับคู่
  // -----------------------------------------------------
  Future<void> respondToMatchRequest(int matchId, String status) async {
    try {
      await _dio.patch(
        '$baseUrl/matches/$matchId',
        data: {'status': status},
      );
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'เกิดข้อผิดพลาดในการตอบรับคำขอจับคู่',
      );
    }
  }

  // -----------------------------------------------------
  // 🆕 6.6 รายการคำขอจับคู่ทั้งหมดที่ฉันเกี่ยวข้อง (ส่งไปเอง + ส่งมาที่ประกาศของฉัน)
  // -----------------------------------------------------
  Future<List<Map<String, dynamic>>> getMyMatchRequests() async {
    try {
      final response = await _dio.get('$baseUrl/my-match-requests');
      return List<Map<String, dynamic>>.from(response.data['data'] ?? []);
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'เกิดข้อผิดพลาดในการดึงรายการแชท',
      );
    }
  }

  // -----------------------------------------------------
  // 🆕 7. ผู้ขอ: ยกเลิกคำขอจับคู่ของตัวเอง (ทำได้เฉพาะตอนยังรอตอบรับ)
  // -----------------------------------------------------
  Future<void> cancelMatchRequest(int matchId) async {
    try {
      await _dio.patch('$baseUrl/matches/$matchId/cancel');
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'เกิดข้อผิดพลาดในการยกเลิกคำขอ',
      );
    }
  }

  // -----------------------------------------------------
  // 🆕 7.5 เปิดแชท 1:1 คุยกันก่อนตอบรับ ("ทักแชท" — เจ้าของประกาศหรือผู้ขอเปิดได้ทั้งคู่)
  // -----------------------------------------------------
  Future<void> openPreChat(int matchId) async {
    try {
      await _dio.post('$baseUrl/matches/$matchId/chat');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'เกิดข้อผิดพลาดในการเปิดแชท');
    }
  }

  // -----------------------------------------------------
  // 🆕 7.6 เจ้าของประกาศ: ยกเลิกการจับคู่ (Unmatch) กับสมาชิกที่จับคู่แล้ว — ประกาศจะเปิดรับ
  // คำขอใหม่อีกครั้งโดยอัตโนมัติ (Post_Status กลับเป็น 'Searching')
  // -----------------------------------------------------
  Future<void> unmatch(int matchId) async {
    try {
      await _dio.patch('$baseUrl/matches/$matchId/unmatch');
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'เกิดข้อผิดพลาดในการยกเลิกการจับคู่',
      );
    }
  }

  // -----------------------------------------------------
  // 🆕 8. เจ้าของประกาศ: ลบประกาศของตัวเอง (ทำได้เฉพาะยังไม่ได้คู่รูมเมทเลย)
  // -----------------------------------------------------
  Future<void> deletePost(int postId) async {
    try {
      await _dio.delete('$baseUrl/$postId');
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'เกิดข้อผิดพลาดในการลบประกาศ',
      );
    }
  }

  // -----------------------------------------------------
  // 🆕 9. เจ้าของประกาศ: แก้ไขเงื่อนไขรูมเมทที่ต้องการ (ไม่แก้หอ/ห้อง — ผูกกับห้องจริงตายตัว)
  // -----------------------------------------------------
  Future<void> updatePost({
    required int postId,
    required int reqPersons,
    required String reqGender,
    required String reqAgeRange,
    required String sleepTime,
    required String smokingAllowed,
    required String petAllowed,
    required String cleanliness,
    String? additionalNotes,
  }) async {
    try {
      await _dio.patch(
        '$baseUrl/$postId',
        data: {
          "Req_Persons": reqPersons,
          "Req_Gender": reqGender,
          "Req_Age_Range": reqAgeRange,
          "Sleep_Time": sleepTime,
          "Smoking_Allowed": smokingAllowed,
          "Pet_Allowed": petAllowed,
          "Cleanliness": cleanliness,
          "Additional_Notes": additionalNotes,
        },
      );
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'เกิดข้อผิดพลาดในการแก้ไขประกาศ',
      );
    }
  }

  // -----------------------------------------------------
  // 🆕 10. เจ้าของประกาศ: จองห้องพักจากประกาศที่จับคู่รูมเมทครบแล้ว (flow หารูมเมทก่อนได้หอ)
  // -----------------------------------------------------
  Future<void> bookFromPost(
    int postId, {
    String? expectedMoveIn,
    String? noteToOwner,
  }) async {
    try {
      await _dio.post(
        '$baseUrl/$postId/book',
        data: {
          if (expectedMoveIn != null) 'expectedMoveIn': expectedMoveIn,
          if (noteToOwner != null) 'noteToOwner': noteToOwner,
        },
      );
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'เกิดข้อผิดพลาดในการจองห้องพัก',
      );
    }
  }
}
