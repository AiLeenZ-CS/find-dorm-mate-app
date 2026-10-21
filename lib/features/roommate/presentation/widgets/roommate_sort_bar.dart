// 📄 ไฟล์นี้ทำหน้าที่: แถบ UI เรียงลำดับผลลัพธ์เหนือรายการประกาศในหน้า Feed รูมเมท — กดแล้ว
// เปิด bottom sheet ให้เลือก RoommateSortOption และโชว์จำนวนผลลัพธ์ที่พบ
import 'package:flutter/material.dart';
import 'roommate_sort_option.dart';

/// แถบเรียงลำดับผลลัพธ์ของหน้า Feed รูมเมท — วางไว้เหนือรายการประกาศ กดแล้วเปิด bottom sheet
/// เลือกวิธีเรียง แสดงจำนวนผลลัพธ์คู่กันไปด้วยเลย (แพทเทิร์นเดียวกับ HomeSortBar)
class RoommateSortBar extends StatelessWidget {
  final int resultCount;
  final RoommateSortOption selected;
  final ValueChanged<RoommateSortOption> onSelected;
  final bool isLocating;

  const RoommateSortBar({
    super.key,
    required this.resultCount,
    required this.selected,
    required this.onSelected,
    this.isLocating = false,
  });

  Future<void> _openSortSheet(BuildContext context) async {
    final result = await showModalBottomSheet<RoommateSortOption>(
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
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'พบ $resultCount ประกาศ',
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
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.deepPurple,
                      ),
                    )
                  else
                    const Icon(
                      Icons.swap_vert_rounded,
                      size: 18,
                      color: Colors.deepPurple,
                    ),
                  const SizedBox(width: 6),
                  Text(
                    selected.label,
                    style: const TextStyle(
                      color: Colors.deepPurple,
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
  final RoommateSortOption selected;

  const _SortOptionSheet({required this.selected});

  @override
  Widget build(BuildContext context) {
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
            ...RoommateSortOption.values.map((option) {
              final isSelected = option == selected;
              return ListTile(
                onTap: () => Navigator.pop(context, option),
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: isSelected ? Colors.deepPurple : Colors.grey,
                ),
                title: Text(
                  option.label,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.deepPurple : Colors.black87,
                  ),
                ),
                trailing: option == RoommateSortOption.nearest
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
