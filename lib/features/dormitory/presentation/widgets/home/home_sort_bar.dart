// 📄 ไฟล์นี้ทำหน้าที่: แถบแสดงจำนวนผลลัพธ์ + ปุ่มเปิด bottom sheet เลือกวิธีเรียงลำดับหอพัก
// บนหน้า Home (เป็น widget ย่อยที่ home_screen.dart เรียกใช้)
import 'package:flutter/material.dart';
import 'home_sort_option.dart';

/// แถบเรียงลำดับผลลัพธ์ — วางไว้เหนือรายการหอพัก กดแล้วเปิด bottom sheet เลือกวิธีเรียง
/// แสดงจำนวนผลลัพธ์คู่กันไปด้วยเลย ลดความรกไม่ต้องมีอีก section แยก
class HomeSortBar extends StatelessWidget {
  final int resultCount;
  final HomeSortOption selected;
  final ValueChanged<HomeSortOption> onSelected;
  final bool isLocating;

  const HomeSortBar({
    super.key,
    required this.resultCount,
    required this.selected,
    required this.onSelected,
    this.isLocating = false,
  });

  Future<void> _openSortSheet(BuildContext context) async {
    final result = await showModalBottomSheet<HomeSortOption>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _SortOptionSheet(selected: selected),
    );
    if (result != null) onSelected(result);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'พบ $resultCount หอพัก',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          InkWell(
            onTap: isLocating ? null : () => _openSortSheet(context),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLocating)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.primary,
                      ),
                    )
                  else
                    Icon(
                      Icons.swap_vert_rounded,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                  const SizedBox(width: 6),
                  Text(
                    selected.label,
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SortOptionSheet extends StatelessWidget {
  final HomeSortOption selected;

  const _SortOptionSheet({required this.selected});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
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
            const SizedBox(height: 16),
            const Text(
              'เรียงลำดับตาม',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...HomeSortOption.values.map((option) {
              final isSelected = option == selected;
              return ListTile(
                onTap: () => Navigator.pop(context, option),
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: isSelected ? colorScheme.primary : Colors.grey,
                ),
                title: Text(
                  option.label,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? colorScheme.primary : Colors.black87,
                  ),
                ),
                trailing: option == HomeSortOption.nearest
                    ? Icon(Icons.near_me_outlined, color: Colors.grey.shade400, size: 18)
                    : null,
              );
            }),
          ],
        ),
      ),
    );
  }
}
