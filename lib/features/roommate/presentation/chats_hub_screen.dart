import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:find_dorm_mate/core/widgets/login_required_view.dart';
import 'package:find_dorm_mate/features/auth/data/auth_repository.dart';
import '../data/roommate_repository.dart';
import '../domain/roommate_post_model.dart';

/// หน้า "แชทของฉัน" — กดเข้าจากปุ่มแชทที่หน้าหลัก แยกเป็น 2 แท็บ:
/// 1. แชทเดี่ยว — ห้องแชท 1:1 "ก่อนตอบรับ" ของทุกคำขอจับคู่ที่ฉันเกี่ยวข้อง (ส่งไปเอง +
///    ส่งมาที่ประกาศของฉัน) ไม่ว่าจะยังรอตอบรับ/ตอบรับ/ปฏิเสธ/ยกเลิกไปแล้วก็ตาม
/// 2. รูมเมทที่จับคู่แล้ว — ห้องแชทกลุ่มของประกาศที่มีคนจับคู่ (Matched) อย่างน้อย 1 คนแล้ว
///
/// 🛡️ ต้อง login ก่อนถึงจะเข้าได้ — เป็นชั้นป้องกันสำรอง เผื่อหลุดเข้ามาหน้านี้โดยไม่ผ่าน
/// ปุ่มแชทปกติที่หน้าหลัก (เช่น deep-link จาก push notification ตอน session หมดอายุไปแล้ว
/// พอดี) กันไม่ให้ทั้ง 2 แท็บยิง API ที่ต้อง auth ก่อนรู้ว่า login อยู่หรือเปล่า
class ChatsHubScreen extends StatefulWidget {
  const ChatsHubScreen({super.key});

  @override
  State<ChatsHubScreen> createState() => _ChatsHubScreenState();
}

