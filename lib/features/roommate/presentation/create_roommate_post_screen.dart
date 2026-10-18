import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/roommate_repository.dart';
import '../domain/roommate_post_model.dart';
import 'package:find_dorm_mate/core/widgets/app_text_field.dart';
import 'package:find_dorm_mate/core/widgets/primary_button.dart';
import 'package:find_dorm_mate/core/widgets/section_title.dart';
import 'package:find_dorm_mate/core/widgets/soft_card.dart';

class CreateRoommatePostScreen extends ConsumerStatefulWidget {
  final int dormId;
  final int roomTypeId;
  final String roomTypeName;
  // 🚀 มีค่าเมื่อมาจากปุ่ม "ประกาศหารูมเมท" บนใบจองที่ยืนยันแล้ว — ประกาศที่สร้างจะถูก
  // flag ว่า "มีห้องแล้ว" (ตรงข้ามกับการเลือกห้องจาก Bottom Sheet เองที่ bookingId เป็น null)
  final int? bookingId;
  // 🚀 มีค่า = โหมดแก้ไขประกาศเดิม (ดึงค่าเริ่มต้นจากประกาศนี้มาเติมในฟอร์ม และตอนบันทึก
  // จะเรียก updatePost แทน createRoommatePost) — ไม่มีค่า = โหมดสร้างประกาศใหม่ตามปกติ
  final RoommatePostModel? existingPost;

  const CreateRoommatePostScreen({
    super.key,
    required this.dormId,
    required this.roomTypeId,
    required this.roomTypeName,
    this.bookingId,
    this.existingPost,
  });

  @override
  ConsumerState<CreateRoommatePostScreen> createState() =>
      _CreateRoommatePostScreenState();
}

