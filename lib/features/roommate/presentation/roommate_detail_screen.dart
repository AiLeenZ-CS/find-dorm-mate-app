import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/roommate_post_model.dart';
import '../data/roommate_repository.dart';
import 'package:intl/intl.dart';

class RoommateDetailScreen extends ConsumerStatefulWidget {
  final RoommatePostModel post;

  const RoommateDetailScreen({super.key, required this.post});

  @override
  ConsumerState<RoommateDetailScreen> createState() =>
      _RoommateDetailScreenState();
}

class _RoommateDetailScreenState extends ConsumerState<RoommateDetailScreen> {
  int? _currentMemberId;
  bool _isLoadingSession = true;
  bool _isDeleting = false;
  bool _isCancellingRequest = false;

  // 🚀 เก็บเป็น state แยก (ไม่ใช้ widget.post ตรงๆ) เพื่อให้หน้านี้อัปเดตข้อมูลได้ทันทีหลัง
  // แก้ไขประกาศสำเร็จ โดยไม่ต้องปิดหน้าแล้วเปิดใหม่
  late RoommatePostModel _post;
  RoommatePostModel get post => _post;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _loadSession();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _currentMemberId = prefs.getInt('member_id');
      _isLoadingSession = false;
    });
  }

  Future<void> _handleEditPost() async {
    final updated = await context.push<RoommatePostModel>(
      '/edit-roommate-post',
      extra: post,
    );
    if (updated == null || !mounted) return;
    setState(() => _post = updated);
    ref.invalidate(roommateListProvider);
    ref.invalidate(roommateListByDormProvider);
    ref.invalidate(myRoommatePostsProvider);
  }

  Future<void> _confirmDeletePost() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'ลบประกาศหารูมเมท',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'คุณแน่ใจหรือไม่ว่าต้องการลบประกาศนี้? การลบไม่สามารถย้อนกลับได้',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ปิด', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            child: const Text('ยืนยันลบ'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);
    try {
      await ref.read(roommateRepositoryProvider).deletePost(post.postId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ลบประกาศสำเร็จ'),
          backgroundColor: Colors.green,
        ),
      );
      ref.invalidate(myRoommatePostsProvider);
      ref.invalidate(roommateListProvider);
      ref.invalidate(roommateListByDormProvider);
      // 🚀 ประกาศนี้ไม่มีอยู่จริงแล้ว ปิดหน้ารายละเอียดกลับไปที่หน้ารวม/ประกาศของฉัน
      if (context.canPop()) context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  Future<void> _handleSendRequest() async {
    if (_currentMemberId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเข้าสู่ระบบก่อนส่งคำขอจับคู่'),
          backgroundColor: Colors.orange,
        ),
      );
      context.push('/login');
      return;
    }

    final messageController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'ส่งคำขอจับคู่',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ส่งข้อความแนะนำตัวสั้นๆ ให้ ${post.memberName} (ไม่บังคับ)',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: messageController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'เช่น สวัสดีครับ สนใจร่วมห้องด้วยคนครับ',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.deepPurple),
            child: const Text('ส่งคำขอ'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref
          .read(roommateRepositoryProvider)
          .sendMatchRequest(
            post.postId,
            message: messageController.text.trim().isEmpty
                ? null
                : messageController.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ส่งคำขอจับคู่สำเร็จ! รอเจ้าของประกาศตอบรับ'),
          backgroundColor: Colors.green,
        ),
      );
      ref.invalidate(myMatchRequestStatusProvider(post.postId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 🚀 ผู้ขอยกเลิกคำขอจับคู่ของตัวเองก่อนที่เจ้าของประกาศจะตอบรับ/ปฏิเสธ (ยังเป็น Pending
  // อยู่เท่านั้น) — หลังยกเลิกจะกลับไปกดส่งคำขอใหม่ได้อีกถ้าเปลี่ยนใจ
  Future<void> _cancelMyRequest(int matchId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'ยกเลิกคำขอจับคู่',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('คุณแน่ใจหรือไม่ว่าต้องการยกเลิกคำขอจับคู่นี้?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ปิด', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            child: const Text('ยืนยันยกเลิก'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isCancellingRequest = true);
    try {
      await ref.read(roommateRepositoryProvider).cancelMatchRequest(matchId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ยกเลิกคำขอจับคู่สำเร็จ'),
          backgroundColor: Colors.green,
        ),
      );
      ref.invalidate(myMatchRequestStatusProvider(post.postId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCancellingRequest = false);
    }
  }

  String _translate(String type, String value) {
    switch (type) {
      case 'Gender':
        if (value == 'Male') return 'ชาย';
        if (value == 'Female') return 'หญิง';
        return 'ไม่จำกัดเพศ';
      case 'Sleep':
        if (value == 'Before midnight') return 'นอนก่อนเที่ยงคืน';
        if (value == 'After midnight') return 'นอนดึกได้';
        return 'เวลานอนไม่จำกัด';
      case 'Smoke':
        if (value == 'Smoking') return 'สูบบุหรี่ได้';
        if (value == 'Non_Smoking') return 'ไม่สูบบุหรี่';
        return 'เรื่องบุหรี่ไม่ซีเรียส';
      case 'Pet':
        if (value == 'Pet_Friendly') return 'รักสัตว์/เลี้ยงได้';
        if (value == 'No_Pets') return 'ไม่สะดวกเลี้ยงสัตว์';
        return 'เรื่องสัตว์ไม่ซีเรียส';
      case 'Clean':
        if (value == 'Very') return 'รักความสะอาดมาก';
        if (value == 'Normal') return 'สะอาดปานกลาง';
        if (value == 'Easy') return 'รกได้นิดหน่อย';
        return 'เรื่องความสะอาดชิลๆ';
      default:
        return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    String datePosted = '';
    if (post.createdAt != null) {
      datePosted = DateFormat('dd MMM yyyy, HH:mm').format(post.createdAt!);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // สีพื้นหลังเทาอ่อนๆ สบายตา
      appBar: AppBar(
        title: const Text(
          'รายละเอียดประกาศ',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        backgroundColor: const Color(0xFFF8F9FA),
        foregroundColor: Colors.deepPurple,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. ส่วนหัว: ข้อมูลผู้โพสต์ ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.deepPurple.shade50,
                        width: 4,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 48,
                      backgroundColor: Colors.deepPurple.shade50,
                      backgroundImage: post.memberImage != null
                          ? NetworkImage(post.memberImage!)
                          : null,
                      child: post.memberImage == null
                          ? Icon(
                              Icons.person,
                              color: Colors.deepPurple.shade300,
                              size: 48,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    post.memberName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          post.memberGender == 'Male'
                              ? 'เพศชาย'
                              : post.memberGender == 'Female'
                              ? 'เพศหญิง'
                              : 'ไม่ระบุเพศ',
                          style: TextStyle(
                            color: Colors.deepPurple.shade700,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (post.hasRoomAlready)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_rounded,
                                color: Colors.teal.shade700,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'มีห้องแล้ว',
                                style: TextStyle(
                                  color: Colors.teal.shade700,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'โพสต์เมื่อ: $datePosted',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // --- 2. เงื่อนไขที่ต้องการหา ---
            _buildSectionTitle('คุณสมบัติรูมเมทที่มองหา'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildInfoRow(
                    Icons.person_add,
                    'จำนวนที่หาเพิ่ม',
                    '${post.reqPersons} คน',
                  ),
                  _buildDivider(),
                  _buildInfoRow(
                    Icons.wc,
                    'เพศ',
                    _translate('Gender', post.reqGender),
                  ),
                  _buildDivider(),
                  _buildInfoRow(
                    Icons.cake,
                    'ช่วงอายุ',
                    post.reqAgeRange == 'Any'
                        ? 'ไม่จำกัด'
                        : '${post.reqAgeRange} ปี',
                  ),
                  _buildDivider(),
                  _buildInfoRow(
                    Icons.bedtime,
                    'เวลานอน',
                    _translate('Sleep', post.sleepTime),
                  ),
                  _buildDivider(),
                  _buildInfoRow(
                    Icons.cleaning_services,
                    'ความสะอาด',
                    _translate('Clean', post.cleanliness),
                  ),
                  _buildDivider(),
                  _buildInfoRow(
                    Icons.smoking_rooms,
                    'การสูบบุหรี่',
                    _translate('Smoke', post.smokingAllowed),
                  ),
                  _buildDivider(),
                  _buildInfoRow(
                    Icons.pets,
                    'สัตว์เลี้ยง',
                    _translate('Pet', post.petAllowed),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // --- 3. เพิ่มเติม ---
            if (post.additionalNotes != null &&
                post.additionalNotes!.isNotEmpty) ...[
              _buildSectionTitle('รายละเอียดเพิ่มเติม'),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.deepPurple.shade100),
                ),
                child: Text(
                  post.additionalNotes!,
                  style: TextStyle(
                    color: Colors.deepPurple.shade900,
                    height: 1.6,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],

            // --- 4. สถานที่ (หอพัก & ห้องพัก) กดลิงก์ได้ ---
            _buildSectionTitle('สถานที่พัก'),
            const SizedBox(height: 16),

            _buildLocationCard(
              context: context,
              icon: Icons.apartment,
              label: 'หอพัก',
              title: post.dormName ?? 'ไม่ระบุหอพัก',
              onTap: () {
                if (post.dormId != null) context.push('/dorm/${post.dormId}');
              },
            ),
            const SizedBox(height: 12),
            _buildLocationCard(
              context: context,
              icon: Icons.meeting_room,
              label: 'ห้องพัก',
              title: post.roomTypeName ?? 'ไม่ระบุห้องพัก',
              onTap: () {
                if (post.roomTypeId != null) {
                  context.push('/room/${post.roomTypeId}');
                }
              },
            ),

            const SizedBox(height: 40),

            // --- 5. ปุ่มจับคู่ — เปลี่ยนตามว่าเป็นประกาศของตัวเองหรือไม่ ---
            _buildMatchAction(context),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // 🚀 ปุ่มด้านล่างสุด — เปลี่ยนหน้าตา/พฤติกรรมตามบทบาทของผู้ใช้ปัจจุบัน:
  // - เจ้าของประกาศเอง -> ไปหน้าจัดการคำขอจับคู่
  // - คนอื่น -> ส่งคำขอจับคู่ / แสดงสถานะคำขอที่เคยส่งไปแล้ว
  Widget _buildMatchAction(BuildContext context) {
    if (_isLoadingSession) {
      return const SizedBox(
        height: 56,
        child: Center(child: CircularProgressIndicator(color: Colors.deepPurple)),
      );
    }

    final isOwnPost =
        _currentMemberId != null && _currentMemberId == post.memberId;

    if (isOwnPost) {
      // 🚀 ต้องรู้ Matched_Count ถึงจะเช็คได้ว่าลบประกาศได้ไหม (ลบได้เฉพาะยังไม่ได้คู่เลย)
      // ส่วนแก้ไขทำได้ตราบใดที่ประกาศยัง "กำลังหา" อยู่ (เช็คจาก post.postStatus) และต้องยัง
      // ไม่มีใครขอจับคู่เข้ามาเลยด้วย (Pending/Matched) — เปลี่ยนเงื่อนไขหลังมีคนขอแล้วไม่แฟร์
      // กับผู้ขอที่ตัดสินใจส่งคำขอมาโดยอิงจากเงื่อนไขเดิม (backend เช็คซ้ำอีกชั้นเหมือนกัน)
      return Consumer(
        builder: (context, ref, child) {
          final metaAsync = ref.watch(postMatchRequestsProvider(post.postId));
          final matchedCount = metaAsync.value?['post']?['Matched_Count'] as int?;
          final matches = metaAsync.value?['matches'] as List?;
          final hasActiveRequest = matches?.any(
                (m) =>
                    m['Match_Status'] == 'Pending' ||
                    m['Match_Status'] == 'Matched',
              ) ??
              false;
          final canDelete = matchedCount == 0;
          final canEdit = post.postStatus == 'Searching' && !hasActiveRequest;

          return Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      context.push('/roommate-post/${post.postId}/requests'),
                  icon: const Icon(Icons.mark_email_unread_outlined),
                  label: const Text(
                    'ดูคำขอจับคู่',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: canEdit ? _handleEditPost : null,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('แก้ไขประกาศ'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.deepPurple,
                        side: const BorderSide(color: Colors.deepPurple),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 🚀 มีคนจับคู่แล้ว (canDelete == false) -> ซ่อนปุ่มลบ แสดงปุ่ม "ยกเลิกการ
                  // จับคู่" แทน พาไปหน้าคำขอจับคู่ที่เลือกยกเลิกได้เป็นรายคน (รองรับประกาศที่
                  // หาหลายคนและจับคู่ไปแล้วบางส่วน) ยกเลิกสำเร็จแล้วประกาศจะเปิดกลับเป็น
                  // 'Searching' อัตโนมัติ ทำให้กดลบได้ตามปกติถ้าไม่มีคนจับคู่เหลือแล้ว
                  Expanded(
                    child: canDelete
                        ? OutlinedButton.icon(
                            onPressed: _isDeleting ? null : _confirmDeletePost,
                            icon: _isDeleting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.red,
                                    ),
                                  )
                                : const Icon(Icons.delete_outline, size: 18),
                            label: const Text('ลบประกาศ'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.shade600,
                              side: BorderSide(color: Colors.red.shade400),
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          )
                        : OutlinedButton.icon(
                            onPressed: () => context.push(
                              '/roommate-post/${post.postId}/requests',
                            ),
                            icon: const Icon(Icons.link_off, size: 18),
                            label: const Text('ยกเลิกการจับคู่'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.shade600,
                              side: BorderSide(color: Colors.red.shade400),
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
              if (!canEdit && post.postStatus == 'Searching' && hasActiveRequest) ...[
                const SizedBox(height: 8),
                Text(
                  'แก้ไขไม่ได้ เพราะมีคนขอจับคู่ประกาศนี้เข้ามาแล้ว',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ],
          );
        },
      );
    }

    // 🚀 ประกาศนี้ปิดรับคำขอแล้ว (ได้ครบคนตามที่ต้องการ หรือเจ้าของปิดเอง) —
    // กันไม่ให้กดส่งคำขอไปยังประกาศที่ไม่รับคำขอแล้ว ถึงจะเข้ามาผ่านลิงก์เก่า/แคชก็ตาม
    if (post.postStatus != 'Searching') {
      return _staticActionButton(
        label: post.postStatus == 'Found'
            ? 'ประกาศนี้จับคู่แล้ว'
            : 'ประกาศนี้ปิดรับคำขอแล้ว',
        icon: Icons.event_busy_outlined,
        background: Colors.grey.shade100,
        foreground: Colors.grey.shade600,
      );
    }

    return Consumer(
      builder: (context, ref, child) {
        final statusAsync = ref.watch(
          myMatchRequestStatusProvider(post.postId),
        );

        return statusAsync.when(
          loading: () => const SizedBox(
            height: 56,
            child: Center(
              child: CircularProgressIndicator(color: Colors.deepPurple),
            ),
          ),
          error: (error, stack) => SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: () =>
                  ref.invalidate(myMatchRequestStatusProvider(post.postId)),
              icon: const Icon(Icons.refresh),
              label: const Text('โหลดสถานะคำขอไม่สำเร็จ ลองใหม่'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          data: (match) {
            final status = match?['Match_Status'] as String?;

            if (status == 'Pending') {
              final matchId = match?['Match_ID'] as int?;
              return Column(
                children: [
                  _staticActionButton(
                    label: 'ส่งคำขอแล้ว รอเจ้าของประกาศตอบรับ',
                    icon: Icons.hourglass_top_rounded,
                    background: Colors.orange.shade50,
                    foreground: Colors.orange.shade800,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: (matchId == null || _isCancellingRequest)
                          ? null
                          : () => _cancelMyRequest(matchId),
                      icon: _isCancellingRequest
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.red,
                              ),
                            )
                          : const Icon(Icons.close, size: 18),
                      label: const Text('ยกเลิกคำขอ'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade600,
                        side: BorderSide(color: Colors.red.shade400),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }
            if (status == 'Matched') {
              return _staticActionButton(
                label: 'จับคู่สำเร็จแล้ว 🎉',
                icon: Icons.celebration_outlined,
                background: Colors.green.shade50,
                foreground: Colors.green.shade700,
              );
            }

            // status == 'Rejected' หรือยังไม่เคยส่งคำขอ (null) -> ส่งคำขอได้
            return SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _handleSendRequest,
                icon: const Icon(Icons.person_add_alt_1),
                label: Text(
                  status == 'Rejected' ? 'ส่งคำขอจับคู่อีกครั้ง' : 'ส่งคำขอจับคู่',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _staticActionButton({
    required String label,
    required IconData icon,
    required Color background,
    required Color foreground,
  }) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: foreground),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Helper Widget สำหรับ หัวข้อแต่ละ Section
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 18,
        color: Colors.deepPurple.shade900,
      ),
    );
  }

  // Helper Widget สำหรับเส้นคั่นบางๆ
  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(height: 1, color: Colors.grey.shade100),
    );
  }

  // Helper Widget สำหรับ List คุณสมบัติ (ปรับให้ไอคอนคุมโทนสีเดียวกัน)
  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.deepPurple.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: Colors.deepPurple.shade400),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Text(
            title,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  // Helper Widget สำหรับการ์ดสถานที่พัก
  Widget _buildLocationCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.deepPurple.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.deepPurple),
        ),
        title: Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
        subtitle: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: Colors.grey.shade400,
        ),
      ),
    );
  }
}
