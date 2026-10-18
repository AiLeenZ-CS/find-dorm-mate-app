import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/dorm_repository.dart';
import 'home_filters.dart';

const Map<String, String> _dormTypeLabels = {
  'All': 'ทั้งหมด',
  'Male': 'หอชาย',
  'Female': 'หอหญิง',
  'Mixed': 'หอรวม',
};

const Map<String, String> _airFanLabels = {
  'All': 'ทั้งหมด',
  'Air': 'แอร์',
  'Fan': 'พัดลม',
};

const double _maxPrice = 15000;

class HomeFilterSheet extends ConsumerStatefulWidget {
  final HomeFilters initial;

  const HomeFilterSheet({super.key, required this.initial});

  @override
  ConsumerState<HomeFilterSheet> createState() => _HomeFilterSheetState();
}

class _HomeFilterSheetState extends ConsumerState<HomeFilterSheet> {
  late String _dormType = widget.initial.dormType;
  late String _airFan = widget.initial.airFan;
  late RangeValues _priceRange = widget.initial.priceRange;
  late Set<String> _dormFacilities = {...widget.initial.dormFacilities};
  late Set<String> _roomFacilities = {...widget.initial.roomFacilities};
  late int _minRating = widget.initial.minRating;

  void _clearAll() {
    setState(() {
      _dormType = 'All';
      _airFan = 'All';
      _priceRange = const RangeValues(0, _maxPrice);
      _dormFacilities = {};
      _roomFacilities = {};
      _minRating = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dormFacilitiesAsync = ref.watch(dormFacilitiesProvider);
    final roomFacilitiesAsync = ref.watch(roomFacilitiesProvider);

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
                      'ตัวกรองหอพัก',
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
                  _SectionTitle(
                    icon: Icons.other_houses_rounded,
                    title: 'ประเภทหอพัก',
                  ),
                  const SizedBox(height: 12),
                  // 💡 บังคับ 4 ปุ่มให้อยู่ใน 1 แถวโดยใช้ Row + Expanded
                  Row(
                    children: _dormTypeLabels.entries.map((entry) {
                      final isSelected = _dormType == entry.key;
                      final isLast = entry.key == _dormTypeLabels.keys.last;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: isLast ? 0 : 8.0),
                          child: _buildChoiceChip(
                            label: entry.value,
                            isSelected: isSelected,
                            colorScheme: colorScheme,
                            onSelected: (_) =>
                                setState(() => _dormType = entry.key),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),

                  _SectionTitle(
                    icon: Icons.ac_unit_rounded,
                    title: 'ประเภทห้องพัก',
                  ),
                  const SizedBox(height: 12),
                  // 💡 บังคับ 3 ปุ่มให้อยู่ใน 1 แถวโดยใช้ Row + Expanded
                  Row(
                    children: _airFanLabels.entries.map((entry) {
                      final isSelected = _airFan == entry.key;
                      final isLast = entry.key == _airFanLabels.keys.last;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: isLast ? 0 : 8.0),
                          child: _buildChoiceChip(
                            label: entry.value,
                            isSelected: isSelected,
                            colorScheme: colorScheme,
                            onSelected: (_) =>
                                setState(() => _airFan = entry.key),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _SectionTitle(
                        icon: Icons.payments_rounded,
                        title: 'ช่วงราคา (บาท/เดือน)',
                      ),
                      Text(
                        '฿${_priceRange.start.toInt()} - ฿${_priceRange.end.toInt() == _maxPrice.toInt() ? '15,000+' : _priceRange.end.toInt()}',
                        style: TextStyle(
                          color: colorScheme.primary,
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
                      activeTrackColor: colorScheme.primary,
                      inactiveTrackColor: Colors.grey.shade200,
                      thumbColor: Colors.white,
                      overlayColor: colorScheme.primary.withValues(alpha: 0.1),
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 10,
                        elevation: 2,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 20,
                      ),
                    ),
                    child: RangeSlider(
                      values: _priceRange,
                      min: 0,
                      max: _maxPrice,
                      divisions: 30,
                      labels: RangeLabels(
                        '฿${_priceRange.start.toInt()}',
                        '฿${_priceRange.end.toInt()}',
                      ),
                      onChanged: (values) =>
                          setState(() => _priceRange = values),
                    ),
                  ),
                  const SizedBox(height: 28),

                  _SectionTitle(
                    icon: Icons.star_rounded,
                    title: 'คะแนนรีวิว',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _minRating == 0 ? 'ทั้งหมด' : '$_minRating ดาวขึ้นไป',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(5, (index) {
                      final starValue = index + 1;
                      final isFilled = starValue <= _minRating;
                      return InkWell(
                        borderRadius: BorderRadius.circular(24),
                        // 💡 แตะดาวเดิมซ้ำ = ล้างตัวกรองกลับไปเป็น "ทั้งหมด"
                        onTap: () => setState(() {
                          _minRating = _minRating == starValue ? 0 : starValue;
                        }),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Icon(
                            isFilled
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: isFilled
                                ? Colors.amber.shade600
                                : Colors.grey.shade400,
                            size: 32,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 28),

                  _FacilityFilterSection(
                    icon: Icons.apartment_rounded,
                    title: 'สิ่งอำนวยความสะดวกหอพัก',
                    facilitiesAsync: dormFacilitiesAsync,
                    selected: _dormFacilities,
                    accent: colorScheme.primary,
                    onToggle: (name, isSelected) => setState(() {
                      isSelected
                          ? _dormFacilities.add(name)
                          : _dormFacilities.remove(name);
                    }),
                  ),

                  _FacilityFilterSection(
                    icon: Icons.bed_rounded,
                    title: 'สิ่งอำนวยความสะดวกห้องพัก',
                    facilitiesAsync: roomFacilitiesAsync,
                    selected: _roomFacilities,
                    accent: colorScheme.primary,
                    onToggle: (name, isSelected) => setState(() {
                      isSelected
                          ? _roomFacilities.add(name)
                          : _roomFacilities.remove(name);
                    }),
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
                    HomeFilters(
                      dormType: _dormType,
                      airFan: _airFan,
                      priceRange: _priceRange,
                      dormFacilities: _dormFacilities,
                      roomFacilities: _roomFacilities,
                      minRating: _minRating,
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
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

  // 💡 ลบ width ออก แล้วใช้ double.infinity เพื่อให้ยืดเต็มกรอบ Expanded
  Widget _buildChoiceChip({
    required String label,
    required bool isSelected,
    required ColorScheme colorScheme,
    required ValueChanged<bool> onSelected,
  }) {
    return ChoiceChip(
      label: Container(
        width: double.infinity,
        alignment: Alignment.center,
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      selected: isSelected,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(
        vertical: 10,
      ), // ลบ padding ซ้ายขวาออก เพื่อให้มีพื้นที่ข้อความเยอะขึ้น
      labelStyle: TextStyle(
        color: isSelected ? colorScheme.primary : Colors.grey.shade700,
        fontWeight: FontWeight.w500,
        fontSize:
            13, // 💡 ปรับฟอนต์ลงนิดนึงให้ 4 ปุ่มเรียงกันในจอมือถือเล็กๆ ได้โดยไม่ล้น
      ),
      backgroundColor: Colors.grey.shade100,
      selectedColor: colorScheme.primary.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          width: 1.0,
        ),
      ),
      onSelected: onSelected,
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

class _FacilityFilterSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final AsyncValue<List<Map<String, dynamic>>> facilitiesAsync;
  final Set<String> selected;
  final Color accent;
  final void Function(String name, bool isSelected) onToggle;

  const _FacilityFilterSection({
    required this.icon,
    required this.title,
    required this.facilitiesAsync,
    required this.selected,
    required this.accent,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return facilitiesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
      data: (facilities) {
        if (facilities.isEmpty) return const SizedBox.shrink();

        // 💡 ใช้ LayoutBuilder หุ้มแค่ส่วนสิ่งอำนวยความสะดวก เพื่อแบ่ง 2 คอลัมน์ให้เป๊ะๆ
        return LayoutBuilder(
          builder: (context, constraints) {
            // คำนวณความกว้างหน้าจอ (ลบช่องว่างตรงกลาง 10 แล้วหาร 2)
            final double buttonWidth = (constraints.maxWidth - 10) / 2;

            return Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(icon: icon, title: title),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 12,
                    children: facilities.map((facility) {
                      final name = facility['Facility_Name']?.toString() ?? '';
                      final isSelected = selected.contains(name);

                      return SizedBox(
                        width: buttonWidth, // 💡 บังคับความกว้าง 50%
                        child: FilterChip(
                          label: Container(
                            width: double.infinity,
                            alignment: Alignment.center,
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (value) => onToggle(name, value),
                          showCheckmark: false,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          backgroundColor: Colors.white,
                          selectedColor: accent.withValues(alpha: 0.1),
                          elevation: 0,
                          pressElevation: 0,
                          labelStyle: TextStyle(
                            color: isSelected ? accent : Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected ? accent : Colors.grey.shade300,
                              width: 1.0,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
