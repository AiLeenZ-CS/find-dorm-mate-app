// 📄 ไฟล์นี้ทำหน้าที่: จัดการ Push Notification (Firebase Cloud Messaging) ทั้งหมดของแอป
// ขอ permission, ดึง/ส่ง FCM token ไปเก็บที่ backend, ดักฟังข้อความ และนำทางไปหน้าที่เกี่ยวข้อง
// เมื่อผู้ใช้กดแจ้งเตือน เรียกใช้จาก main.dart และ AuthRepository
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:find_dorm_mate/core/config/api_config.dart';
import 'package:find_dorm_mate/core/network/api_client.dart';
import 'package:find_dorm_mate/core/router/app_router.dart';
import 'package:find_dorm_mate/firebase_options.dart';

/// 🚀 Global key ไว้โชว์ SnackBar จากนอก widget tree (เช่นตอนรับ push ขณะแอปเปิดอยู่ ซึ่งเกิด
/// ขึ้นนอก build context ของหน้าจอใดๆ) ผูกกับ MaterialApp.router(scaffoldMessengerKey: ...)
/// ใน main.dart
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// 🚀 Handler ของข้อความที่มาถึงตอนแอปอยู่เบื้องหลัง/ปิดสนิท — ต้องเป็น top-level function
/// (ห้ามเป็น method ของ class) และมี @pragma('vm:entry-point') กำกับไว้เสมอ เพราะ Flutter
/// รันฟังก์ชันนี้ใน isolate แยกต่างหากจาก UI isolate หลัก (ไม่ใช่ isolate เดียวกับที่ main()
/// รันอยู่) จึงต้อง initializeApp ของ Firebase ใหม่เองในนี้ด้วย ใช้ instance เดิมจาก main()
/// ไม่ได้
///
/// ไม่ต้องเขียนโค้ดโชว์ notification เองในนี้ — ระบบปฏิบัติการ (Android/iOS) จะโชว์บนแถบ
/// แจ้งเตือนให้อัตโนมัติอยู่แล้วตราบใดที่ข้อความมี field "notification" แนบมาด้วย (ซึ่ง
/// backend แนบมาให้เสมอ ดู pushToDevices ใน Backend/src/utils/notifications.ts) handler นี้
/// มีไว้สำหรับ logic เสริมที่อยากทำเงียบๆ เบื้องหลังเท่านั้น (เช่น sync ข้อมูล, log analytics)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint(
    '📩 [FCM Background] ${message.messageId}: '
    '${message.notification?.title ?? message.data['type']}',
  );
}

