// 📄 ไฟล์นี้ทำหน้าที่: Bottom sheet ตัวกรองของหน้า Feed รูมเมท — ให้ผู้ใช้ตั้งค่า RoommateFilters
// (เพศ/อายุ/เวลานอน/บุหรี่/สัตว์เลี้ยง/ความสะอาด/มีห้องแล้ว) แล้วส่งค่ากลับให้หน้า Feed
import 'package:flutter/material.dart';
import 'roommate_filters.dart';

const Map<String, String> _genderLabels = {
  'All': 'ทั้งหมด',
  'Male': 'ชาย',
  'Female': 'หญิง',
  'Any': 'ไม่จำกัดเพศ',
};

const Map<String, String> _sleepLabels = {
  'All': 'ทั้งหมด',
  'Before midnight': 'ก่อนเที่ยงคืน',
  'After midnight': 'หลังเที่ยงคืน',
  'Any': 'ยังไงก็ได้',
};

const Map<String, String> _smokeLabels = {
  'All': 'ทั้งหมด',
  'Smoking': 'สูบบุหรี่ได้',
  'Non_Smoking': 'ไม่สูบบุหรี่',
  'Any': 'ยังไงก็ได้',
};

const Map<String, String> _petLabels = {
  'All': 'ทั้งหมด',
  'Pet_Friendly': 'เลี้ยงได้',
  'No_Pets': 'ไม่ให้เลี้ยง',
  'Any': 'ยังไงก็ได้',
};

const Map<String, String> _cleanLabels = {
  'All': 'ทั้งหมด',
  'Very': 'เนี๊ยบมาก',
  'Normal': 'ปานกลาง',
  'Easy': 'สบายๆ รกได้นิดหน่อย',
  'Any': 'ยังไงก็ได้',
};

/// ตัวกรองหน้า Feed รูมเมท — กรองตามเงื่อนไขที่ผู้ประกาศระบุไว้ในประกาศเอง (เพศที่ต้องการ,
/// ช่วงอายุ, เวลานอน, บุหรี่, สัตว์เลี้ยง, ความสะอาด) ธีมเดียวกับ HomeFilterSheet
class RoommateFilterSheet extends StatefulWidget {
  final RoommateFilters initial;

  const RoommateFilterSheet({super.key, required this.initial});

  @override
  State<RoommateFilterSheet> createState() => _RoommateFilterSheetState();
}

class _RoommateFilterSheetState extends State<RoommateFilterSheet> {
  late String _reqGender = widget.initial.reqGender;
  late String _sleepTime = widget.initial.sleepTime;
  late String _smokingAllowed = widget.initial.smokingAllowed;
  late String _petAllowed = widget.initial.petAllowed;
  late String _cleanliness = widget.initial.cleanliness;
  late RangeValues _ageRange = widget.initial.ageRange;
  late bool _onlyWithRoom = widget.initial.onlyWithRoom;

  void _clearAll() {
    setState(() {
      _reqGender = 'All';
      _sleepTime = 'All';
      _smokingAllowed = 'All';
      _petAllowed = 'All';
      _cleanliness = 'All';
      _ageRange = const RangeValues(18, 50);
      _onlyWithRoom = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        children: [
          // --- Header ---
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ตัวกรองรูมเมท',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    TextButton(
                      onPressed: _clearAll,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade600,
                        textStyle: const TextStyle(fontWeight: FontWeight.w600),
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('ล้างทั้งหมด'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: Colors.grey.shade200),
              ],
            ),
          ),

          // --- เนื้อหาเลื่อนได้ ---
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(icon: Icons.wc_rounded, title: 'เพศที่ต้องการ'),
                  const SizedBox(height: 12),
                  _chipRow(
                    labels: _genderLabels,
                    value: _reqGender,
                    onChanged: (v) => setState(() => _reqGender = v),
                  ),
                  const SizedBox(height: 28),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _SectionTitle(icon: Icons.cake_rounded, title: 'ช่วงอายุ'),
                      Text(
                        '${_ageRange.start.round()} - ${_ageRange.end.round()} ปี',
                        style: const TextStyle(
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      activeTrackColor: Colors.deepPurple,
                      inactiveTrackColor: Colors.grey.shade200,
                      thumbColor: Colors.white,
                      overlayColor: Colors.deepPurple.withValues(alpha: 0.1),
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 10,
                        elevation: 2,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 20,
                      ),
                    ),
                    child: RangeSlider(
                      values: _ageRange,
                      min: 18,
                      max: 50,
                      divisions: 32,
                      labels: RangeLabels(
                        '${_ageRange.start.round()}',
                        '${_ageRange.end.round()}',
                      ),
                      onChanged: (values) => setState(() => _ageRange = values),
                    ),
                  ),
                  const SizedBox(height: 28),

