// 📄 ไฟล์นี้ทำหน้าที่: สร้าง Dio instance กลางของทั้งแอป ใช้เป็น HTTP client หลักในการเรียก
// backend API ทุกจุด พร้อมแนบ JWT token ให้ทุก request โดยอัตโนมัติ
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 🚀 Dio instance เดียวที่ใช้ร่วมกันทั้งแอป แนบ JWT (Authorization: Bearer ...) ให้ทุก
// request โดยอัตโนมัติ
// (ก่อนหน้านี้แต่ละ repository สร้าง Dio() ของตัวเองแยกกัน และไม่มีที่ไหนแนบ Authorization
// header เลยสักจุด ทำให้ token ที่เก็บไว้ตอน login ไม่เคยถูกใช้จริง — endpoint ที่ backend
// เพิ่งเปลี่ยนให้ต้อง login ก่อน (เช่น สร้างหอพัก/เข้าคิว/โพสต์หารูมเมท) จะใช้งานไม่ได้ถ้าไม่มี Dio
// กลางตัวนี้)
class ApiClient {
  ApiClient._();

  static final Dio instance = _create();

  static Dio _create() {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('jwt_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
    return dio;
  }
}