/// 🚀 รวมทุกอย่างเกี่ยวกับ Push Notification (FCM) ไว้ที่เดียว — ขอ permission, ดึง/ส่ง Token
/// ไปเก็บที่ backend, และดักฟังข้อความทั้ง 3 สถานะ (foreground / กดจาก background / background
/// เงียบๆ) เป็น singleton ธรรมดา (ไม่ผูกกับ Riverpod) เพราะต้องเรียกใช้ตั้งแต่ใน main() ก่อนที่
/// ProviderScope จะพร้อมใช้งาน เหมือนรูปแบบเดียวกับ AuthRepository ที่ใช้อยู่แล้วใน main.dart
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  bool _listenersAttached = false;

  /// 🚀 เรียกครั้งเดียวตอนแอปเริ่มทำงาน (main.dart) — ขอ permission + ติดตั้ง listener ไว้
  /// ก่อนเลย แม้ผู้ใช้จะยังไม่ login ก็ตาม (permission ต้องขอให้เสร็จก่อน ไม่งั้นตอน login
  /// เสร็จแล้วไปขอ token อาจจะยังไม่มีสิทธิ์)
  Future<void> initialize() async {
    await _requestPermission();
    _attachForegroundListeners();

    // 🚀 แอปถูกเปิดขึ้นมาจากการแตะ notification ตอนปิดสนิทอยู่ (cold start) — ต้องเช็คแยก
    // จาก onMessageOpenedApp เพราะ stream นั้นจะไม่ยิง event ย้อนหลังให้กับข้อความที่เป็น
    // ต้นเหตุให้แอปเปิดขึ้นมาตั้งแต่แรก
    try {
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _navigateFromData(initialMessage.data);
      }
    } catch (e) {
      debugPrint('⚠️ Get initial push message failed: $e');
    }

    // 🚀 Token เปลี่ยนเองได้ระหว่างใช้งาน (ย้ายเครื่อง, restore จาก backup, ล้างข้อมูลแอป)
    // ต้องส่งอัปเดตไปเก็บที่ backend ทุกครั้งที่เปลี่ยน ไม่ใช่แค่ตอน login ครั้งแรก
    _messaging.onTokenRefresh.listen(_sendTokenToBackend);
  }

  Future<void> _requestPermission() async {
    try {
      // 🚀 เรียกครั้งเดียวครอบคลุมทั้ง iOS (ต้องขอ permission ก่อนเสมอ) และ Android 13+
      // (API 33 ขึ้นไป ต้องขอ runtime permission POST_NOTIFICATIONS เหมือนกัน — เวอร์ชัน
      // ต่ำกว่านั้น Android อนุญาตอัตโนมัติโดยไม่ต้องถาม) ปลั๊กอินจัดการความต่างระหว่าง
      // แพลตฟอร์มให้หมดแล้วในเรียกเดียวนี้
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('🔔 Notification permission: ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('⚠️ Request notification permission failed: $e');
    }
  }

  void _attachForegroundListeners() {
    if (_listenersAttached) return;
    _listenersAttached = true;

    // 1) ข้อความมาถึงตอนแอปเปิดอยู่พอดี (foreground) — ทั้ง Android และ iOS ไม่โชว์
    // notification บนแถบระบบให้อัตโนมัติในสถานะนี้ ต้องจัดการเอง (โชว์ SnackBar)
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 2) ผู้ใช้แตะ notification ตอนแอปอยู่เบื้องหลัง (ไม่ได้ปิดสนิท) — พากลับเข้าแอปพร้อม
    // deep-link ไปหน้าที่เกี่ยวข้องตาม data['link'] ที่ backend แนบมาด้วยเสมอ
    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _navigateFromData(message.data),
    );
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final title = message.notification?.title ?? message.data['title'];
    final body = message.notification?.body ?? message.data['body'];
    if (title == null && body == null) return;

    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.deepPurple,
        duration: const Duration(seconds: 4),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (body != null)
              Text(body, style: const TextStyle(color: Colors.white)),
          ],
        ),
        action: (message.data['link'] as String?)?.isNotEmpty == true
            ? SnackBarAction(
                label: 'ดู',
                textColor: Colors.amberAccent,
                onPressed: () => _navigateFromData(message.data),
              )
            : null,
      ),
    );
  }

  void _navigateFromData(Map<String, dynamic> data) {
    final link = data['link'] as String?;
    if (link == null || link.isEmpty) return;
    try {
      appRouter.push(link);
    } catch (e) {
      debugPrint('⚠️ Navigate from push notification failed: $e');
    }
  }

  /// 🚀 เรียกหลัง login สำเร็จ (AuthRepository._saveSession) และตอนแอปเปิดขึ้นมาแล้วมี
  /// session เดิมอยู่ (main.dart) — ดึง FCM Token ปัจจุบันของเครื่องนี้แล้วส่งไปเก็บที่ backend
  /// ไม่ throw ออกไปเด็ดขาด เพราะ push เป็นฟีเจอร์เสริม ถ้าทำไม่สำเร็จ login หลักต้องผ่านได้ปกติ
  Future<void> registerToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await _sendTokenToBackend(token);
    } catch (e) {
      debugPrint('⚠️ Register FCM token failed: $e');
    }
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      await ApiClient.instance.post(
        '${ApiConfig.apiUrl}/notifications/save-token',
        data: {
          'fcmToken': token,
          'platform': defaultTargetPlatform == TargetPlatform.iOS
              ? 'ios'
              : 'android',
        },
      );
    } catch (e) {
      debugPrint('⚠️ Save FCM token to backend failed: $e');
    }
  }

  /// 🚀 เรียกตอน logout — ลบ token ของเครื่องนี้ออกจาก backend กันไม่ให้บัญชีเดิมได้รับ push
  /// จากเครื่องที่ออกจากระบบไปแล้ว ไม่ critical ถ้าล้มเหลว (logout หลักต้องผ่านได้ปกติ)
  Future<void> unregisterToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await ApiClient.instance.delete(
        '${ApiConfig.apiUrl}/notifications/device-token',
        data: {'fcmToken': token},
      );
    } catch (e) {
      debugPrint('⚠️ Unregister FCM token failed: $e');
    }
  }
}
