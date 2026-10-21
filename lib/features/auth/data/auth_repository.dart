// 📄 ไฟล์นี้ทำหน้าที่: ชั้น repository ของระบบยืนยันตัวตนทั้งหมด (login, register, Google
// sign-in, ลืม/เปลี่ยนรหัสผ่าน, กรอกโปรไฟล์ให้ครบ, ผูก session กับ Firebase Auth)
// หน้าจอในโฟลเดอร์ presentation ทุกหน้าเรียกผ่าน authRepositoryProvider เพื่อคุยกับ backend
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:find_dorm_mate/core/config/api_config.dart';
import 'package:find_dorm_mate/core/network/api_client.dart';
import 'package:find_dorm_mate/core/auth/role_utils.dart';
import 'package:find_dorm_mate/core/notifications/push_notification_service.dart';

final authRepositoryProvider = Provider((ref) => AuthRepository());

// 🚀 ดึงโปรไฟล์ตาม Role ที่เก็บไว้ (Owner แยกตาราง/แยก endpoint จาก Member)
// ⚠️ Endpoint นี้ต้อง login ก่อน (ดูข้อมูลได้เฉพาะของตัวเอง) จึงต้องใช้ ApiClient.instance
// เพื่อให้แนบ JWT ไปด้วย ไม่ใช่ Dio() เปล่าๆ เหมือนเดิม
final userProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((
  ref,
) async {
  final prefs = await SharedPreferences.getInstance();
  final memberId = prefs.getInt('member_id');

  if (memberId == null) {
    return null;
  }

  final role = prefs.getString('user_role') ?? 'Member';
  final isOwner = isOwnerRole(role);
  final endpoint = isOwner ? 'owner-profile' : 'profile';

  try {
    final response = await ApiClient.instance.get(
      '${ApiConfig.apiUrl}/auth/$endpoint/$memberId',
    );

    if (response.statusCode == 200) {
      return response.data['data'];
    } else {
      throw Exception('ไม่สามารถดึงข้อมูลได้');
    }
  } catch (e) {
    throw Exception('เกิดข้อผิดพลาดในการเชื่อมต่อ: $e');
  }
});

class AuthRepository {
  final Dio _dio = ApiClient.instance;
  final String baseUrl = '${ApiConfig.apiUrl}/auth';

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _dio.post(
        '$baseUrl/login',
        data: {'email': email, 'password': password},
      );

      final token = response.data['token'];
      final user = response.data['user'];

      if (user == null) {
        throw Exception('ไม่พบข้อมูลผู้ใช้จากเซิร์ฟเวอร์');
      }

      await _saveSession(token: token, user: user);

