// 📄 ไฟล์นี้ทำหน้าที่: หน้ากรอกอีเมลเพื่อขอลิงก์รีเซ็ตรหัสผ่าน (ใช้ก่อนล็อกอิน สำหรับทั้ง
// Member และ Owner) เรียก AuthRepository.forgotPassword แล้วให้ backend ส่งลิงก์ไปที่อีเมล
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import 'package:find_dorm_mate/core/widgets/app_text_field.dart';
import 'package:find_dorm_mate/core/widgets/primary_button.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submit() async {
    if (_emailController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .forgotPassword(_emailController.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ส่งลิงก์ไปที่อีเมลแล้ว กรุณาตรวจสอบกล่องจดหมาย'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('ลืมรหัสผ่าน'),
        backgroundColor: Colors.grey.shade50,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mark_email_read, size: 72, color: colorScheme.primary),
            const SizedBox(height: 24),
            const Text(
              'กรอกอีเมลที่ใช้ลงทะเบียน\nเราจะส่งลิงก์สำหรับตั้งรหัสผ่านใหม่ไปให้',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            AppTextField(
              controller: _emailController,
              labelText: 'อีเมลของคุณ',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'ส่งลิงก์รีเซ็ตรหัสผ่าน',
              onPressed: _submit,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }
}
