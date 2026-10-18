import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginState();
  }

  Future<void> _checkLoginState() async {
    // หน่วงเวลาให้เห็นหน้า Splash สวยๆ สัก 1.5 วินาที
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    // ✅ ส่งไปที่ /home เสมอ เพื่อให้ Guest ใช้งานแอปได้
    // (เดี๋ยว RoleWrapper ใน /home จะเป็นคนคัดแยกผู้ใช้อีกที)
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.apartment, size: 80, color: colorScheme.onPrimary),
            const SizedBox(height: 16),
            Text(
              'Find a Dorm Mate',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: colorScheme.onPrimary,
              ),
            ),
            const SizedBox(height: 32),
            CircularProgressIndicator(color: colorScheme.onPrimary),
          ],
        ),
      ),
    );
  }
}
