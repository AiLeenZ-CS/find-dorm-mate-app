// 📄 ไฟล์นี้ทำหน้าที่: หน้ารวมแจ้งเตือนทั้งหมด ใช้ร่วมกันทั้ง Member และ Owner (แยกข้อมูลที่
// backend ให้แล้ว ฝั่ง UI ไม่ต้องรู้ role) กดเพื่ออ่านและนำทางต่อไปตาม link ของแจ้งเตือนนั้น
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:find_dorm_mate/core/widgets/login_required_view.dart';
import 'package:find_dorm_mate/features/auth/data/auth_repository.dart';
import '../data/notification_repository.dart';
import '../domain/notification_model.dart';

/// หน้ารวมแจ้งเตือนในแอป — ใช้ร่วมกันทั้ง Member และ Owner (แยกข้อมูลกันที่ backend ผ่าน
/// Recipient_Type/Recipient_ID อยู่แล้ว ฝั่ง UI ไม่ต้องรู้ว่าใครเป็นใคร)
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _isMarkingAll = false;
  bool? _isLoggedIn; // null = ยังเช็คไม่เสร็จ

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

  Future<void> _handleMarkAllRead() async {
    setState(() => _isMarkingAll = true);
    try {
      await ref.read(notificationRepositoryProvider).markAllAsRead();
      ref.invalidate(notificationListProvider);
      ref.invalidate(unreadNotificationCountProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isMarkingAll = false);
    }
  }

  Future<void> _handleTapNotification(AppNotification notification) async {
    if (!notification.isRead) {
      ref.read(notificationRepositoryProvider).markAsRead(notification.id).then(
        (_) {
          ref.invalidate(notificationListProvider);
          ref.invalidate(unreadNotificationCountProvider);
        },
      );
    }

    final link = notification.link;
    if (link != null && link.isNotEmpty && mounted) {
      context.push(link);
    }
  }

  IconData _iconForType(String type) {
    if (type.startsWith('Booking')) return Icons.event_available_rounded;
    if (type.startsWith('Match') || type == 'Post_Fully_Matched') {
      return Icons.people_alt_rounded;
    }
    if (type.startsWith('Owner')) return Icons.verified_user_rounded;
    if (type.startsWith('Dorm')) return Icons.apartment_rounded;
    return Icons.notifications_rounded;
  }

  Color _colorForType(String type) {
    if (type.contains('Rejected')) return Colors.red;
    if (type.contains('Confirmed') ||
        type.contains('Approved') ||
        type.contains('Matched')) {
      return Colors.green;
    }
    if (type.contains('Expired')) return Colors.orange;
    return Colors.deepPurple;
  }

  String _formatRelativeTime(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'เมื่อสักครู่';
    if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
    if (diff.inHours < 24) return '${diff.inHours} ชั่วโมงที่แล้ว';
    if (diff.inDays < 7) return '${diff.inDays} วันที่แล้ว';
    return DateFormat('d MMM yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoggedIn == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.deepPurple),
        ),
      );
    }
    if (_isLoggedIn == false) {
      return const LoginRequiredView(
        title: 'แจ้งเตือน',
        message: 'เข้าสู่ระบบเพื่อดูการแจ้งเตือนของคุณ',
        icon: Icons.notifications_off_outlined,
      );
    }

    final notificationsAsync = ref.watch(notificationListProvider);
    final hasUnread = notificationsAsync.value?.any((n) => !n.isRead) ?? false;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'แจ้งเตือน',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        centerTitle: true,
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: _isMarkingAll ? null : _handleMarkAllRead,
              child: _isMarkingAll
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('อ่านทั้งหมด'),
            ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.deepPurple),
        ),
        error: (error, stack) => Center(
          child: Text(
            'เกิดข้อผิดพลาด: $error',
            style: const TextStyle(color: Colors.red),
          ),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ยังไม่มีการแจ้งเตือน',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notificationListProvider);
              ref.invalidate(unreadNotificationCountProvider);
            },
            color: Colors.deepPurple,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final notification = notifications[index];
                final accent = _colorForType(notification.type);

                return Material(
                  color: notification.isRead
                      ? Colors.white
                      : accent.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _handleTapNotification(notification),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _iconForType(notification.type),
                              color: accent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  notification.title,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: notification.isRead
                                        ? FontWeight.w600
                                        : FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                if ((notification.body ?? '').isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    notification.body!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Text(
                                  _formatRelativeTime(notification.createdAt),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(top: 4, left: 4),
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
