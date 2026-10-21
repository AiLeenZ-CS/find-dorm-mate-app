// 📄 ไฟล์นี้ทำหน้าที่: เก็บค่า config กลางของแอป (base URL ของ backend API) ไว้ที่เดียว
// ให้ ApiClient และ repository/service ทุกจุดเรียกใช้ร่วมกัน
// 🚀 Base URL เดียวที่ใช้ทั้งแอป (ก่อนหน้านี้ hardcode ซ้ำกันอยู่ 6 จุดในหลาย repository)
// ⚠️ ค่า default 10.0.2.2 คือ loopback alias ของ Android Emulator เท่านั้น ใช้ไม่ได้กับ
// iOS Simulator/เครื่องจริง/เว็บ หรือ production — ตอน build จริงให้ส่ง URL ของ backend จริง
// เข้ามาผ่าน --dart-define เช่น:
//   flutter build apk --dart-define=API_BASE_URL=https://api.yourdomain.com
// ไม่ส่งมาก็ยังใช้ค่า default เดิมได้ตามปกติตอน dev บน emulator เหมือนเดิมทุกประการ
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );
  static const String apiUrl = '$baseUrl/api';
}
