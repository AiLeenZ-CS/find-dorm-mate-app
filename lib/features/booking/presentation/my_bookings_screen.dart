import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/booking_repository.dart';
import 'package:find_dorm_mate/features/roommate/data/roommate_repository.dart';
import 'package:find_dorm_mate/features/roommate/domain/roommate_post_model.dart';
import 'package:find_dorm_mate/features/reviews/data/review_repository.dart';

/// หน้า "การจองของฉัน" — แทนที่ระบบคิวเดิมทั้งหมด
/// แสดงใบจองทุกสถานะ (Pending/Confirmed/Rejected/Cancelled/Expired)
/// ใบจอง Pending จะมีตัวนับถอยหลัง 24 ชม. (Expires_At) และปุ่มยกเลิก
class MyBookingsScreen extends ConsumerStatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  ConsumerState<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends ConsumerState<MyBookingsScreen> {
  List<String> _parseImages(String? dataString) {
    if (dataString == null || dataString.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(dataString);
      if (decoded is List) return decoded.map((e) => e.toString()).toList();
    } catch (e) {
      final cleaned = dataString.replaceAll(RegExp(r'[\[\]"]'), '');
      return cleaned
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate).toLocal();
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return '';
    }
  }

  Future<void> _confirmCancel(int bookingId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'ยืนยันการยกเลิกใบจอง',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'คุณแน่ใจหรือไม่ว่าต้องการยกเลิกใบจองนี้?\nระบบจะคืนสต๊อกห้องพักให้ทันที',
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

    if (confirm == true) {
      try {
        await ref.read(bookingRepositoryProvider).cancelBooking(bookingId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ยกเลิกใบจองสำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
        ref.invalidate(myBookingsProvider);
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
  }

  Future<void> _writeReview(int bookingId, int dormId) async {
    int selectedRating = 5;
    final commentController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text(
            'รีวิวหอพักนี้',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ให้คะแนนหอพักนี้'),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starValue = index + 1;
                  return IconButton(
                    onPressed: () =>
                        setDialogState(() => selectedRating = starValue),
                    icon: Icon(
                      selectedRating >= starValue
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: Colors.amber,
                      size: 32,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: commentController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'เล่าความประทับใจ (ไม่บังคับ)',
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ปิด', style: TextStyle(color: Colors.grey)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.teal),
              child: const Text('ส่งรีวิว'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    try {
      await ref
          .read(reviewRepositoryProvider)
          .createReview(
            bookingId: bookingId,
            rating: selectedRating,
            comment: commentController.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ส่งรีวิวสำเร็จ ขอบคุณสำหรับความคิดเห็น!'),
          backgroundColor: Colors.green,
        ),
      );
      ref.invalidate(myBookingsProvider);
      ref.invalidate(dormReviewsProvider(dormId));
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

  @override
  Widget build(BuildContext context) {
    final bookingsAsyncValue = ref.watch(myBookingsProvider);
    // 🚀 ใช้เช็คว่าใบจองนี้เคยสร้างประกาศหารูมเมทไปแล้วหรือยัง (ผูกกับ Booking_ID) และ
    // เช็คว่าตอนนี้มีประกาศที่ "กำลังหา" อยู่แล้วหรือไม่ (สร้างได้แค่ 1 ประกาศต่อคน)
    final myRoommatePosts = ref.watch(myRoommatePostsProvider).value ?? [];

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'การจองของฉัน',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: bookingsAsyncValue.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Colors.teal)),
        error: (error, stack) => Center(
          child: Text(
            'เกิดข้อผิดพลาด: $error',
            style: const TextStyle(color: Colors.red),
          ),
        ),
        data: (bookings) {
          if (bookings.isEmpty) return _buildEmptyState();

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(myBookingsProvider),
            color: Colors.teal,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              itemBuilder: (context, index) =>
                  _buildBookingCard(bookings[index], myRoommatePosts),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'ยังไม่มีการจองห้องพัก',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ห้องพักที่คุณจองไว้จะแสดงที่นี่',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(
    Map<String, dynamic> booking,
    List<RoommatePostModel> myRoommatePosts,
  ) {
    final status = booking['Booking_Status'] ?? 'Pending';
    final roomType = booking['Room_Type'] ?? {};
    final dorm = booking['Dorm'] ?? {};
    final roomName =
        roomType['Room_Type_Name'] ?? roomType['Room_Type'] ?? 'ไม่ทราบชื่อห้อง';
    final dormName = dorm['Dorm_Name'] ?? '';
    final price = roomType['Price_Per_Month'] ?? 0;

    final imageUrls = _parseImages(roomType['Room_Images']);
    final firstImage = imageUrls.isNotEmpty ? imageUrls.first : null;

    // 🚀 เช็คว่าใบจองนี้เคยสร้างประกาศหารูมเมทไปแล้วหรือยัง และมีประกาศ "กำลังหา"
    // ที่เปิดอยู่ที่ไหนอยู่แล้วไหม (สร้างได้แค่ 1 ประกาศต่อคนในเวลาเดียวกัน)
    final bookingId = booking['Booking_ID'];
    RoommatePostModel? postForThisBooking;
    RoommatePostModel? otherActivePost;
    for (final p in myRoommatePosts) {
      if (p.bookingId == bookingId) {
        postForThisBooking = p;
      } else if (p.postStatus == 'Searching') {
        otherActivePost = p;
      }
    }

    Color statusColor;
    String statusText;
    IconData statusIcon;
    bool isPending = false;

    switch (status) {
      case 'Pending':
        statusColor = Colors.orange.shade700;
        statusText = 'รอเจ้าของหอยืนยัน';
        statusIcon = Icons.hourglass_top_rounded;
        isPending = true;
        break;
      case 'Confirmed':
        statusColor = Colors.green.shade600;
        statusText = 'ยืนยันการจองแล้ว';
        statusIcon = Icons.check_circle_outline;
        break;
      case 'Rejected':
        statusColor = Colors.red.shade600;
        statusText = 'เจ้าของหอปฏิเสธการจอง';
        statusIcon = Icons.cancel_outlined;
        break;
      case 'Expired':
        statusColor = Colors.grey.shade600;
        statusText = 'หมดเวลารอยืนยัน';
        statusIcon = Icons.timer_off_outlined;
        break;
      default:
        statusColor = Colors.grey.shade600;
        statusText = 'ยกเลิกแล้ว';
        statusIcon = Icons.block;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (roomType['Room_Type_ID'] != null) {
              context.push('/room/${roomType['Room_Type_ID']}');
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(statusIcon, color: statusColor, size: 20),
                              const SizedBox(width: 6),
                              Text(
                                statusText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            roomName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (dormName.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              dormName,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            '฿$price / เดือน',
                            style: TextStyle(
                              color: Colors.blueGrey.shade400,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: firstImage != null
                          ? Image.network(
                              firstImage,
                              fit: BoxFit.cover,
                              cacheWidth: 180,
                              errorBuilder: (c, e, s) => const Icon(
                                Icons.meeting_room,
                                color: Colors.grey,
                              ),
                            )
                          : const Icon(
                              Icons.meeting_room,
                              color: Colors.grey,
                              size: 40,
                            ),
                    ),
                  ],
                ),

                if (booking['Expected_Move_In'] != null) ...[
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.calendar_month_outlined,
                        size: 16,
                        color: Colors.teal,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'คาดว่าจะเข้าอยู่: ${_formatDate(booking['Expected_Move_In'])}',
                          style: TextStyle(
                            color: Colors.grey.shade800,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if ((booking['Note_To_Owner'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 16,
                          color: Colors.teal.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            booking['Note_To_Owner'],
                            style: TextStyle(
                              color: Colors.teal.shade900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (isPending && booking['Expires_At'] != null) ...[
                  const SizedBox(height: 24),
                  const Center(
                    child: Text(
                      'เหลือเวลารอเจ้าของหอยืนยัน',
                      style: TextStyle(
                        color: Colors.blueGrey,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  CountdownBoxTimer(
                    endTime: DateTime.parse(booking['Expires_At']),
                    onExpired: () => ref.refresh(myBookingsProvider),
                  ),
                ],

                if (status == 'Rejected' &&
                    (booking['Reject_Reason'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'เหตุผล: ${booking['Reject_Reason']}',
                      style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                    ),
                  ),
                ],

                if (isPending) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _confirmCancel(booking['Booking_ID']),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade600,
                        side: BorderSide(color: Colors.red.shade400, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        surfaceTintColor: Colors.red.shade50,
                      ),
                      child: const Text(
                        'ยกเลิกการจองนี้',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],

                // 🚀 จองได้ห้องแล้ว -> ให้ประกาศหารูมเมทได้ทันทีจากใบจองนี้เลย
                // (ผูก Booking_ID ไปกับประกาศ ทำให้ประกาศแสดงสถานะ "มีห้องแล้ว")
                // ถ้าเคยสร้างประกาศสำหรับใบจองนี้แล้ว -> ลิงก์ไปหน้าประกาศแทนการสร้างใหม่
                // ถ้ามีประกาศอื่นเปิดอยู่ (ห้องอื่น) -> บอกให้ไปจัดการประกาศเดิมก่อน (สร้างได้แค่ 1 ประกาศ)
                if (status == 'Confirmed' &&
                    roomType['Room_Type_ID'] != null &&
                    dorm['Dorm_ID'] != null) ...[
                  const SizedBox(height: 16),
                  if (postForThisBooking != null)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => context.push(
                          '/roommate-detail',
                          extra: postForThisBooking,
                        ),
                        icon: const Icon(Icons.campaign_outlined),
                        label: const Text(
                          'ดูประกาศหารูมเมทของคุณ',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    )
                  else if (otherActivePost != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'คุณมีประกาศหารูมเมทที่เปิดอยู่แล้ว (ห้องอื่น) '
                            'ต้องปิดหรือลบก่อนถึงจะประกาศห้องนี้ได้',
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => context.push(
                              '/roommate-detail',
                              extra: otherActivePost,
                            ),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'ไปดูประกาศเดิม',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          context.push(
                            '/create-roommate-post/${dorm['Dorm_ID']}',
                            extra: {
                              'roomTypeId': roomType['Room_Type_ID'],
                              'roomTypeName': roomName,
                              'bookingId': booking['Booking_ID'],
                            },
                          );
                        },
                        icon: const Icon(Icons.campaign_outlined),
                        label: const Text(
                          'ประกาศหารูมเมท',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                ],

                // 🚀 รีวิวได้เมื่อยืนยันการจองแล้วเท่านั้น และรีวิวได้แค่ 1 ครั้งต่อใบจอง
                // (เช็คจาก Reviews ที่ backend แนบมากับใบจองนี้แล้ว)
                if (status == 'Confirmed' && dorm['Dorm_ID'] != null) ...[
                  const SizedBox(height: 12),
                  if ((booking['Reviews'] as List?)?.isNotEmpty ?? false)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Colors.amber.shade700,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'คุณรีวิวหอพักนี้แล้ว',
                            style: TextStyle(
                              color: Colors.amber.shade900,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _writeReview(
                          booking['Booking_ID'],
                          dorm['Dorm_ID'],
                        ),
                        icon: const Icon(Icons.star_border_rounded, size: 18),
                        label: const Text('เขียนรีวิวหอพักนี้'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.amber.shade800,
                          side: BorderSide(
                            color: Colors.amber.shade400,
                            width: 1.5,
                          ),
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
          ),
        ),
      ),
    );
  }
}

// ⏳ ====================================================
// Widget: เวลานับถอยหลัง แบบกล่องมินิมอล 3 ช่อง
// ====================================================
class CountdownBoxTimer extends StatefulWidget {
  final DateTime endTime;
  final VoidCallback onExpired;

  const CountdownBoxTimer({
    super.key,
    required this.endTime,
    required this.onExpired,
  });

  @override
  State<CountdownBoxTimer> createState() => _CountdownBoxTimerState();
}

class _CountdownBoxTimerState extends State<CountdownBoxTimer> {
  Timer? _timer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _calculateTimeLeft();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) => _calculateTimeLeft(),
    );
  }

  void _calculateTimeLeft() {
    final now = DateTime.now();
    if (widget.endTime.isAfter(now)) {
      setState(() => _timeLeft = widget.endTime.difference(now));
    } else {
      _timer?.cancel();
      if (_timeLeft != Duration.zero) {
        setState(() => _timeLeft = Duration.zero);
        widget.onExpired();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_timeLeft <= Duration.zero) {
      return const Center(
        child: Text(
          'หมดเวลารอยืนยันแล้ว',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
      );
    }

    String hours = _timeLeft.inHours.toString().padLeft(2, '0');
    String minutes = (_timeLeft.inMinutes.remainder(60)).toString().padLeft(2, '0');
    String seconds = (_timeLeft.inSeconds.remainder(60)).toString().padLeft(2, '0');

    return Row(
      children: [
        _buildTimeBox(hours, 'ชั่วโมง'),
        const SizedBox(width: 12),
        _buildTimeBox(minutes, 'นาที'),
        const SizedBox(width: 12),
        _buildTimeBox(seconds, 'วินาที'),
      ],
    );
  }

  Widget _buildTimeBox(String time, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              time,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
