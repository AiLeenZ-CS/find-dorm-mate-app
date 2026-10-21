// 📄 ไฟล์นี้ทำหน้าที่: widget สถานะ loading เต็มจอมาตรฐาน
// ใช้ร่วมกันทุกหน้าที่กำลังรอข้อมูลจาก backend
import 'package:flutter/material.dart';

/// สถานะ loading เต็มจอมาตรฐาน ใช้ร่วมกันทุกหน้า
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}
