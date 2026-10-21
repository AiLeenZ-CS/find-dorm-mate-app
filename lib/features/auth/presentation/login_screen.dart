// 📄 ไฟล์นี้ทำหน้าที่: หน้าเข้าสู่ระบบด้วยอีเมล/รหัสผ่าน หรือ Google (สำหรับทั้ง Member และ
// Owner) หลังล็อกอินสำเร็จจะแยกเส้นทางไปหน้าแรกตาม role ที่ backend ส่งกลับมา
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/auth_repository.dart';
import 'package:find_dorm_mate/features/dormitory/data/dorm_repository.dart';
import 'package:find_dorm_mate/core/auth/role_utils.dart';
import 'package:find_dorm_mate/core/widgets/app_text_field.dart';
import 'package:find_dorm_mate/core/widgets/primary_button.dart';
import 'package:find_dorm_mate/core/widgets/soft_card.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submitLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกอีเมลและรหัสผ่าน')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userData = await ref
          .read(authRepositoryProvider)
          .login(_emailController.text.trim(), _passwordController.text);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('เข้าสู่ระบบสำเร็จ! ยินดีต้อนรับ'),
          backgroundColor: Color.fromARGB(255, 78, 148, 46),
          behavior: SnackBarBehavior.floating,
        ),
      );
      final String userRole = userData['role'] ?? 'Guest';

      // 🚀 ล้างแคชของ provider ที่ผูกกับตัวตนผู้ใช้ก่อนเสมอ (เหมือนที่ _logout() ทำ)
      // ป้องกันปัญหา ProfileScreen ค้างข้อมูลเก่า/ว่างเปล่าจากก่อนล็อกอิน เพราะมันถูก
      // eager-build อยู่ใน IndexedStack ของ MainScreen/OwnerMainScreen ตลอดเวลา ทำให้
      // FutureProvider.autoDispose ไม่มีจังหวะเคลียร์ค่าที่ cache ไว้ตอนที่ยังเป็น Guest
      _invalidateUserScopedProviders();

      if (isOwnerRole(userRole)) {
        context.go('/owner-dashboard');
      } else {
        context.go('/');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _invalidateUserScopedProviders() {
    ref.invalidate(userProfileProvider);
    ref.invalidate(ownerDormsProvider);
  }

  Future<void> _submitGoogleLogin() async {
    setState(() => _isLoading = true);
    try {
      final result = await ref.read(authRepositoryProvider).loginWithGoogle();

      if (!mounted) return;

      final bool isNewUser = result['isNewUser'] ?? false;
      final bool isProfileCompleted = result['isProfileCompleted'] ?? false;
      final userData = result['user'];

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('เชื่อมต่อ Google สำเร็จ!'),
          backgroundColor: Color.fromARGB(255, 78, 148, 46),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // 🚀 เช็คตาม Flow: ถ้าโปรไฟล์ยังไม่ครบ หรือเป็นผู้ใช้ใหม่ ให้พาไปหน้ากรอกข้อมูลให้ครบ
      // (ผู้ใช้ใหม่เอี่ยม ยังไม่มี userData เพราะ Backend ยังไม่สร้างบัญชีให้จนกว่าจะรู้ว่าเป็น Member หรือ Owner)
      if (isNewUser || !isProfileCompleted) {
        context.go('/complete-profile');
      } else {
        final String userRole = userData?['role'] ?? 'Guest';
        _invalidateUserScopedProviders();
        if (isOwnerRole(userRole)) {
          context.go('/owner-dashboard');
        } else {
          context.go('/');
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.home_work_rounded, size: 72, color: colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  'Find a Dorm Mate',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                Text(
                  'หาเพื่อนร่วมห้องที่ใช่ ในหอที่ชอบ',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 32),

                SoftCard(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'เข้าสู่ระบบ',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      AppTextField(
                        controller: _emailController,
                        labelText: 'อีเมล',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),

                      AppTextField(
                        controller: _passwordController,
                        labelText: 'รหัสผ่าน',
                        prefixIcon: Icons.lock_outline,
                        isPassword: true,
                      ),
                      const SizedBox(height: 8),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => context.push('/forgot-password'),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'ลืมรหัสผ่าน?',
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      PrimaryButton(
                        label: 'เข้าสู่ระบบ',
                        onPressed: _submitLogin,
                        isLoading: _isLoading,
                      ),
                      const SizedBox(height: 24),

                      Row(
                        children: [
                          Expanded(
                            child: Divider(color: Colors.grey.shade300),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'หรือ',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ),
                          Expanded(
                            child: Divider(color: Colors.grey.shade300),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      OutlinedButton.icon(
                        onPressed: _isLoading ? null : _submitGoogleLogin,
                        icon: Image.network(
                          'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/48px-Google_%22G%22_logo.svg.png',
                          height: 24,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.g_mobiledata,
                            color: colorScheme.primary,
                            size: 28,
                          ),
                        ),
                        label: const Text(
                          'ดำเนินการต่อด้วย Google',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('ยังไม่มีบัญชีใช่ไหม?'),
                    TextButton(
                      onPressed: () => context.push('/register'),
                      child: Text(
                        'สมัครสมาชิกที่นี่',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
