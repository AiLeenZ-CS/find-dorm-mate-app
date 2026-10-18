import 'dart:convert';

// 🚀 แปลงฟิลด์ที่ Backend เก็บเป็น JSON string ของ List<String> (เช่น Custom_Facilities,
// Dorm_Images, Room_Images ที่เก็บแบบ @db.Text) กลับมาเป็น List<String> ที่ใช้งานได้จริง
// รองรับทั้งกรณี backend ส่งมาเป็น string ที่ยัง encode อยู่ และกรณีเผื่อส่งมาเป็น List ตรงๆ อยู่แล้ว
// คืนค่า [] เสมอถ้า parse ไม่ได้ ไม่ throw ออกไปทำให้หน้าจอพัง
List<String> parseStringListJson(dynamic raw) {
  if (raw == null) return [];

  if (raw is List) {
    return raw.map((e) => e.toString()).toList();
  }

  if (raw is String && raw.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {
      // ข้อมูลเก่า/รูปแบบผิดพลาด - ไม่ throw ให้หน้าจอพัง แค่ถือว่าไม่มีข้อมูล
    }
  }

  return [];
}
