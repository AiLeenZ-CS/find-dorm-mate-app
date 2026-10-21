// 📄 ไฟล์นี้ทำหน้าที่: หน้า "รูมเมทของฉัน" — รวมประกาศของฉัน, ประวัติคำขอจับคู่ที่ฉันเกี่ยวข้อง,
// และประกาศที่จับคู่ได้รูมเมทแล้วพร้อมกดส่งคำขอจองห้อง (3 แท็บ)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/roommate_repository.dart';
import '../domain/roommate_post_model.dart';

/// หน้า "รูมเมทของฉัน" — รวม 3 แท็บ:
/// 1. ประกาศของฉัน (ทุกสถานะ รวมที่จับคู่ครบแล้วและถูกปิดจากหน้ารวมไปแล้ว)
/// 2. ที่ฉันจับคู่ด้วย (ประกาศที่จับคู่สำเร็จ ในฐานะผู้ขอ)
/// 3. จับคู่แล้ว — ประกาศของฉันที่ได้รูมเมทอย่างน้อย 1 คนแล้ว (flow หารูมเมทก่อนได้หอ)
///    กดส่งคำขอจองห้องต่อได้ทันทีที่จับคู่ครบตามจำนวน
/// มีไว้เพื่อให้เจ้าของประกาศ/คนที่จับคู่ด้วย ยังตามดูประกาศนั้นได้เสมอ
/// ถึงแม้จะไม่โชว์ในหน้ารวมแล้วก็ตาม
class MyRoommateMatchesScreen extends StatelessWidget {
  const MyRoommateMatchesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text(
            'รูมเมทของฉัน',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.grey.shade50,
          foregroundColor: Colors.deepPurple,
          elevation: 0,
          centerTitle: true,
          bottom: const TabBar(
            isScrollable: true,
            labelColor: Colors.deepPurple,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.deepPurple,
            tabs: [
              Tab(text: 'ประกาศของฉัน'),
              Tab(text: 'ที่ฉันจับคู่ด้วย'),
              Tab(text: 'จับคู่แล้ว'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_MyPostsTab(), _MyMatchedPostsTab(), _ReadyToBookTab()],
        ),
      ),
    );
  }
}

class _MyPostsTab extends ConsumerWidget {
  const _MyPostsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(myRoommatePostsProvider);

    return postsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: Colors.deepPurple)),
      error: (error, stack) => Center(
        child: Text('เกิดข้อผิดพลาด: $error', style: const TextStyle(color: Colors.red)),
      ),
      data: (posts) {
        if (posts.isEmpty) {
          return const _EmptyState(
            icon: Icons.campaign_outlined,
            text: 'คุณยังไม่เคยสร้างประกาศหารูมเมท',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.refresh(myRoommatePostsProvider),
          color: Colors.deepPurple,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            itemCount: posts.length,
            itemBuilder: (context, index) => _RoommatePostCard(post: posts[index]),
          ),
        );
      },
    );
  }
}

// 🚀 ตัวเลือก filter สถานะที่แท็บ "ที่ฉันจับคู่ด้วย" ใช้ดูประวัติคำขอจับคู่ทั้งหมดของตัวเอง
// ไม่ใช่แค่ที่สำเร็จแล้วอย่างเดียวเหมือนเดิม
const Map<String, String> _matchHistoryFilters = {
  'All': 'ทั้งหมด',
  'Pending': 'รอตอบรับ',
  'Matched': 'จับคู่สำเร็จ',
  'Rejected': 'ถูกปฏิเสธ',
  'Unmatched': 'ถูกยกเลิกจับคู่',
  'Cancelled': 'ที่ยกเลิกเอง',
};

class _MyMatchedPostsTab extends ConsumerStatefulWidget {
  const _MyMatchedPostsTab();

  @override
  ConsumerState<_MyMatchedPostsTab> createState() =>
      _MyMatchedPostsTabState();
}

class _MyMatchedPostsTabState extends ConsumerState<_MyMatchedPostsTab> {
  String _statusFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(myMatchHistoryProvider(_statusFilter));

