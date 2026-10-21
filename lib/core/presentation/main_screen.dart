// 📄 ไฟล์นี้ทำหน้าที่: หน้าหลักของผู้ใช้ทั่วไป/สมาชิก (ไม่ใช่เจ้าของหอ) ครอบ 3 แท็บหลัก
// (หาหอพัก/รูมเมท/โปรไฟล์) ด้วย bottom navigation bar เรียกใช้จาก RoleWrapper
import 'package:find_dorm_mate/features/roommate/presentation/roommate_feed_screen.dart';
import 'package:flutter/material.dart';
import 'package:find_dorm_mate/core/widgets/app_bottom_nav_bar.dart';
// Import ไฟล์หน้าจอต่างๆ ให้ถูกต้อง
import '../../features/dormitory/presentation/home_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';

// สมมติว่าเราสร้างไฟล์ใหม่นี้แล้ว (เดี๋ยวดูโค้ดด้านล่าง)

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // อัปเดตรายการหน้าจอที่จะสลับ
  final List<Widget> _screens = const [
    HomeScreen(),
    RoommateFeedScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: AppBottomNavBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        accentColor: Colors.deepPurple,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: Colors.deepPurple),
            label: 'หาหอพัก',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group, color: Colors.deepPurple),
            label: 'รูมเมท',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: Colors.deepPurple),
            label: 'โปรไฟล์',
          ),
        ],
      ),
    );
  }
}
