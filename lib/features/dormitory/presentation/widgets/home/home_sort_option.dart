/// ตัวเลือกการเรียงลำดับผลลัพธ์หน้า Home — แยกจาก HomeFilters เพราะเป็นคนละแนวคิดกัน
/// (filter = ตัดรายการที่ไม่ตรงเงื่อนไขทิ้ง, sort = จัดลำดับรายการที่เหลือใหม่)
enum HomeSortOption {
  recommended('เรียงตามคะแนนรีวิว'),
  priceLowToHigh('ราคา: ต่ำ - สูง'),
  priceHighToLow('ราคา: สูง - ต่ำ'),
  nearest('ระยะทาง: ใกล้ - ไกล');

  final String label;
  const HomeSortOption(this.label);
}
