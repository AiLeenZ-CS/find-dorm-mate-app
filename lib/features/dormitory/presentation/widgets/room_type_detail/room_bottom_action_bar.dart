import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:find_dorm_mate/core/auth/role_utils.dart';
import 'package:find_dorm_mate/features/booking/data/booking_repository.dart';
import 'package:find_dorm_mate/features/dormitory/domain/room_type_detail_model.dart';

/// แถบปุ่ม CTA ยึดด้านล่างจอของหน้ารายละเอียดห้องพัก
/// เจ้าของหอเห็นปุ่มแก้ไขห้อง ส่วนสมาชิกเห็นปุ่มกดจองห้องพัก
/// กดแล้วสร้างใบจองสถานะ Pending ทันที (ตัดสต๊อกห้องแบบ atomic ฝั่ง backend)
/// รอเจ้าของหอยืนยันภายใน 24 ชม. — ดูสถานะ/ยกเลิกได้ที่หน้า "การจองของฉัน"
class RoomBottomActionBar extends ConsumerStatefulWidget {
  final int roomTypeId;
  final int? remainingRooms;
  final RoomTypeDetailModel room;

  const RoomBottomActionBar({
    super.key,
    required this.roomTypeId,
    required this.room,
    this.remainingRooms,
  });

  @override
  ConsumerState<RoomBottomActionBar> createState() =>
      _RoomBottomActionBarState();
}

class _RoomBottomActionBarState extends ConsumerState<RoomBottomActionBar> {
  bool _isBooking = false;

  Future<String> _getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_role') ?? 'Guest';
  }

  Future<void> _handleBookRoom() async {
    final prefs = await SharedPreferences.getInstance();
    final memberId = prefs.getInt('member_id');

    if (!mounted) return;

    if (memberId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเข้าสู่ระบบก่อนทำรายการ'),
          backgroundColor: Colors.orange,
        ),
      );
      context.push('/login');
      return;
    }

    final formResult = await _showBookingFormSheet();
    if (formResult == null) return;

    setState(() => _isBooking = true);
    try {
      await ref
          .read(bookingRepositoryProvider)
          .createBooking(
            widget.roomTypeId,
            expectedMoveIn: formResult.moveInDate.toIso8601String(),
            noteToOwner: formResult.note,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('จองห้องพักสำเร็จ! รอเจ้าของหอยืนยันภายใน 3 วัน'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
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

  // 🚀 เก็บวันที่คาดว่าจะเข้าอยู่ (บังคับ) + หมายเหตุถึงเจ้าของหอ (ไม่บังคับ) ก่อนสร้างใบจอง
  // จริง ให้เจ้าของหอเห็นข้อมูลนี้ตอนพิจารณาอนุมัติที่หน้า "การจองทั้งหมด"
  Future<_BookingFormResult?> _showBookingFormSheet() {
    return showModalBottomSheet<_BookingFormResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const _BookingFormSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: FutureBuilder<String>(
          future: _getUserRole(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(height: 52);
            }

            final isOwner = isOwnerRole(snapshot.data);
            return isOwner ? _buildOwnerButton(context) : _buildMemberButton();
          },
        ),
      ),
    );
  }

  Widget _buildOwnerButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () {
          final dormId = widget.room.dormId;
          if (dormId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('ไม่พบข้อมูลหอพักของห้องนี้ ลองรีเฟรชหน้าใหม่อีกครั้ง'),
              ),
            );
            return;
          }
          context.push('/edit-room-type/$dormId', extra: widget.room);
        },
        icon: const Icon(Icons.edit_note),
        label: const Text('แก้ไขข้อมูลห้องพักนี้'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildMemberButton() {
    final isFull = widget.remainingRooms != null && widget.remainingRooms! <= 0;

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: (_isBooking || isFull) ? null : _handleBookRoom,
        icon: _isBooking
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Icon(isFull ? Icons.block : Icons.event_available_rounded),
        label: Text(
          _isBooking
              ? 'กำลังดำเนินการ...'
              : isFull
              ? 'ห้องเต็มแล้ว'
              : 'จองห้องพักนี้',
        ),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _BookingFormResult {
  final DateTime moveInDate;
  final String? note;

  const _BookingFormResult({required this.moveInDate, this.note});
}

/// 🚀 ฟอร์มก่อนยืนยันจอง — บังคับเลือกวันที่คาดว่าจะเข้าอยู่ (Expected_Move_In) และให้พิมพ์
/// หมายเหตุถึงเจ้าของหอได้ (ไม่บังคับ, Note_To_Owner) เจ้าของหอจะเห็นทั้งสองค่านี้ตอนพิจารณา
/// อนุมัติที่หน้า "การจองทั้งหมด" (owner_bookings_screen.dart)
class _BookingFormSheet extends StatefulWidget {
  const _BookingFormSheet();

  @override
  State<_BookingFormSheet> createState() => _BookingFormSheetState();
}

class _BookingFormSheetState extends State<_BookingFormSheet> {
  DateTime? _moveInDate;
  final _noteController = TextEditingController();
  String? _dateError;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _moveInDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'เลือกวันที่คาดว่าจะเข้าอยู่',
    );
    if (picked != null) {
      setState(() {
        _moveInDate = picked;
        _dateError = null;
      });
    }
  }

  void _handleSubmit() {
    if (_moveInDate == null) {
      setState(() => _dateError = 'กรุณาเลือกวันที่คาดว่าจะเข้าอยู่');
      return;
    }
    Navigator.pop(
      context,
      _BookingFormResult(
        moveInDate: _moveInDate!,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      ),
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'ข้อมูลก่อนจองห้องพัก',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'ระบบจะกันห้องนี้ไว้ให้คุณทันที และรอเจ้าของหอยืนยันภายใน 3 วัน '
              'หากเกินเวลาหรือเจ้าของหอปฏิเสธ ห้องจะถูกคืนสต๊อกให้ผู้อื่นจองต่อโดยอัตโนมัติ',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'วันที่คาดว่าจะเข้าอยู่ *',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                  border: _dateError != null
                      ? Border.all(color: Colors.red.shade400)
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month, color: primary, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      _moveInDate != null
                          ? DateFormat('d MMM yyyy').format(_moveInDate!)
                          : 'แตะเพื่อเลือกวันที่',
                      style: TextStyle(
                        color: _moveInDate != null
                            ? Colors.black87
                            : Colors.grey.shade500,
                        fontWeight: _moveInDate != null
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_dateError != null) ...[
              const SizedBox(height: 6),
              Text(
                _dateError!,
                style: TextStyle(color: Colors.red.shade600, fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              'หมายเหตุถึงเจ้าของหอ (ไม่บังคับ)',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'เช่น ขอเข้าอยู่ช่วงเย็น, มีสัตว์เลี้ยง 1 ตัว ฯลฯ',
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('ยกเลิก'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _handleSubmit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('ยืนยันจอง'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