      return Map<String, dynamic>.from(user);
    } on DioException catch (e) {
      final errorMsg =
          e.response?.data['message'] ?? 'เกิดข้อผิดพลาดในการเชื่อมต่อ';
      throw Exception(errorMsg);
    }
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    String? nickname,
    String? gender,
    String? birthdate,
    String? phone,
    String? userRole,
    String? idCardNo,
    String? profileImage,
    String? idCardImage,
  }) async {
    try {
      await _dio.post(
        '$baseUrl/register',
        data: {
          'username': username,
          'email': email,
          'password': password,
          'firstName': firstName,
          'lastName': lastName,
          'nickname': nickname,
          'gender': gender,
          'birthdate': birthdate,
          'phone': phone,
          'userRole': userRole,
          'idCardNo': idCardNo,
          'profileImage': profileImage,
          'idCardImage': idCardImage,
        },
      );
    } on DioException catch (e) {
      final errorMsg =
          e.response?.data['message'] ?? 'เกิดข้อผิดพลาดในการสมัครสมาชิก';
      throw Exception(errorMsg);
    }
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    return token != null && token.isNotEmpty;
  }

  Future<void> logout() async {
    await PushNotificationService.instance.unregisterToken();

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    try {
      await FirebaseAuth.instance.signOut();
      await FirebaseAuth.instance.signInAnonymously();
    } catch (_) {
      // ไม่ critical พอจะบล็อกการ logout หลัก
    }
  }

  Future<void> _syncFirebaseAuth() async {
    try {
      final response = await _dio.post('$baseUrl/firebase-token');
      final customToken = response.data['token'] as String?;
      if (customToken == null) return;

      await FirebaseAuth.instance.signOut();
      await FirebaseAuth.instance.signInWithCustomToken(customToken);
    } catch (e) {
      // ปล่อยผ่าน — ดูรายละเอียดได้จาก log ฝั่ง backend ถ้าจำเป็น
    }
  }

  Future<void> ensureFirebaseSession() async {
    final hasBackendSession = await isLoggedIn();

    if (hasBackendSession) {
      await _syncFirebaseAuth();
      return;
    }

    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  }

  Future<void> forgotPassword(String email) async {
    try {
      await _dio.post('$baseUrl/forgot-password', data: {'email': email});
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'เกิดข้อผิดพลาด');
    }
  }

  Future<void> resetPassword(int id, String token, String newPassword) async {
    try {
      await _dio.post(
        '$baseUrl/reset-password',
        data: {'id': id, 'token': token, 'newPassword': newPassword},
      );
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'เกิดข้อผิดพลาด หรือลิงก์หมดอายุ',
      );
    }
  }

  // 🚀 แก้ไขข้อมูลส่วนตัว — Backend อ่านตัวตนจาก JWT เอง แยก endpoint ตาม role
  // เพราะ Member (D1) กับ Owner (D2) เป็นคนละตารางที่มีฟิลด์ไม่เหมือนกัน
  Future<Map<String, dynamic>> updateProfile({
    required bool isOwner,
    String? firstName,
    String? lastName,
    String? nickname,
    String? phone,
    String? gender,
    String? birthdate,
    String? profileImage,
  }) async {
    try {
      final endpoint = isOwner ? 'owner-profile' : 'profile';
      final data = {
        if (firstName != null) 'firstName': firstName,
        if (lastName != null) 'lastName': lastName,
        if (phone != null) 'phone': phone,
        if (profileImage != null) 'profileImage': profileImage,
        if (!isOwner && nickname != null) 'nickname': nickname,
        if (!isOwner && gender != null) 'gender': gender,
        if (!isOwner && birthdate != null) 'birthdate': birthdate,
      };

      final response = await _dio.patch('$baseUrl/$endpoint', data: data);
      return Map<String, dynamic>.from(response.data['data']);
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'เกิดข้อผิดพลาดในการแก้ไขข้อมูลส่วนตัว',
      );
    }
  }

  Future<void> changePassword(String oldPassword, String newPassword) async {
    try {
      // 🚀 Backend อ่านตัวตนผู้ใช้จาก JWT token เอง (แนบให้อัตโนมัติผ่าน ApiClient)
      // ไม่ต้องส่ง memberId/accountType มาเองอีกต่อไป
      final response = await _dio.post(
        '$baseUrl/change-password',
        data: {'oldPassword': oldPassword, 'newPassword': newPassword},
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('การเปลี่ยนรหัสผ่านไม่สำเร็จ');
      }
    } on DioException catch (e) {
      if (e.response != null && e.response!.data != null) {
        if (e.response!.data is Map<String, dynamic>) {
          throw Exception(
            e.response!.data['message'] ?? 'เกิดข้อผิดพลาดจากเซิร์ฟเวอร์',
          );
        } else {
          throw Exception('รหัสผ่านเดิมไม่ถูกต้อง หรือเซิร์ฟเวอร์ขัดข้อง');
        }
      } else {
        throw Exception('ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้: ${e.message}');
      }
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดของระบบ: $e');
    }
  }

  // 🚀 กรอกข้อมูลให้ครบหลังล็อกอินด้วย Google ครั้งแรก
  // - ถ้าเป็นผู้ใช้ใหม่เอี่ยม (ไม่มี memberId) จะสร้างบัญชีใหม่ตาม userRole ที่เลือก
  //   (Member ไปตาราง D1, Owner ไปตาราง D2 แยกกันคนละบัญชี)
  // - ถ้ามี memberId (กรณีบัญชี Member เดิมที่กรอกข้อมูลยังไม่ครบ) จะอัปเดตบัญชีเดิม
  Future<Map<String, dynamic>> completeProfile({
    int? memberId,
    String? email,
    String? googleId,
    String? photoUrl,
    String? username,
    String? firstName,
    String? lastName,
    String? nickname,
    String? phone,
    String? gender,
    String? birthdate,
    required String userRole,
    String? idCardNo,
    String? idCardImage,
  }) async {
    try {
      final response = await _dio.post(
        '$baseUrl/complete-profile',
        data: {
          'memberId': memberId,
          'email': email,
          'googleId': googleId,
          'photoUrl': photoUrl,
          'username': username,
          'firstName': firstName,
          'lastName': lastName,
          'nickname': nickname,
          'phone': phone,
          'gender': gender,
          'birthdate': birthdate,
          'userRole': userRole,
          'idCardNo': idCardNo,
          'idCardImage': idCardImage,
        },
      );

      final user = response.data['user'];
      if (user == null) {
        throw Exception('ไม่พบข้อมูลผู้ใช้จากเซิร์ฟเวอร์');
      }

      final token = response.data['token'];
      await _saveSession(token: token, user: user);

      // 🚀 ล้างข้อมูล Google ที่ค้างไว้ชั่วคราว (ใช้แล้วหมดหน้าที่)
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_google_email');
      await prefs.remove('pending_google_id');
      await prefs.remove('pending_google_photo');

      return Map<String, dynamic>.from(user);
    } on DioException catch (e) {
      final errorMsg =
          e.response?.data['message'] ?? 'เกิดข้อผิดพลาดในการอัปเดตโปรไฟล์';
      throw Exception(errorMsg);
    }
  }

  static bool _googleSignInInitialized = false;

  Future<Map<String, dynamic>> loginWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn.instance;
      if (!_googleSignInInitialized) {
        await googleSignIn.initialize(
          serverClientId:
              '806571724387-tidsrjcq1ndhnurlauugnll1j93m73m1.apps.googleusercontent.com',
        );
        _googleSignInInitialized = true;
      }

      // ให้ผู้ใช้เลือกบัญชี Google
      late final GoogleSignInAccount googleUser;
      try {
        googleUser = await googleSignIn.authenticate();
      } on GoogleSignInException catch (e) {
        switch (e.code) {
          case GoogleSignInExceptionCode.canceled:
            throw Exception('ผู้ใช้ยกเลิกการเข้าสู่ระบบด้วย Google');
          case GoogleSignInExceptionCode.providerConfigurationError:
          case GoogleSignInExceptionCode.clientConfigurationError:
            // 🚨 มักเกิดจากอุปกรณ์/อีมูเลเตอร์ไม่มี Google Play Services ที่รองรับ
            // Credential Manager (เช่น อีมูเลเตอร์ใช้อิมเมจ Google APIs แบบเก่าที่ไม่ใช่
            // Google Play จริง) ไม่ใช่บั๊กของโค้ด แนะนำให้ทดสอบบนเครื่องจริงหรืออีมูเลเตอร์
            // ที่ใช้ระบบภาพ "Google Play" ที่อัปเดต Play Services ล่าสุดแล้ว
            throw Exception(
              'ไม่สามารถเชื่อมต่อบริการ Google ได้ในอุปกรณ์นี้ '
              'กรุณาอัปเดต Google Play Services หรือทดลองใช้งานบนเครื่องอื่น',
            );
          default:
            rethrow;
        }
      }

      // ส่งข้อมูลที่ได้จาก Google ไปให้ Backend (Node.js) จัดการต่อ
      final response = await _dio.post(
        '$baseUrl/google-login',
        data: {
          'email': googleUser.email,
          'googleId': googleUser.id,
          'name': googleUser.displayName ?? '',
          'photoUrl': googleUser.photoUrl ?? '',
        },
      );

      final isNewUser = response.data['isNewUser'] ?? false;

      // 🚀 ผู้ใช้ใหม่เอี่ยม: Backend ยังไม่สร้างบัญชีให้ (ยังไม่รู้ว่าจะเป็น Member หรือ Owner)
      // เก็บข้อมูลจาก Google ไว้ชั่วคราว ให้หน้ากรอกโปรไฟล์นำไปสร้างบัญชีจริงต่อ
      if (isNewUser == true) {
        final googleProfile = response.data['googleProfile'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'pending_google_email',
          googleProfile['email'] ?? '',
        );
        await prefs.setString(
          'pending_google_id',
          googleProfile['googleId'] ?? '',
        );
        await prefs.setString(
          'pending_google_photo',
          googleProfile['photoUrl'] ?? '',
        );

        return {'isNewUser': true, 'isProfileCompleted': false, 'user': null};
      }

      final token = response.data['token'];
      final user = response.data['user'];

      if (user == null) {
        throw Exception('ไม่พบข้อมูลผู้ใช้จากเซิร์ฟเวอร์');
      }

      final isProfileCompleted = user['Is_Profile_Completed'] ?? false;

      await _saveSession(token: token, user: user);

      // คืนค่ากลับไปพร้อมสถานะเพื่อบอก UI ว่าต้องพาไปหน้าไหนต่อ
      return {
        'user': user,
        'isNewUser': false,
        'isProfileCompleted': isProfileCompleted,
      };
    } on DioException catch (e) {
      final errorMsg =
          e.response?.data['message'] ??
          'เกิดข้อผิดพลาดในการเชื่อมต่อเซิร์ฟเวอร์';
      throw Exception(errorMsg);
    } catch (e) {
      throw Exception('ไม่สามารถเข้าสู่ระบบด้วย Google ได้: $e');
    }
  }

  // 🚀 เก็บ Token/Session ของผู้ใช้ที่ล็อกอินสำเร็จ (ใช้ร่วมกันทั้ง Member และ Owner)
  // ⚠️ ถ้าไม่มี token แปลว่ายังไม่ได้ล็อกอินจริง (เช่น เจ้าของหอพักสมัครใหม่แต่ยังรอแอดมินอนุมัติ)
  // จึงไม่บันทึกอะไรลง SharedPreferences เลย ป้องกันไม่ให้ RoleWrapper เข้าใจผิดว่าล็อกอินแล้ว
  Future<void> _saveSession({
    String? token,
    required Map<String, dynamic> user,
  }) async {
    if (token == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);

    final memberId = user['Member_ID'];
    if (memberId != null) {
      await prefs.setInt('member_id', int.parse(memberId.toString()));
      // 🚀 ผูก Firebase เข้ากับ Member_ID ทันทีหลัง login สำเร็จ (ระบบแชทรูมเมท)
      // เฉพาะ Member เท่านั้น — Owner ไม่มีสิทธิ์เรียก endpoint นี้ (ไม่ใช้ฟีเจอร์แชท)
      await _syncFirebaseAuth();
    }
    if (user['role'] != null) {
      await prefs.setString('user_role', user['role']);
    }
    if (user['username'] != null) {
      await prefs.setString('username', user['username']);
    }
    if (user['email'] != null) {
      await prefs.setString('email', user['email']);
    }

    // 🆕 ส่ง FCM Token ของเครื่องนี้ไปเก็บที่ backend ทันทีหลัง login สำเร็จ (ทั้ง Member และ
    // Owner — ต่างจาก _syncFirebaseAuth ด้านบนที่เป็น Member เท่านั้น เพราะ Owner ก็ต้องรับ
    // push แจ้งเตือนได้เหมือนกัน เช่น Booking_Created) ไม่ critical ถ้าล้มเหลว — login หลัก
    // ต้องผ่านได้ปกติ แค่เครื่องนี้จะยังไม่ได้รับ push จนกว่าจะลองใหม่ (onTokenRefresh/เปิดแอปใหม่)
    await PushNotificationService.instance.registerToken();
  }
}
