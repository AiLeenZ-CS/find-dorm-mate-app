import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 🚀 หน้าจอ placeholder โชว์แทนเนื้อหาจริง เมื่อผู้ใช้ยังไม่ได้เข้าสู่ระบบแต่หลุดเข้ามาถึงหน้า
/// ที่ต้อง login ก่อน (เช่น แจ้งเตือน, แชท) — ใช้เป็นชั้นป้องกันสำรอง (defense-in-depth) เผื่อ
/// เข้าถึงผ่านทางอื่นนอกจากปุ่มปกติ (เช่น deep-link จาก push notification ที่ session หมดอายุ
/// ไปแล้วพอดี) กันไม่ให้หน้าจอไปยิง API ที่ต้อง auth แล้วเจอ error ดิบๆ ตรงๆ
class LoginRequiredView extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const LoginRequiredView({
    super.key,
    required this.title,
    this.message = 'เข้าสู่ระบบเพื่อใช้งานส่วนนี้',
    this.icon = Icons.lock_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 80, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.push('/login'),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('เข้าสู่ระบบ'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
