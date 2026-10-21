// 📄 ไฟล์นี้ทำหน้าที่: enum รายการตัวเลือกการเรียงลำดับผลลัพธ์หน้า Home (แนะนำ/ราคา/ระยะทาง)
// ใช้ร่วมกันระหว่าง home_screen.dart และ home_sort_bar.dart
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
