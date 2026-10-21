// 📄 ไฟล์นี้ทำหน้าที่: ตัดสินใจว่าจะโชว์หน้าแรกไหนตาม role ของผู้ใช้ที่ login ไว้
// (เจ้าของหอ -> OwnerMainScreen, อื่นๆ/Guest -> MainScreen) เรียกใช้จาก route '/home'
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/presentation/main_screen.dart';
import '../../features/owner/presentation/owner_main_screen.dart';
import '../auth/role_utils.dart';

class RoleWrapper extends StatelessWidget {
  const RoleWrapper({super.key});

  // ฟังก์ชันดึงข้อมูลใหม่ทุกครั้งที่ GoRouter วิ่งมาหน้านี้
  Future<String> _checkUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // 🚀 บังคับเคลียร์แคชและดึงข้อมูลใหม่ล่าสุดเสมอ
    return prefs.getString('user_role') ?? 'Guest';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _checkUserRole(),
      builder: (context, snapshot) {
        // ระหว่างรอโหลดข้อมูล ให้โชว์หน้าหมุนๆ ไปก่อน
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Colors.teal)),
          );
        }

        final role = snapshot.data ?? 'Guest';

        // เช็คและแยกหน้า ✅ ใส่ ValueKey เพื่อสั่งให้ Flutter วาดหน้าจอใหม่ทิ้งของเก่าทันที
        if (isOwnerRole(role)) {
          // ใช้ UniqueKey() บังคับสร้างหน้าจอใหม่ 100% ทุกครั้งที่เข้ามา
          return OwnerMainScreen(key: UniqueKey());
        } else {
          // ใช้ UniqueKey() บังคับสร้างหน้าจอใหม่ 100% ทุกครั้งที่เข้ามา
          return MainScreen(key: UniqueKey());
        }
      },
    );
  }
}
