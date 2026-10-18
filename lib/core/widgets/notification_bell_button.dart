import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:find_dorm_mate/features/auth/data/auth_repository.dart';
import 'package:find_dorm_mate/features/notifications/data/notification_repository.dart';

/// ปุ่มกระดิ่งแจ้งเตือน + badge จำนวนที่ยังไม่อ่าน ใช้ใส่ใน AppBar actions ได้ทุกหน้า
/// ตั้ง [floating] เป็น true เพื่อห่อด้วยพื้นหลังวงกลมสีขาว + เงานุ่มนวล สำหรับหน้าที่ไม่มี
/// AppBar ให้พื้นหลังอยู่แล้ว (เช่นหน้า Home ที่ต้องลอยทับเนื้อหาที่เลื่อนอยู่ข้างใต้)
///
/// 🚀 เช็ค login ก่อนเสมอ — ทั้งก่อนกดเข้าหน้าแจ้งเตือน (กันเข้าหน้าที่ต้อง auth ทั้งที่ยังไม่
/// login) และก่อนจะดึงจำนวนที่ยังไม่อ่านมาโชว์ badge (กันยิง API ที่ต้อง auth เปล่าๆ ทุกครั้งที่
/// Guest เปิดหน้า Home แล้วเจอ 401 เงียบๆ)
class NotificationBellButton extends ConsumerStatefulWidget {
  final Color? color;
  final bool floating;

  const NotificationBellButton({super.key, this.color, this.floating = false});

  @override
  ConsumerState<NotificationBellButton> createState() =>
      _NotificationBellButtonState();
}

class _NotificationBellButtonState extends ConsumerState<NotificationBellButton> {
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final isLoggedIn = await AuthRepository().isLoggedIn();
    if (!mounted) return;
    setState(() => _isLoggedIn = isLoggedIn);
  }

  Future<void> _handleTap() async {
    if (!_isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อนดูการแจ้งเตือน')),
      );
      context.push('/login');
      return;
    }

    await context.push('/notifications');
    if (!mounted) return;
    ref.invalidate(unreadNotificationCountProvider);
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _isLoggedIn
        ? (ref.watch(unreadNotificationCountProvider).value ?? 0)
        : 0;

    final bell = Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(Icons.notifications_outlined, color: widget.color),
          tooltip: 'แจ้งเตือน',
          onPressed: _handleTap,
        ),
        if (unreadCount > 0)
          Positioned(
            top: 6,
            right: 6,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  unreadCount > 9 ? '9+' : '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    if (!widget.floating) return bell;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: bell,
    );
  }
}
