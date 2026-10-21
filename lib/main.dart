// 📄 ไฟล์นี้ทำหน้าที่: จุดเริ่มต้น (entry point) ของแอปฝั่งผู้ใช้/เจ้าของหอ — เซ็ตอัป Firebase,
// ผูก session เดิม (ถ้ามี), เริ่มระบบ push notification, แล้วสร้าง MaterialApp.router หลักที่ครอบ
// ทั้งแอปด้วย ProviderScope (Riverpod) และ appRouter (go_router)
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/router/app_router.dart';
import 'features/auth/data/auth_repository.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 🚀 ต้องลงทะเบียน background handler ก่อน runApp เสมอ (ข้อกำหนดของ firebase_messaging)
  // ดูรายละเอียดว่าทำงานยังไงที่คอมเมนต์ของฟังก์ชันนี้ใน push_notification_service.dart
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // 🚀 ถ้ามี session ของ backend อยู่แล้ว (เปิดแอปใหม่โดยไม่ได้ logout) ผูก Firebase เข้ากับ
  // Member_ID ทันที ไม่ใช่ anonymous เฉยๆ เหมือนเดิม — ให้ระบบแชทรูมเมทใช้งานได้ทันทีที่เปิดแอป
  await AuthRepository().ensureFirebaseSession();

  // 🆕 ขอ permission + ติดตั้ง listener แจ้งเตือนทั้ง 3 สถานะไว้ก่อนเลย แล้วถ้ามี session
  // เดิมอยู่ (เปิดแอปใหม่โดยไม่ได้ logout) ส่ง FCM Token ของเครื่องนี้ไปอัปเดตที่ back-end ทันที
  // (กรณี login ครั้งใหม่ อีกจุดคือ AuthRepository._saveSession เป็นคนเรียกแทน)
  await PushNotificationService.instance.initialize();
  if (await AuthRepository().isLoggedIn()) {
    await PushNotificationService.instance.registerToken();
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Find a Dorm Mate',
      // 🚀 ปิดริบบิ้น "DEBUG" มุมขวาบน — ชนกับปุ่มแจ้งเตือนที่ลอยอยู่มุมเดียวกัน
      // (ไม่โชว์ใน release build อยู่แล้ว แค่กวนตาตอน dev/debug)
      debugShowCheckedModeBanner: false,
      // 🆕 ให้ PushNotificationService โชว์ SnackBar ได้จากนอก widget tree (ตอนรับ push
      // ขณะแอปเปิดอยู่ ซึ่งไม่มี BuildContext ของหน้าจอใดๆ ให้ใช้)
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      routerConfig: appRouter,
    );
  }
}