class _ChatsHubScreenState extends State<ChatsHubScreen> {
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
        title: 'แชทของฉัน',
        message: 'เข้าสู่ระบบเพื่อดูแชทของคุณ',
        icon: Icons.chat_bubble_outline,
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text(
            'แชทของฉัน',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.grey.shade50,
          foregroundColor: Colors.deepPurple,
          elevation: 0,
          centerTitle: true,
          bottom: const TabBar(
            labelColor: Colors.deepPurple,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.deepPurple,
            tabs: [
              Tab(text: 'แชทเดี่ยว'),
              Tab(text: 'รูมเมทที่จับคู่แล้ว'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_SingleChatsTab(), _MatchedChatsTab()],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyState({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            text,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SingleChatsTab extends ConsumerStatefulWidget {
  const _SingleChatsTab();

  @override
  ConsumerState<_SingleChatsTab> createState() => _SingleChatsTabState();
}

class _SingleChatsTabState extends ConsumerState<_SingleChatsTab> {
  final Set<int> _openingIds = {};

  String _displayName(Map<String, dynamic>? member) {
    if (member == null) return 'ผู้ใช้งานทั่วไป';
    final nickname = member['Nickname'];
    if (nickname != null && nickname.toString().trim().isNotEmpty) {
      return nickname.toString();
    }
    final firstName = member['First_Name'] ?? '';
    final lastName = member['Last_Name'] ?? '';
    final fullName = '$firstName $lastName'.trim();
    return fullName.isNotEmpty ? fullName : 'ผู้ใช้งานทั่วไป';
  }

  ({Color bg, Color fg, String label}) _statusInfo(String status) {
    switch (status) {
      case 'Matched':
        return (
          bg: Colors.green.shade50,
          fg: Colors.green.shade700,
          label: 'จับคู่สำเร็จ',
        );
      case 'Rejected':
        return (
          bg: Colors.red.shade50,
          fg: Colors.red.shade600,
          label: 'ปฏิเสธแล้ว',
        );
      case 'Unmatched':
        return (
          bg: Colors.grey.shade200,
          fg: Colors.grey.shade700,
          label: 'ยกเลิกการจับคู่แล้ว',
        );
      case 'Cancelled':
        return (
          bg: Colors.grey.shade200,
          fg: Colors.grey.shade700,
          label: 'ยกเลิกคำขอแล้ว',
        );
      default:
        return (
          bg: Colors.orange.shade50,
          fg: Colors.orange.shade800,
          label: 'รอตอบรับ',
        );
    }
  }

  Future<void> _openChat(Map<String, dynamic> item) async {
    final matchId = item['Match_ID'] as int;
    final otherParty = item['Other_Party'] as Map<String, dynamic>?;
    final name = _displayName(otherParty);
    final image = otherParty?['Profile_Image'] as String?;

    setState(() => _openingIds.add(matchId));
    try {
      await ref.read(roommateRepositoryProvider).openPreChat(matchId);
      if (!mounted) return;
      context.push(
        '/roommate-pre-chat/$matchId',
        extra: {'title': 'แชทกับ $name', 'image': image},
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _openingIds.remove(matchId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(myMatchRequestsProvider);

    return requestsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Colors.deepPurple),
      ),
      error: (error, stack) => Center(
        child: Text(
          'เกิดข้อผิดพลาด: $error',
          style: const TextStyle(color: Colors.red),
        ),
      ),
      data: (requests) {
        if (requests.isEmpty) {
          return const _EmptyState(
            icon: Icons.chat_bubble_outline,
            text: 'ยังไม่มีแชทเดี่ยว\nส่งคำขอจับคู่หรือทักแชทผู้ขอก่อนได้เลย',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.refresh(myMatchRequestsProvider),
          color: Colors.deepPurple,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            itemCount: requests.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = requests[index];
              final matchId = item['Match_ID'] as int;
              final otherParty = item['Other_Party'] as Map<String, dynamic>?;
              final name = _displayName(otherParty);
              final profileImage = otherParty?['Profile_Image'] as String?;
              final isOwner = item['Is_Owner'] == true;
              final dormName = item['Dorm_Name'] as String?;
              final status = item['Match_Status'] as String? ?? 'Pending';
              final statusInfo = _statusInfo(status);
              final isOpening = _openingIds.contains(matchId);
              // 🚀 คุยได้เฉพาะตอนคำขอยังรอตอบรับ (Pending) เท่านั้น — ตอบรับแล้วมีแชทกลุ่ม
              // หลักรองรับแทน (แท็บ "รูมเมทที่จับคู่แล้ว"), ปฏิเสธ/ยกเลิกไปแล้วก็ไม่มีเหตุผล
              // ให้คุยต่อ (backend บล็อกซ้ำอีกชั้นที่ openPreMatchChat อยู่แล้วเช่นกัน)
              final isPending = status == 'Pending';

              return Opacity(
                opacity: isPending ? 1 : 0.6,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: (isOpening || !isPending)
                          ? null
                          : () => _openChat(item),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.deepPurple.shade50,
                              backgroundImage: profileImage != null
                                  ? ResizeImage(
                                      NetworkImage(profileImage),
                                      width: 100,
                                    )
                                  : null,
                              child: profileImage == null
                                  ? Icon(
                                      Icons.person,
                                      color: Colors.deepPurple.shade300,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isOwner
                                        ? 'ผู้ขอร่วมประกาศของคุณ${dormName != null ? ' • $dormName' : ''}'
                                        : 'ประกาศของ$name${dormName != null ? ' • $dormName' : ''}',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusInfo.bg,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    statusInfo.label,
                                    style: TextStyle(
                                      color: statusInfo.fg,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                isOpening
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.deepPurple,
                                        ),
                                      )
                                    : Icon(
                                        isPending
                                            ? Icons.chevron_right
                                            : Icons.lock_outline_rounded,
                                        color: Colors.grey.shade400,
                                        size: isPending ? 24 : 18,
                                      ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _MatchedChatsTab extends ConsumerWidget {
  const _MatchedChatsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownedAsync = ref.watch(myRoommatePostsProvider);
    final matchedAsync = ref.watch(myMatchedRoommatePostsProvider);

    if (ownedAsync.isLoading || matchedAsync.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.deepPurple),
      );
    }
    if (ownedAsync.hasError) {
      return Center(
        child: Text(
          'เกิดข้อผิดพลาด: ${ownedAsync.error}',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }
    if (matchedAsync.hasError) {
      return Center(
        child: Text(
          'เกิดข้อผิดพลาด: ${matchedAsync.error}',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    // 🚀 รวม 2 รายการเข้าด้วยกัน กันซ้ำด้วย Post_ID (เหมือน _ReadyToBookTab ใน
    // my_roommate_matches_screen.dart) เอาเฉพาะประกาศที่มีคนจับคู่แล้วอย่างน้อย 1 คน
    final Map<int, RoommatePostModel> merged = {};
    for (final p in ownedAsync.value ?? const <RoommatePostModel>[]) {
      if (p.matchedCount >= 1) merged[p.postId] = p;
    }
    for (final p in matchedAsync.value ?? const <RoommatePostModel>[]) {
      merged.putIfAbsent(p.postId, () => p);
    }
    final posts = merged.values.toList()
      ..sort(
        (a, b) =>
            (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
      );

    if (posts.isEmpty) {
      return const _EmptyState(
        icon: Icons.groups_2_outlined,
        text:
            'ยังไม่มีแชทกลุ่มรูมเมท\nจับคู่สำเร็จเมื่อไหร่จะเปิดให้แชทที่นี่ทันที',
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myRoommatePostsProvider);
        ref.invalidate(myMatchedRoommatePostsProvider);
      },
      color: Colors.deepPurple,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: posts.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final post = posts[index];
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => context.push(
                  '/roommate-chat/${post.postId}',
                  extra: post.dormName ?? 'แชทกลุ่มรูมเมท',
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.groups_rounded,
                          color: Colors.deepPurple.shade400,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.dormName ?? 'ไม่ระบุหอพัก',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'จับคู่แล้ว ${post.matchedCount}/${post.reqPersons} คน',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.grey.shade400),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
