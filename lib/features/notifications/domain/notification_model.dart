// 📄 ไฟล์นี้ทำหน้าที่: โมเดลข้อมูลแจ้งเตือนหนึ่งรายการ แปลงจาก JSON ที่ backend ส่งมา
// ให้ NotificationRepository และหน้า notifications_screen.dart ใช้งานต่อ
class AppNotification {
  final int id;
  final String type;
  final String title;
  final String? body;
  final String? link;
  final bool isRead;
  final DateTime? createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.link,
    required this.isRead,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['Notification_ID'],
      type: json['Type'] ?? '',
      title: json['Title'] ?? '',
      body: json['Body'],
      link: json['Link'],
      isRead: json['Is_Read'] == true,
      createdAt: json['Created_At'] != null
          ? DateTime.tryParse(json['Created_At'])
          : null,
    );
  }
}