class _CreateRoommatePostScreenState
    extends ConsumerState<CreateRoommatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();

  int _reqPersons = 1;
  String _reqGender = 'Any';

  bool _isAnyAge = true;
  RangeValues _ageRange = const RangeValues(18, 30);

  String _sleepTime = 'Any';
  String _smokingAllowed = 'Any';
  String _petAllowed = 'Any';
  String _cleanliness = 'Any';

  bool _isLoading = false;

  bool get _isEditMode => widget.existingPost != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingPost;
    if (existing == null) return;

    // 🚀 โหมดแก้ไข — เติมค่าเดิมของประกาศลงในฟอร์มทั้งหมด
    _reqPersons = existing.reqPersons;
    _reqGender = existing.reqGender;
    _sleepTime = existing.sleepTime;
    _smokingAllowed = existing.smokingAllowed;
    _petAllowed = existing.petAllowed;
    _cleanliness = existing.cleanliness;
    _notesController.text = existing.additionalNotes ?? '';

    if (existing.reqAgeRange == 'Any') {
      _isAnyAge = true;
    } else {
      final parts = existing.reqAgeRange.split('-');
      final start = parts.isNotEmpty ? double.tryParse(parts[0]) : null;
      final end = parts.length > 1 ? double.tryParse(parts[1]) : null;
      if (start != null && end != null) {
        _isAnyAge = false;
        _ageRange = RangeValues(start.clamp(18, 50), end.clamp(18, 50));
      }
    }
  }

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    String finalAgeRange = _isAnyAge
        ? 'Any'
        : '${_ageRange.start.round()}-${_ageRange.end.round()}';
    final notes = _notesController.text.trim();

    try {
      if (_isEditMode) {
        await ref
            .read(roommateRepositoryProvider)
            .updatePost(
              postId: widget.existingPost!.postId,
              reqPersons: _reqPersons,
              reqGender: _reqGender,
              reqAgeRange: finalAgeRange,
              sleepTime: _sleepTime,
              smokingAllowed: _smokingAllowed,
              petAllowed: _petAllowed,
              cleanliness: _cleanliness,
              additionalNotes: notes,
            );
      } else {
        await ref
            .read(roommateRepositoryProvider)
            .createRoommatePost(
              dormId: widget.dormId,
              roomTypeId: widget.roomTypeId,
              reqPersons: _reqPersons,
              reqGender: _reqGender,
              reqAgeRange: finalAgeRange,
              sleepTime: _sleepTime,
              smokingAllowed: _smokingAllowed,
              petAllowed: _petAllowed,
              cleanliness: _cleanliness,
              additionalNotes: notes,
              bookingId: widget.bookingId,
            );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode ? 'บันทึกการแก้ไขสำเร็จ! 🎉' : 'สร้างประกาศหารูมเมทสำเร็จ! 🎉',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green,
        ),
      );

      if (_isEditMode) {
        context.pop(
          widget.existingPost!.copyWith(
            reqPersons: _reqPersons,
            reqGender: _reqGender,
            reqAgeRange: finalAgeRange,
            sleepTime: _sleepTime,
            smokingAllowed: _smokingAllowed,
            petAllowed: _petAllowed,
            cleanliness: _cleanliness,
            additionalNotes: notes,
          ),
        );
      } else {
        context.pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'แก้ไขประกาศหารูมเมท' : 'ลงประกาศหารูมเมท',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.grey.shade50,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 1. ข้อมูลห้องพัก (ล็อคไว้) ---
              const SectionTitle(
                title: 'ห้องพักที่จะแชร์',
                icon: Icons.meeting_room,
              ),
              const SizedBox(height: 12),
              SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.apartment,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ประเภทห้องพักที่เลือก',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.roomTypeName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 28,
                        ),
                      ],
                    ),
                    if (widget.bookingId != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              color: Colors.teal.shade600,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'ห้องนี้คือห้องที่คุณจองไว้แล้ว ประกาศนี้จะแสดง'
                                'สถานะ "มีห้องแล้ว" ให้รูมเมทเห็น',
                                style: TextStyle(
                                  color: Colors.teal.shade800,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // --- 2. จำนวนคนที่หาเพิ่ม ---
              const SectionTitle(title: 'จำนวนที่ต้องการ', icon: Icons.group_add),
              const SizedBox(height: 12),
              SoftCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'จำนวนรูมเมทที่หาเพิ่ม',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.remove,
                              color: _reqPersons > 1
                                  ? colorScheme.primary
                                  : Colors.grey,
                            ),
                            onPressed: _reqPersons > 1
                                ? () => setState(() => _reqPersons--)
                                : null,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              '$_reqPersons',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.add,
                              color: _reqPersons < 4
                                  ? colorScheme.primary
                                  : Colors.grey,
                            ),
                            onPressed: _reqPersons < 4
                                ? () => setState(() => _reqPersons++)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // --- 3. เงื่อนไขรูมเมท ---
              const SectionTitle(
                title: 'คุณสมบัติรูมเมทที่ต้องการ',
                icon: Icons.checklist,
              ),
              const SizedBox(height: 12),
              SoftCard(
                child: Column(
                  children: [
                    _buildDropdownRow(
                      title: 'เพศ',
                      icon: Icons.wc,
                      value: _reqGender,
                      items: const {
                        'Male': 'ชาย',
                        'Female': 'หญิง',
                        'Any': 'ไม่จำกัด',
                      },
                      onChanged: (val) => setState(() => _reqGender = val!),
                    ),
                    const Divider(height: 24),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.cake,
                              color: colorScheme.primary.withValues(alpha: 0.6),
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 100,
                              child: Text(
                                'ช่วงอายุ',
                                style: TextStyle(
                                  color: Colors.grey.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'ไม่จำกัด',
                              style: TextStyle(
                                color: _isAnyAge
                                    ? colorScheme.primary
                                    : Colors.grey.shade600,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Switch(
                              value: _isAnyAge,
                              onChanged: (val) => setState(() => _isAnyAge = val),
                            ),
                          ],
                        ),

                        if (!_isAnyAge) ...[
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${_ageRange.start.round()} ปี',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  '${_ageRange.end.round()} ปี',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          RangeSlider(
                            values: _ageRange,
                            min: 18,
                            max: 50,
                            divisions: 32,
                            labels: RangeLabels(
                              '${_ageRange.start.round()}',
                              '${_ageRange.end.round()}',
                            ),
                            onChanged: (RangeValues values) {
                              setState(() {
                                _ageRange = values;
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                    const Divider(height: 24),

                    _buildDropdownRow(
                      title: 'เวลานอน',
                      icon: Icons.bedtime,
                      value: _sleepTime,
                      items: const {
                        'Before midnight': 'ก่อนเที่ยงคืน',
                        'After midnight': 'หลังเที่ยงคืน',
                        'Any': 'ยังไงก็ได้',
                      },
                      onChanged: (val) => setState(() => _sleepTime = val!),
                    ),
                    const Divider(height: 24),
                    _buildDropdownRow(
                      title: 'การสูบบุหรี่',
                      icon: Icons.smoking_rooms,
                      value: _smokingAllowed,
                      items: const {
                        'Smoking': 'สูบบุหรี่ได้',
                        'Non_Smoking': 'ไม่สูบบุหรี่',
                        'Any': 'ยังไงก็ได้',
                      },
                      onChanged: (val) => setState(() => _smokingAllowed = val!),
                    ),
                    const Divider(height: 24),
                    _buildDropdownRow(
                      title: 'การเลี้ยงสัตว์',
                      icon: Icons.pets,
                      value: _petAllowed,
                      items: const {
                        'Pet_Friendly': 'เลี้ยงได้',
                        'No_Pets': 'ไม่ให้เลี้ยง',
                        'Any': 'ยังไงก็ได้',
                      },
                      onChanged: (val) => setState(() => _petAllowed = val!),
                    ),
                    const Divider(height: 24),
                    _buildDropdownRow(
                      title: 'ความสะอาด',
                      icon: Icons.cleaning_services,
                      value: _cleanliness,
                      items: const {
                        'Very': 'เนี๊ยบมาก',
                        'Normal': 'ปานกลาง',
                        'Easy': 'สบายๆ รกได้นิดหน่อย',
                        'Any': 'ยังไงก็ได้',
                      },
                      onChanged: (val) => setState(() => _cleanliness = val!),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // --- 4. รายละเอียดเพิ่มเติม ---
              const SectionTitle(
                title: 'รายละเอียดเพิ่มเติม (ถ้ามี)',
                icon: Icons.edit_note,
              ),
              const SizedBox(height: 12),
              SoftCard(
                padding: const EdgeInsets.all(12),
                child: AppTextField(
                  controller: _notesController,
                  hintText:
                      'แนะนำตัวคร่าวๆ, ไลฟ์สไตล์, งานอดิเรก หรือข้อตกลงอื่นๆ เพื่อให้รูมเมทตัดสินใจง่ายขึ้น...',
                  maxLines: 4,
                ),
              ),

              const SizedBox(height: 32),

              PrimaryButton(
                label: _isLoading
                    ? (_isEditMode ? 'กำลังบันทึก...' : 'กำลังโพสต์...')
                    : (_isEditMode ? 'บันทึกการแก้ไข' : 'โพสต์ประกาศหารูมเมท'),
                onPressed: _submitPost,
                isLoading: _isLoading,
                icon: _isEditMode ? Icons.save_outlined : Icons.campaign,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownRow({
    required String title,
    required IconData icon,
    required String value,
    required Map<String, String> items,
    required void Function(String?) onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, color: colorScheme.primary.withValues(alpha: 0.6), size: 22),
        const SizedBox(width: 12),
        SizedBox(
          width: 100,
          child: Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(14),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: value,
                icon: Icon(Icons.keyboard_arrow_down, color: colorScheme.primary),
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                items: items.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
