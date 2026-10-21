// 📄 ไฟล์นี้ทำหน้าที่: โมเดลข้อมูลรีวิวหอพักหนึ่งรายการ (คะแนน/คอมเมนต์/ผู้รีวิว) แปลงจาก
// JSON ที่ backend ส่งมา ให้ ReviewRepository และหน้าแสดงรีวิวใช้งานต่อ
class ReviewModel {
  final int id;
  final int? rating;
  final String? comment;
  final DateTime? reviewedAt;
  final int? memberId;
  final String? memberUsername;
  final String? memberProfileImage;

  ReviewModel({
    required this.id,
    this.rating,
    this.comment,
    this.reviewedAt,
    this.memberId,
    this.memberUsername,
    this.memberProfileImage,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    final member = json['Member'] as Map<String, dynamic>?;
    return ReviewModel(
      id: json['Review_ID'],
      rating: json['Rating'],
      comment: json['Comment'],
      reviewedAt: json['Reviewed_At'] != null
          ? DateTime.tryParse(json['Reviewed_At'])
          : null,
      memberId: member?['Member_ID'],
      memberUsername: member?['Username'],
      memberProfileImage: member?['Profile_Image'],
    );
  }
}