                  _SectionTitle(icon: Icons.bedtime_rounded, title: 'เวลานอน'),
                  const SizedBox(height: 12),
                  _chipRow(
                    labels: _sleepLabels,
                    value: _sleepTime,
                    onChanged: (v) => setState(() => _sleepTime = v),
                  ),
                  const SizedBox(height: 28),

                  _SectionTitle(icon: Icons.smoking_rooms_rounded, title: 'การสูบบุหรี่'),
                  const SizedBox(height: 12),
                  _chipRow(
                    labels: _smokeLabels,
                    value: _smokingAllowed,
                    onChanged: (v) => setState(() => _smokingAllowed = v),
                  ),
                  const SizedBox(height: 28),

                  _SectionTitle(icon: Icons.pets_rounded, title: 'สัตว์เลี้ยง'),
                  const SizedBox(height: 12),
                  _chipRow(
                    labels: _petLabels,
                    value: _petAllowed,
                    onChanged: (v) => setState(() => _petAllowed = v),
                  ),
                  const SizedBox(height: 28),

                  _SectionTitle(icon: Icons.cleaning_services_rounded, title: 'ความสะอาด'),
                  const SizedBox(height: 12),
                  _chipRow(
                    labels: _cleanLabels,
                    value: _cleanliness,
                    onChanged: (v) => setState(() => _cleanliness = v),
                  ),
                  const SizedBox(height: 28),

                  _SectionTitle(icon: Icons.verified_rounded, title: 'อื่นๆ'),
                  const SizedBox(height: 12),
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () =>
                        setState(() => _onlyWithRoom = !_onlyWithRoom),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: _onlyWithRoom
                            ? Colors.deepPurple.withValues(alpha: 0.08)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _onlyWithRoom
                              ? Colors.deepPurple
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.key_rounded,
                            size: 20,
                            color: _onlyWithRoom
                                ? Colors.deepPurple
                                : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'เฉพาะประกาศที่มีห้องแล้ว',
                              style: TextStyle(
                                color: _onlyWithRoom
                                    ? Colors.deepPurple
                                    : Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Switch(
                            value: _onlyWithRoom,
                            onChanged: (v) => setState(() => _onlyWithRoom = v),
                            activeColor: Colors.deepPurple,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- Footer ---
          Container(
            padding: EdgeInsets.fromLTRB(
              24,
              16,
              24,
              16 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                    RoommateFilters(
                      reqGender: _reqGender,
                      sleepTime: _sleepTime,
                      smokingAllowed: _smokingAllowed,
                      petAllowed: _petAllowed,
                      cleanliness: _cleanliness,
                      ageRange: _ageRange,
                      onlyWithRoom: _onlyWithRoom,
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                child: const Text('ดูผลลัพธ์'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipRow({
    required Map<String, String> labels,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: labels.entries.map((entry) {
        final isSelected = value == entry.key;
        return ChoiceChip(
          label: Text(entry.value),
          selected: isSelected,
          showCheckmark: false,
          onSelected: (_) => onChanged(entry.key),
          backgroundColor: Colors.grey.shade100,
          selectedColor: Colors.deepPurple.withValues(alpha: 0.1),
          labelStyle: TextStyle(
            color: isSelected ? Colors.deepPurple : Colors.grey.shade700,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: isSelected ? Colors.deepPurple : Colors.transparent,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 22, color: Colors.black87),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