    return Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: postsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: Colors.deepPurple),
            ),
            error: (error, stack) => Center(
              child: Text(
                'เกิดข้อผิดพลาด: $error',
                style: const TextStyle(color: Colors.red),
              ),
            ),
            data: (posts) {
              if (posts.isEmpty) {
                return _EmptyState(
                  icon: Icons.diversity_3_outlined,
                  text: _statusFilter == 'All'
                      ? 'ยังไม่มีประวัติคำขอจับคู่'
                      : 'ไม่มีประวัติในสถานะนี้',
                );
              }
              return RefreshIndicator(
                onRefresh: () async =>
                    ref.refresh(myMatchHistoryProvider(_statusFilter)),
                color: Colors.deepPurple,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  itemCount: posts.length,
                  itemBuilder: (context, index) =>
                      _RoommatePostCard(post: posts[index]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _matchHistoryFilters.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final entry = _matchHistoryFilters.entries.elementAt(index);
            final isSelected = _statusFilter == entry.key;
            return ChoiceChip(
              label: Text(entry.value),
              selected: isSelected,
              showCheckmark: false,
              onSelected: (_) => setState(() => _statusFilter = entry.key),
              backgroundColor: Colors.grey.shade100,
              selectedColor: Colors.deepPurple.shade50,
              labelStyle: TextStyle(
                color: isSelected ? Colors.deepPurple : Colors.grey.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? Colors.deepPurple : Colors.transparent,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 🚀 แท็บ "จับคู่แล้ว" — รวมประกาศที่มีคนจับคู่ (Matched) แล้วอย่างน้อย 1 คน ทั้งฝั่ง
/// เจ้าของประกาศเอง (myRoommatePostsProvider) และฝั่งสมาชิกที่จับคู่เข้าไปอยู่ในประกาศ
/// ของคนอื่น (myMatchedRoommatePostsProvider) ไม่ใช่แค่เจ้าของประกาศเห็นฝ่ายเดียวเหมือนเดิม
/// ให้ทุกคนในกลุ่มตามความคืบหน้าได้ ส่วนปุ่มส่งคำขอจองจะ enable เฉพาะเจ้าของประกาศตอน
/// จับคู่ครบตามจำนวนที่ประกาศไว้แล้ว (post.readyToBook)
class _ReadyToBookTab extends ConsumerWidget {
  const _ReadyToBookTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownedAsync = ref.watch(myRoommatePostsProvider);
    final matchedAsync = ref.watch(myMatchedRoommatePostsProvider);

    if (ownedAsync.isLoading || matchedAsync.isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
    }
    if (ownedAsync.hasError) {
      return Center(
        child: Text('เกิดข้อผิดพลาด: ${ownedAsync.error}', style: const TextStyle(color: Colors.red)),
      );
    }
    if (matchedAsync.hasError) {
      return Center(
        child: Text('เกิดข้อผิดพลาด: ${matchedAsync.error}', style: const TextStyle(color: Colors.red)),
      );
    }

    // 🚀 รวม 2 รายการเข้าด้วยกัน กันซ้ำด้วย Post_ID (ไม่มีทางซ้ำจริงอยู่แล้ว เพราะห้ามส่ง
    // คำขอจับคู่ประกาศของตัวเอง แต่กันไว้เผื่อ edge case)
    final Map<int, RoommatePostModel> merged = {};
    for (final p in ownedAsync.value ?? const <RoommatePostModel>[]) {
      if (p.matchedCount >= 1) merged[p.postId] = p;
    }
    for (final p in matchedAsync.value ?? const <RoommatePostModel>[]) {
      merged.putIfAbsent(p.postId, () => p);
    }
    final posts = merged.values.toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));

    if (posts.isEmpty) {
      return const _EmptyState(
        icon: Icons.groups_2_outlined,
        text: 'ยังไม่มีประกาศที่จับคู่รูมเมทได้เลย',
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myRoommatePostsProvider);
        ref.invalidate(myMatchedRoommatePostsProvider);
      },
      color: Colors.deepPurple,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: posts.length,
        itemBuilder: (context, index) =>
            _BookableRoommatePostCard(post: posts[index]),
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

class _RoommatePostCard extends StatelessWidget {
  final RoommatePostModel post;

  const _RoommatePostCard({required this.post});

  ({String label, Color bg, Color text}) _statusInfo(String status) {
    switch (status) {
      case 'Found':
        return (label: 'จับคู่แล้ว', bg: Colors.green.shade50, text: Colors.green.shade700);
      default:
        return (label: 'กำลังหา', bg: Colors.orange.shade50, text: Colors.orange.shade800);
    }
  }

  // 🚀 สถานะคำขอจับคู่ "ของฉัน" กับประกาศนี้โดยเฉพาะ (ใช้ที่แท็บ "ที่ฉันจับคู่ด้วย" เท่านั้น —
  // post.myMatchStatus มีค่าเฉพาะตอนดึงผ่าน getMyMatchedPosts) ต่างจาก _statusInfo ด้านบนที่
  // เป็นสถานะของตัวประกาศเอง (ใช้ที่แท็บ "ประกาศของฉัน" ซึ่งเจ้าของประกาศไม่มี myMatchStatus)
  ({String label, Color bg, Color text}) _myMatchStatusInfo(String status) {
    switch (status) {
      case 'Pending':
        return (label: 'รอตอบรับ', bg: Colors.orange.shade50, text: Colors.orange.shade800);
      case 'Matched':
        return (label: 'จับคู่สำเร็จ', bg: Colors.green.shade50, text: Colors.green.shade700);
      case 'Rejected':
        return (label: 'ถูกปฏิเสธ', bg: Colors.red.shade50, text: Colors.red.shade600);
      case 'Unmatched':
        return (label: 'ถูกยกเลิกจับคู่', bg: Colors.grey.shade200, text: Colors.grey.shade700);
      case 'Cancelled':
        return (label: 'คุณยกเลิกคำขอ', bg: Colors.grey.shade200, text: Colors.grey.shade700);
      default:
        return (label: status, bg: Colors.grey.shade200, text: Colors.grey.shade700);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myMatchStatus = post.myMatchStatus;
    final status = myMatchStatus != null
        ? _myMatchStatusInfo(myMatchStatus)
        : _statusInfo(post.postStatus);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push('/roommate-detail', extra: post),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.deepPurple.shade50,
                  backgroundImage: post.memberImage != null
                      ? ResizeImage(NetworkImage(post.memberImage!), width: 120)
                      : null,
                  child: post.memberImage == null
                      ? Icon(Icons.person, color: Colors.deepPurple.shade300, size: 28)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.memberName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        post.dormName ?? 'ไม่ระบุหอพัก',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: status.bg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.label,
                    style: TextStyle(
                      color: status.text,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 🚀 การ์ดในแท็บ "จับคู่แล้ว" — โชว์รายชื่อสมาชิกทั้งหมดในกลุ่ม (เจ้าของ + คนที่จับคู่แล้ว)
/// + ความคืบหน้าการจับคู่ + ปุ่มส่งคำขอจอง (เฉพาะเจ้าของประกาศกดได้ enable ตอนจับคู่ครบแล้ว/
/// ยังไม่เคยจอง — สมาชิกคนอื่นเห็นแค่สถานะ) + ปุ่มแชท (placeholder รอทำทีหลังตามที่ตกลงไว้)
class _BookableRoommatePostCard extends ConsumerStatefulWidget {
  final RoommatePostModel post;

  const _BookableRoommatePostCard({required this.post});

  @override
  ConsumerState<_BookableRoommatePostCard> createState() =>
      _BookableRoommatePostCardState();
}

class _BookableRoommatePostCardState
    extends ConsumerState<_BookableRoommatePostCard> {
  bool _isBooking = false;
  int? _currentMemberId;

  RoommatePostModel get post => widget.post;
  bool get _isOwner =>
      _currentMemberId != null && _currentMemberId == post.memberId;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _currentMemberId = prefs.getInt('member_id'));
  }

  Future<void> _confirmBook() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'ยืนยันการจองห้องพัก',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'ระบบจะกันห้องนี้ไว้ให้คุณทันที และรอเจ้าของหอยืนยันภายใน 3 วัน '
          'หากเกินเวลาหรือเจ้าของหอปฏิเสธ ห้องจะถูกคืนสต๊อกให้ผู้อื่นจองต่อโดยอัตโนมัติ',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ยืนยันจอง'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isBooking = true);
    try {
      await ref.read(roommateRepositoryProvider).bookFromPost(post.postId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('จองห้องพักสำเร็จ! รอเจ้าของหอยืนยันภายใน 3 วัน'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      ref.invalidate(myRoommatePostsProvider);
      context.push('/my-bookings');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  void _handleChatTap() {
    context.push(
      '/roommate-chat/${post.postId}',
      extra: post.dormName ?? 'แชทกลุ่มรูมเมท',
    );
  }

  Widget _staticStatusChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.grey.shade600,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reqPersons = post.reqPersons;
    final matchedCount = post.matchedCount;
    final isFull = post.postStatus == 'Found';
    final alreadyBooked = post.bookingId != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.push('/roommate-detail', extra: post),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.apartment, color: Colors.deepPurple.shade400),
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
                        post.roomTypeName ?? 'ไม่ระบุห้องพัก',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
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
          const SizedBox(height: 14),
          _MemberRoster(postId: post.postId),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isFull ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  isFull ? Icons.celebration_outlined : Icons.groups_outlined,
                  color: isFull ? Colors.green.shade700 : Colors.orange.shade800,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'จับคู่รูมเมทแล้ว $matchedCount/$reqPersons คน',
                    style: TextStyle(
                      color: isFull ? Colors.green.shade800 : Colors.orange.shade900,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: alreadyBooked
                    ? _staticStatusChip('จองห้องแล้ว')
                    : !_isOwner
                    // 🚀 สมาชิกที่จับคู่ด้วย (ไม่ใช่เจ้าของประกาศ) กดส่งคำขอจองเองไม่ได้ —
                    // ต้องรอเจ้าของประกาศเป็นคนกดจองแทนทั้งกลุ่ม
                    ? _staticStatusChip(
                        post.readyToBook ? 'รอเจ้าของประกาศกดจอง' : 'รอจับคู่ให้ครบ',
                      )
                    : FilledButton.icon(
                        onPressed: (post.readyToBook && !_isBooking)
                            ? _confirmBook
                            : null,
                        icon: _isBooking
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.event_available_rounded, size: 18),
                        label: Text(
                          _isBooking
                              ? 'กำลังจอง...'
                              : (post.readyToBook ? 'ส่งคำขอจอง' : 'รอจับคู่ให้ครบ'),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _handleChatTap,
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text(
                    'แชท',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.deepPurple,
                    side: const BorderSide(color: Colors.deepPurple),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 🚀 แถวรูปสมาชิกในกลุ่ม (เจ้าของ + คนที่จับคู่แล้ว) — ดึงจาก postMembersProvider ซึ่งเข้าถึง
/// ได้ทั้งเจ้าของประกาศและสมาชิกที่จับคู่ด้วย (ต่างจาก postMatchRequestsProvider ที่เจ้าของ
/// ประกาศดูได้อย่างเดียว และมีข้อมูลผู้สมัครที่ยัง Pending/Rejected ปนอยู่ด้วย)
class _MemberRoster extends ConsumerWidget {
  final int postId;

  const _MemberRoster({required this.postId});

  String _displayName(Map<String, dynamic> m) {
    final nickname = m['Nickname'];
    if (nickname != null && nickname.toString().trim().isNotEmpty) {
      return nickname.toString();
    }
    final firstName = m['First_Name'];
    if (firstName != null && firstName.toString().trim().isNotEmpty) {
      return firstName.toString();
    }
    return 'สมาชิก';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(postMembersProvider(postId));

    return membersAsync.when(
      loading: () => const SizedBox(
        height: 56,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepPurple),
          ),
        ),
      ),
      error: (error, stack) => const SizedBox.shrink(),
      data: (data) {
        final owner = data['owner'] as Map<String, dynamic>?;
        final members = List<Map<String, dynamic>>.from(data['members'] ?? []);

        final roster = <Map<String, dynamic>>[
          if (owner != null) {...owner, 'isOwner': true},
          ...members.map((m) => {...m, 'isOwner': false}),
        ];

        if (roster.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 60,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: roster.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final m = roster[index];
              final name = _displayName(m);
              final image = m['Profile_Image'] as String?;
              final isOwner = m['isOwner'] == true;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.deepPurple.shade50,
                        backgroundImage: image != null
                            ? ResizeImage(NetworkImage(image), width: 80)
                            : null,
                        child: image == null
                            ? Icon(
                                Icons.person,
                                color: Colors.deepPurple.shade300,
                                size: 18,
                              )
                            : null,
                      ),
                      if (isOwner)
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.amber,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.star,
                              size: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 48,
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
