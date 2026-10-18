import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/booking_repository.dart';

/// หน้า "การจองทั้งหมด" — ฝั่งเจ้าของหอพัก
/// แสดงใบจองที่เข้ามาทุกหอของเจ้าของหอคนนี้ พร้อมปุ่มอนุมัติ/ปฏิเสธสำหรับใบจอง Pending
class OwnerBookingsScreen extends ConsumerStatefulWidget {
  const OwnerBookingsScreen({super.key});

  @override
  ConsumerState<OwnerBookingsScreen> createState() =>
      _OwnerBookingsScreenState();
}

const _tealAccent = Colors.teal;

class _OwnerBookingsScreenState extends ConsumerState<OwnerBookingsScreen> {
  String _filter = 'All';
  final Set<int> _processingIds = {};

  static const _filters = {
    'All': 'ทั้งหมด',
    'Pending': 'รอตอบรับ',
    'Confirmed': 'ยืนยันแล้ว',
    'Rejected': 'ปฏิเสธแล้ว',
    'Cancelled': 'ยกเลิกแล้ว',
    'Expired': 'หมดเวลา',
  };

  Future<void> _confirmBooking(int bookingId) async {
    setState(() => _processingIds.add(bookingId));
    try {
      await ref.read(bookingRepositoryProvider).confirmBooking(bookingId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ยืนยันการจองสำเร็จ'),
          backgroundColor: Colors.green,
        ),
      );
      ref.invalidate(ownerBookingsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _processingIds.remove(bookingId));
    }
  }

  Future<void> _rejectBooking(int bookingId) async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'ปฏิเสธการจอง',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ระบุเหตุผล (ไม่บังคับ) เพื่อแจ้งให้ผู้จองทราบ'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'เช่น ห้องไม่ว่างแล้ว, ข้อมูลไม่ครบ ฯลฯ',
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
            child: const Text('ปิด', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            child: const Text('ยืนยันปฏิเสธ'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _processingIds.add(bookingId));
    try {
      await ref
          .read(bookingRepositoryProvider)
          .rejectBooking(
            bookingId,
            reason: reasonController.text.trim().isEmpty
                ? null
                : reasonController.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ปฏิเสธการจองสำเร็จ คืนสต๊อกห้องแล้ว'),
          backgroundColor: Colors.green,
        ),
      );
      ref.invalidate(ownerBookingsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _processingIds.remove(bookingId));
    }
  }

  Future<void> _reportBooking(int bookingId) async {
    final noteController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'รายงานผู้ใช้',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ใช้สำหรับรายงานพฤติกรรมไม่เหมาะสมของผู้จอง เช่น ส่งข้อความไม่เหมาะสม '
              'จองแล้วไม่มารับห้อง/ไม่ชำระเงินตามที่ตกลง ฯลฯ '
              'รายงานได้ตั้งแต่ยังไม่ตอบรับคำขอจอง และหากรายงานแล้วจะไม่สามารถอนุมัติใบจองนี้ได้อีก '
              'ทีมงานจะตรวจสอบรายงานนี้ภายหลัง',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'รายละเอียดเพิ่มเติม (ไม่บังคับ)',
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
            child: const Text('ปิด', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600,
            ),
            child: const Text('ส่งรายงาน'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _processingIds.add(bookingId));
    try {
      await ref
          .read(bookingRepositoryProvider)
          .reportBooking(
            bookingId,
            note: noteController.text.trim().isEmpty
                ? null
                : noteController.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ส่งรายงานผู้ใช้สำเร็จ'),
          backgroundColor: Colors.green,
        ),
      );
      ref.invalidate(ownerBookingsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _processingIds.remove(bookingId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingsAsyncValue = ref.watch(ownerBookingsProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'การจองทั้งหมด',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: bookingsAsyncValue.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: _tealAccent),
              ),
              error: (error, stack) => Center(
                child: Text(
                  'เกิดข้อผิดพลาด: $error',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              data: (bookings) {
                final filtered = _filter == 'All'
                    ? bookings
                    : bookings
                          .where((b) => b['Booking_Status'] == _filter)
                          .toList();

                if (filtered.isEmpty) return _buildEmptyState();

                return RefreshIndicator(
                  onRefresh: () async => ref.refresh(ownerBookingsProvider),
                  color: _tealAccent,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) =>
                        _buildBookingCard(filtered[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: DropdownMenu<String>(
        initialSelection: _filter,
        expandedInsets: EdgeInsets.zero,
        leadingIcon: Icon(Icons.filter_list_rounded, color: _tealAccent.shade700),
        label: const Text('กรองตามสถานะ'),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        menuStyle: MenuStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade100,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _tealAccent, width: 1.5),
          ),
        ),
        onSelected: (value) {
          if (value != null) setState(() => _filter = value);
        },
        dropdownMenuEntries: _filters.entries
            .map(
              (entry) =>
                  DropdownMenuEntry<String>(value: entry.key, label: entry.value),
            )
            .toList(),
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
            'ยังไม่มีรายการจองในหมวดนี้',
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

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final bookingId = booking['Booking_ID'] as int;
    final status = booking['Booking_Status'] ?? 'Pending';
    final member = booking['Member'] ?? {};
    final roomType = booking['Room_Type'] ?? {};
    final dorm = booking['Dorm'] ?? {};

    final memberName =
        '${member['First_Name'] ?? ''} ${member['Last_Name'] ?? ''}'.trim();
    final displayName = memberName.isNotEmpty
        ? memberName
        : (member['Username'] ?? 'ไม่ทราบชื่อผู้จอง');
    final phone = member['Phone'] ?? 'ไม่ระบุเบอร์โทร';
    final profileImage = member['Profile_Image'] as String?;
    final gender = member['Gender'] as String?;
    final roomName =
        roomType['Room_Type_Name'] ?? roomType['Room_Type'] ?? 'ไม่ทราบชื่อห้อง';
    final dormName = dorm['Dorm_Name'] ?? '';
    final price = roomType['Price_Per_Month'] ?? 0;
    final isProcessing = _processingIds.contains(bookingId);

    Color statusColor;
    String statusText;
    IconData statusIcon;
    bool isPending = false;

    switch (status) {
      case 'Pending':
        statusColor = Colors.orange.shade700;
        statusText = 'รอตอบรับ';
        statusIcon = Icons.hourglass_top_rounded;
        isPending = true;
        break;
      case 'Confirmed':
        statusColor = Colors.green.shade600;
        statusText = 'ยืนยันแล้ว';
        statusIcon = Icons.check_circle_outline;
        break;
      case 'Rejected':
        statusColor = Colors.red.shade600;
        statusText = 'ปฏิเสธแล้ว';
        statusIcon = Icons.cancel_outlined;
        break;
      case 'Expired':
        statusColor = Colors.grey.shade600;
        statusText = 'หมดเวลารอตอบรับ';
        statusIcon = Icons.timer_off_outlined;
        break;
      default:
        statusColor = Colors.grey.shade600;
        statusText = 'ยกเลิกแล้ว';
        statusIcon = Icons.block;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
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
              const Spacer(),
              if (booking['Requested_At'] != null)
                Text(
                  _formatDate(booking['Requested_At']),
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _tealAccent.shade50,
                backgroundImage: profileImage != null
                    ? ResizeImage(NetworkImage(profileImage), width: 88)
                    : null,
                child: profileImage == null
                    ? Icon(Icons.person, color: _tealAccent.shade700)
                    : null,
              ),
              const SizedBox(width: 12),
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
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          gender == 'Male'
                              ? Icons.male
                              : gender == 'Female'
                              ? Icons.female
                              : Icons.person_outline,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          gender == 'Male'
                              ? 'เพศชาย'
                              : gender == 'Female'
                              ? 'เพศหญิง'
                              : 'ไม่ระบุเพศ',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          Icons.phone_outlined,
                          size: 13,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          phone,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text(
            roomName,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (dormName.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              dormName,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 4),
          Text(
            '฿$price / เดือน',
            style: TextStyle(
              color: Colors.blueGrey.shade400,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),

          if (booking['Expected_Move_In'] != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.calendar_month_outlined,
                  size: 16,
                  color: _tealAccent.shade700,
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
                color: _tealAccent.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 16,
                    color: _tealAccent.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      booking['Note_To_Owner'],
                      style: TextStyle(
                        color: _tealAccent.shade900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (status == 'Rejected' &&
              (booking['Reject_Reason'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 12),
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
            if (_hasReport(booking)) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.flag, size: 16, color: Colors.red.shade600),
                    const SizedBox(width: 6),
                    Text(
                      'รายงานผู้ใช้นี้แล้ว ไม่สามารถอนุมัติใบจองนี้ได้',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isProcessing
                      ? null
                      : () => _rejectBooking(bookingId),
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
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isProcessing
                          ? null
                          : () => _rejectBooking(bookingId),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('ปฏิเสธ'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade600,
                        side: BorderSide(
                          color: Colors.red.shade400,
                          width: 1.5,
                        ),
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
                          : () => _confirmBooking(bookingId),
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
                        backgroundColor: _tealAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: isProcessing
                      ? null
                      : () => _reportBooking(bookingId),
                  icon: const Icon(Icons.flag_outlined, size: 16),
                  label: const Text('รายงานผู้ใช้'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade600,
                  ),
                ),
              ),
            ],
          ],

          if (status == 'Confirmed') ...[
            const SizedBox(height: 16),
            if (_hasReport(booking))
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.flag, size: 16, color: Colors.red.shade600),
                    const SizedBox(width: 6),
                    Text(
                      'รายงานผู้ใช้นี้แล้ว',
                      style: TextStyle(
                        color: Colors.red.shade700,
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
                  onPressed: isProcessing
                      ? null
                      : () => _reportBooking(bookingId),
                  icon: const Icon(Icons.flag_outlined, size: 18),
                  label: const Text('รายงานผู้ใช้ (จองแล้วไม่จ่ายเงิน)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade600,
                    side: BorderSide(color: Colors.red.shade300, width: 1.5),
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

  bool _hasReport(Map<String, dynamic> booking) {
    final reports = booking['Reports'];
    return reports is List && reports.isNotEmpty;
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate).toLocal();
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return '';
    }
  }
}
