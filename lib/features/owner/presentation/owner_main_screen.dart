// 📄 ไฟล์นี้ทำหน้าที่: โครงหน้าหลัก (shell) ฝั่งเจ้าของหอ (owner) คุม bottom navigation
// สลับระหว่าง 3 แท็บ — หอพักของฉัน, การจอง, โปรไฟล์ — คู่กับ main screen ของสมาชิกทั่วไป
import 'package:flutter/material.dart';
import 'package:find_dorm_mate/core/widgets/app_bottom_nav_bar.dart';
import 'package:find_dorm_mate/features/owner/presentation/owner_dashboard_screen.dart';
import 'package:find_dorm_mate/features/booking/presentation/owner_bookings_screen.dart';
import 'package:find_dorm_mate/features/profile/presentation/profile_screen.dart';

class OwnerMainScreen extends StatefulWidget {
  const OwnerMainScreen({super.key});

  @override
  State<OwnerMainScreen> createState() => _OwnerMainScreenState();
}

class _OwnerMainScreenState extends State<OwnerMainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    OwnerDashboardScreen(), // หน้า 1: หอพักของฉัน
    OwnerBookingsScreen(), // หน้า 2: การจองทั้งหมด
    ProfileScreen(), // หน้า 3: โปรไฟล์ (ดึงของเดิมมาใช้ได้เลย)
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: AppBottomNavBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        // 🚀 ใช้โทนเขียว teal คงเดิมสำหรับโหมดเจ้าของหอ แยกจากโทนม่วงของสมาชิกทั่วไป
        // เพื่อให้เห็นชัดว่ากำลังอยู่ในโหมดไหน
        accentColor: Colors.teal,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.apartment_outlined),
            selectedIcon: Icon(Icons.apartment, color: Colors.teal),
            label: 'หอพักของฉัน',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check, color: Colors.teal),
            label: 'การจอง',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: Colors.teal),
            label: 'โปรไฟล์',
          ),
        ],
      ),
    );
  }
}
