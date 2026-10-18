import 'package:find_dorm_mate/features/auth/data/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:find_dorm_mate/core/auth/role_utils.dart';
import 'package:find_dorm_mate/core/widgets/primary_button.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // 🚪 ฟังก์ชันออกจากระบบ
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'ออกจากระบบ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('คุณแน่ใจหรือไม่ว่าต้องการออกจากระบบ?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            child: const Text('ออกจากระบบ'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // ล้างข้อมูลทั้งหมดในเครื่อง

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ออกจากระบบสำเร็จ')));

        // 🚀 1. ล้างข้อมูลใน Riverpod
        ref.invalidate(userProfileProvider);

        // 🚀 2. เพิ่มบรรทัดนี้! บังคับให้แอปเด้งกลับไปหน้าแรกสุด (Home)
        // เพื่อให้โครงสร้างแอปและแถบเมนู โหลดใหม่กลายเป็นของ "ผู้ใช้ทั่วไป"
        context.go('/');
      }
    }
  }

  // 📝 ฟังก์ชันแปลเพศจาก Database เป็นภาษาไทย
  String _translateGender(String? gender) {
    if (gender == 'Male') return 'ชาย';
    if (gender == 'Female') return 'หญิง';
    if (gender == 'Other') return 'อื่นๆ';
    return gender ?? 'ไม่ระบุ';
  }

  @override
  Widget build(BuildContext context) {
    // เฝ้าดูข้อมูลโปรไฟล์จาก API
    final profileAsyncValue = ref.watch(userProfileProvider);

    return profileAsyncValue.when(
      // ⏳ สถานะกำลังโหลด
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.deepPurple),
        ),
      ),

      // 🚨 สถานะ Error หรือ หาผู้ใช้ไม่เจอ
      error: (error, stack) {
        final errorStr = error.toString();

        // 1. ถ้า Error เกิดจาก 'ไม่พบรหัสผู้ใช้งาน' ให้โชว์หน้า Guest แบบไม่มี AppBar
        if (errorStr.contains('ไม่พบรหัสผู้ใช้งาน') ||
            errorStr.contains('NOT_LOGGED_IN')) {
          return Scaffold(
            backgroundColor: Colors.grey.shade50,
            body: SafeArea(child: _buildGuestPrompt()), // ❌ ไม่ใส่ AppBar
          );
        }

        // 2. ถ้าพังเรื่องอื่น โชว์หน้า Error พร้อมปุ่มออกฉุกเฉิน
        return Scaffold(
          appBar: AppBar(
            title: const Text('เกิดข้อผิดพลาด'),
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 60,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'เกิดข้อผิดพลาด: $error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(userProfileProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('ลองโหลดใหม่'),
                    ),
                    const SizedBox(width: 16),
                    FilledButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('ออกจากระบบ'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },

      // 🟢 สถานะดึงข้อมูลสำเร็จ (หรือ null ตอนไม่ได้ล็อกอิน)
      data: (user) {
        // 1. ถ้ายังไม่เข้าสู่ระบบ (user == null) ให้โชว์หน้า Guest
        if (user == null) {
          return Scaffold(
            backgroundColor: Colors.grey.shade50,
            body: SafeArea(child: _buildGuestPrompt()), // ❌ ไม่ใส่ AppBar
          );
        }

        // 2. ถ้าล็อกอินแล้ว เช็ค Role เพื่อกำหนดสี
        final role = user['User_Role'] ?? user['Role'] ?? 'Member';
        final isOwner = isOwnerRole(role);

        // 🚀 กำหนดสี Theme ตามสิทธิ์ผู้ใช้
        final themeColor = isOwner ? Colors.teal : Colors.deepPurple;

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          // ✅ แสดง AppBar พร้อมเปลี่ยนสีตาม Theme Color แบบ Real-time
          appBar: AppBar(
            title: const Text(
              'โปรไฟล์ของฉัน',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: themeColor,
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
          ),
          body: RefreshIndicator(
            onRefresh: () async => ref.refresh(userProfileProvider.future),
            color: themeColor,
            child: _buildAdvancedUserProfile(user, themeColor, isOwner),
          ),
        );
      },
    );
  }

  // ==========================================
  // 🔴 หน้า UI สำหรับ Guest (ยังไม่ล็อกอิน) ไม่มี AppBar
  // ==========================================
  Widget _buildGuestPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_circle_outlined,
              size: 100,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 24),
            const Text(
              'คุณยังไม่ได้เข้าสู่ระบบ',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'เข้าสู่ระบบเพื่อดูข้อมูลโปรไฟล์\nและจัดการข้อมูลของคุณ',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
            const SizedBox(height: 32),
            PrimaryButton(
              label: 'เข้าสู่ระบบ / สมัครสมาชิก',
              onPressed: () async {
                await context.push('/login');
                ref.invalidate(userProfileProvider);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 🟢 หน้า UI สำหรับ Member/Owner (ล็อกอินแล้ว)
  // ==========================================
  Widget _buildAdvancedUserProfile(
    Map<String, dynamic> user,
    Color themeColor,
    bool isOwner,
  ) {
    final firstName = user['First_Name'] ?? 'ไม่มีชื่อ';
    final lastName = user['Last_Name'] ?? '';
    final fullName = '$firstName $lastName'.trim();
    final email = user['Email'] ?? 'ไม่มีอีเมล';
    final phone = user['Phone'] ?? 'ไม่ระบุเบอร์โทรศัพท์';

    // ✅ เรียกใช้ฟังก์ชันแปลงเพศตรงนี้
    final gender = _translateGender(user['Gender']);

    final String? profileImage = user['Profile_Image'];

    return SingleChildScrollView(
      // 🚀 ต้องระบุ physics แบบนี้เสมอ ไม่งั้นถ้าเนื้อหาพอดีกับความสูงจอ (ไม่ล้น) การลากลงเพื่อ
      // รีเฟรช (RefreshIndicator ที่ห่อ widget นี้อยู่ใน build()) จะไม่ทำงาน
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          // --- 🎨 ส่วนหัว (Header) รูปโปรไฟล์และชื่อ ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(bottom: 30, top: 10),
            decoration: BoxDecoration(
              color: themeColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white,
                  child: CircleAvatar(
                    radius: 46,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage:
                        (profileImage != null && profileImage.isNotEmpty)
                        ? NetworkImage(profileImage)
                        : null,
                    child: (profileImage == null || profileImage.isEmpty)
                        ? Icon(
                            Icons.person,
                            size: 50,
                            color: Colors.grey.shade400,
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  fullName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isOwner ? '👑 เจ้าของหอพัก' : '👤 สมาชิกค้นหาหอพัก',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // --- 📝 ส่วนข้อมูลส่วนตัว ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ข้อมูลติดต่อ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      _buildProfileMenu(Icons.email_outlined, 'อีเมล', email),
                      const Divider(height: 1),
                      _buildProfileMenu(
                        Icons.phone_outlined,
                        'เบอร์โทรศัพท์',
                        phone,
                      ),
                      const Divider(height: 1),
                      _buildProfileMenu(
                        Icons.wc,
                        'เพศ',
                        gender,
                      ), // ✅ ค่าเพศที่แปลแล้วจะแสดงตรงนี้
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // --- ⚙️ ส่วนตั้งค่าและอื่นๆ ---
                const Text(
                  'การตั้งค่า',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      // 🚀 Owner ดู "การจองทั้งหมด" จากแท็บด้านล่างใน OwnerMainScreen แทนแล้ว
                      // (ย้ายออกจากเมนูนี้เพื่อไม่ให้ซ้ำซ้อนกัน) เมนูนี้จึงเหลือไว้ให้ Member เท่านั้น
                      if (!isOwner) ...[
                        _buildActionMenu(
                          Icons.receipt_long_outlined,
                          'การจองของฉัน',
                          () => context.push('/my-bookings'),
                        ),
                        const Divider(height: 1),
                      ],
                      _buildActionMenu(
                        Icons.edit_document,
                        'แก้ไขข้อมูลส่วนตัว',
                        () => context.push(
                          '/edit-profile',
                          extra: {'user': user, 'isOwner': isOwner},
                        ),
                      ),
                      const Divider(height: 1),
                      _buildActionMenu(
                        Icons.lock_outline,
                        'เปลี่ยนรหัสผ่าน',
                        () => context.push('/change-password'), // 🚀 แก้ตรงนี้
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // --- 🚪 ปุ่มออกจากระบบ ---
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text(
                      'ออกจากระบบ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileMenu(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.grey.shade700),
      ),
      title: Text(
        title,
        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildActionMenu(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.black87),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.grey,
      ),
    );
  }
}
