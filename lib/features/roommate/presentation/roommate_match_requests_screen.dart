// 📄 ไฟล์นี้ทำหน้าที่: หน้า "คำขอจับคู่" ฝั่งเจ้าของประกาศ — ดูโปรไฟล์ผู้ขอ ทักแชทก่อนตัดสินใจ
// อนุมัติ/ปฏิเสธคำขอ หรือยกเลิกการจับคู่ (Unmatch) กับคนที่จับคู่ไปแล้ว
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../data/roommate_repository.dart';

/// หน้า "คำขอจับคู่" ฝั่งเจ้าของประกาศ — ดูโปรไฟล์คนที่ส่งคำขอมา และอนุมัติ/ปฏิเสธได้
class RoommateMatchRequestsScreen extends ConsumerStatefulWidget {
  final int postId;

  const RoommateMatchRequestsScreen({super.key, required this.postId});

  @override
  ConsumerState<RoommateMatchRequestsScreen> createState() =>
      _RoommateMatchRequestsScreenState();
}

class _RoommateMatchRequestsScreenState
    extends ConsumerState<RoommateMatchRequestsScreen> {
  final Set<int> _processingIds = {};

  Future<void> _respond(int matchId, String status) async {
    setState(() => _processingIds.add(matchId));
    try {
      await ref
          .read(roommateRepositoryProvider)
          .respondToMatchRequest(matchId, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'Matched' ? 'อนุมัติคำขอจับคู่สำเร็จ' : 'ปฏิเสธคำขอแล้ว',
          ),
          backgroundColor: Colors.green,
        ),
      );
      ref.invalidate(postMatchRequestsProvider(widget.postId));

      // 🚀 ถ้าอนุมัติจนได้ครบคนแล้ว ประกาศจะถูกปิด (Post_Status เปลี่ยนเป็น 'Found')
      // แต่ roommateListProvider/roommateListByDormProvider ไม่ใช่ autoDispose เลยยังแคชรายการ
      // เดิมค้างไว้อยู่ ถ้าไม่ invalidate ตรงนี้ หน้าประกาศรวมจะยังโชว์ประกาศที่ปิดไปแล้วอยู่ดี
      ref.invalidate(myRoommatePostsProvider);
      ref.invalidate(roommateListProvider);
      ref.invalidate(roommateListByDormProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _processingIds.remove(matchId));
    }
  }

  // 🚀 เปิดห้องแชท 1:1 คุยกับผู้ขอก่อนตัดสินใจอนุมัติ/ปฏิเสธ — ต้องให้ backend สร้าง/sync
  // ห้องแชทก่อนเสมอ (ดู openPreMatchChat) ค่อยพาไปหน้าแชทต่อ ไม่งั้น Firestore Rules จะไม่ให้
  // อ่าน/เขียนห้องที่ยังไม่มี participantIds
  Future<void> _openChat(
    int matchId,
    String memberName,
    String? memberImage,
  ) async {
    setState(() => _processingIds.add(matchId));
    try {
      await ref.read(roommateRepositoryProvider).openPreChat(matchId);
      if (!mounted) return;
      context.push(
        '/roommate-pre-chat/$matchId',
        extra: {'title': 'แชทกับ $memberName', 'image': memberImage},
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
      if (mounted) setState(() => _processingIds.remove(matchId));
    }
  }

  Future<void> _unmatch(int matchId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'ยกเลิกการจับคู่',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'ประกาศนี้จะเปิดรับคำขอจับคู่ใหม่อีกครั้ง และอีกฝ่ายจะหลุดออกจากกลุ่มแชทนี้ '
          'คุณแน่ใจหรือไม่?',
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
            child: const Text('ยืนยันยกเลิก'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _processingIds.add(matchId));
    try {
      await ref.read(roommateRepositoryProvider).unmatch(matchId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ยกเลิกการจับคู่สำเร็จ ประกาศเปิดรับคำขอใหม่อีกครั้ง'),
          backgroundColor: Colors.green,
        ),
      );
      ref.invalidate(postMatchRequestsProvider(widget.postId));
      ref.invalidate(postMembersProvider(widget.postId));
      // 🚀 ประกาศกลับไปเป็น 'Searching' แล้ว ต้อง invalidate รายการรวม/ของฉัน เหมือนตอน
      // respondToMatchRequest ปิดประกาศ (ดูคอมเมนต์ใน _respond) กันหน้าอื่นโชว์สถานะเก่าค้างไว้
      ref.invalidate(myRoommatePostsProvider);
      ref.invalidate(roommateListProvider);
      ref.invalidate(roommateListByDormProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _processingIds.remove(matchId));
    }
  }

  int? _calculateAge(String? birthdateIso) {
    if (birthdateIso == null) return null;
    final birthdate = DateTime.tryParse(birthdateIso);
    if (birthdate == null) return null;
    final now = DateTime.now();
    int age = now.year - birthdate.year;
    if (now.month < birthdate.month ||
        (now.month == birthdate.month && now.day < birthdate.day)) {
      age--;
    }
    return age;
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(postMatchRequestsProvider(widget.postId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'คำขอจับคู่',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        backgroundColor: const Color(0xFFF8F9FA),
        foregroundColor: Colors.deepPurple,
        elevation: 0,
        centerTitle: true,
      ),
      body: requestsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Colors.deepPurple)),
        error: (error, stack) => Center(
          child: Text(
            'เกิดข้อผิดพลาด: $error',
            style: const TextStyle(color: Colors.red),
          ),
        ),
        data: (result) {
          final requests = List<Map<String, dynamic>>.from(
            result['matches'] ?? [],
          );
          final postMeta = result['post'] as Map<String, dynamic>?;

          if (requests.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async =>
                  ref.refresh(postMatchRequestsProvider(widget.postId)),
              color: Colors.deepPurple,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (postMeta != null) _buildProgressBanner(postMeta),
                  const SizedBox(height: 60),
                  Icon(
                    Icons.person_search_outlined,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ยังไม่มีคนส่งคำขอจับคู่มา',
                    textAlign: TextAlign.center,
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
            onRefresh: () async =>
                ref.refresh(postMatchRequestsProvider(widget.postId)),
            color: Colors.deepPurple,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (postMeta != null) _buildProgressBanner(postMeta),
                ...requests.map(_buildRequestCard),
              ],
            ),
          );
        },
      ),
    );
  }

  // 🚀 แถบสรุปความคืบหน้า/สถานะประกาศด้านบนรายการคำขอ — โชว์ "ได้ X/Y คนแล้ว"
  // และถ้าประกาศถูกปิดอัตโนมัติแล้ว (ได้ครบคนตามที่ต้องการ) จะขึ้นแบนเนอร์แจ้งด้วย
  Widget _buildProgressBanner(Map<String, dynamic> postMeta) {
    final status = postMeta['Post_Status'] as String? ?? 'Searching';
    final reqPersons = postMeta['Req_Persons'] as int? ?? 1;
    final matchedCount = postMeta['Matched_Count'] as int? ?? 0;
    final isClosed = status != 'Searching';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isClosed ? Colors.green.shade50 : Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            isClosed ? Icons.celebration_outlined : Icons.groups_outlined,
            color: isClosed ? Colors.green.shade700 : Colors.deepPurple,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isClosed
                  ? 'จับคู่แล้ว $matchedCount/$reqPersons คน — ปิดรับคำขออัตโนมัติ'
                  : 'ได้คู่แล้ว $matchedCount/$reqPersons คน',
              style: TextStyle(
                color: isClosed ? Colors.green.shade800 : Colors.deepPurple.shade800,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final matchId = request['Match_ID'] as int;
    final status = request['Match_Status'] ?? 'Pending';
    final member = request['Member'] ?? {};
    final message = request['Message_To_Owner'] as String?;
    final requestedAt = request['Requested_At'] != null
        ? DateTime.tryParse(request['Requested_At'])
        : null;

    final firstName = member['First_Name'] ?? '';
    final lastName = member['Last_Name'] ?? '';
    final nickname = member['Nickname'];
    final fullName = '$firstName $lastName'.trim();
    final displayName = fullName.isNotEmpty ? fullName : 'ผู้ใช้งานทั่วไป';
    final gender = member['Gender'];
    final age = _calculateAge(member['Birthdate']);
    final profileImage = member['Profile_Image'] as String?;
    final isProcessing = _processingIds.contains(matchId);

    Color statusColor;
    String statusText;
    bool isPending = false;
    bool isMatched = false;

    // 🐛 เดิม switch นี้มีแค่ 'Matched'/'Rejected' ชัดเจน ที่เหลือตกไป default (รอตอบรับ)
    // หมดโดยไม่ตั้งใจ — พอเพิ่มสถานะ 'Unmatched' (ยกเลิกการจับคู่) และ 'Cancelled' (ผู้ขอยกเลิก
    // คำขอเอง) เข้ามา ถ้าไม่แยก case ให้ชัด จะดันกลายเป็น isPending=true โชว์ปุ่มปฏิเสธ/อนุมัติ/
    // ทักแชทผิดๆ ซ้ำบนคำขอที่จบไปแล้ว ต้องระบุทุกสถานะที่เป็นไปได้ให้ชัดเจน ไม่พึ่ง default
    switch (status) {
      case 'Matched':
        statusColor = Colors.green.shade600;
        statusText = 'จับคู่สำเร็จ';
        isMatched = true;
        break;
      case 'Rejected':
        statusColor = Colors.red.shade600;
        statusText = 'ปฏิเสธแล้ว';
        break;
      case 'Unmatched':
        statusColor = Colors.grey.shade600;
        statusText = 'ยกเลิกการจับคู่แล้ว';
        break;
      case 'Cancelled':
        statusColor = Colors.grey.shade600;
        statusText = 'ผู้ขอยกเลิกคำขอแล้ว';
        break;
      case 'Pending':
      default:
        statusColor = Colors.orange.shade700;
        statusText = 'รอตอบรับ';
        isPending = true;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.deepPurple.shade50,
                backgroundImage: profileImage != null
                    ? ResizeImage(NetworkImage(profileImage), width: 120)
                    : null,
                child: profileImage == null
                    ? Icon(
                        Icons.person,
                        color: Colors.deepPurple.shade300,
                        size: 28,
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (nickname != null && nickname.toString().isNotEmpty)
                      Text(
                        '(${nickname.toString()})',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (gender != null)
                          Text(
                            gender == 'Male'
                                ? 'เพศชาย'
                                : gender == 'Female'
                                ? 'เพศหญิง'
                                : 'ไม่ระบุเพศ',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                        if (age != null)
                          Text(
                            '• อายุ $age ปี',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (message != null && message.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                message,
                style: TextStyle(color: Colors.deepPurple.shade900, fontSize: 13),
              ),
            ),
          ],
          if (requestedAt != null) ...[
            const SizedBox(height: 10),
            Text(
              'ส่งคำขอเมื่อ ${DateFormat('dd MMM yyyy, HH:mm').format(requestedAt)}',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
            ),
          ],
          if (isPending) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isProcessing
                    ? null
                    : () => _openChat(matchId, displayName, profileImage),
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('ทักแชทคุยก่อน'),
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
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isProcessing
                        ? null
                        : () => _respond(matchId, 'Rejected'),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('ปฏิเสธ'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade600,
                      side: BorderSide(color: Colors.red.shade400, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isProcessing
                        ? null
                        : () => _respond(matchId, 'Matched'),
                    icon: isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: const Text('อนุมัติ'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
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
          if (isMatched) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isProcessing ? null : () => _unmatch(matchId),
                icon: const Icon(Icons.link_off, size: 18),
                label: const Text('ยกเลิกการจับคู่ (Unmatch)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade600,
                  side: BorderSide(color: Colors.red.shade400, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
