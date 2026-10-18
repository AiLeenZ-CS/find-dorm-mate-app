/// ตัวเลือกการเรียงลำดับผลลัพธ์หน้า Feed รูมเมท — แยกจาก RoommateFilters เพราะเป็นคนละแนวคิด
/// กัน (filter = ตัดรายการที่ไม่ตรงเงื่อนไขทิ้ง, sort = จัดลำดับรายการที่เหลือใหม่)
enum RoommateSortOption {
  recommended('แนะนำ'),
  newest('ใหม่ล่าสุด'),
  priceLowToHigh('ราคาห้อง: ต่ำ - สูง'),
  priceHighToLow('ราคาห้อง: สูง - ต่ำ'),
  nearest('ระยะทาง: ใกล้ - ไกล');

  final String label;
  const RoommateSortOption(this.label);
}
