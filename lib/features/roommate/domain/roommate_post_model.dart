// 📄 ไฟล์นี้ทำหน้าที่: Data model ของ "ประกาศหารูมเมท" 1 รายการ — แปลง JSON จาก backend เป็น
// object ที่ UI ใช้ได้ (เงื่อนไขที่ต้องการ + ข้อมูลหอ/ห้อง/เจ้าของประกาศ + สถานะการจับคู่)
class RoommatePostModel {
  final int postId;
  final int reqPersons;
  final String reqGender;
  final String reqAgeRange;
  final String sleepTime;
  final String smokingAllowed;
  final String petAllowed;
  final String cleanliness;
  final String? additionalNotes;
  final DateTime? createdAt;
  final String postStatus;

  // 🚀 ข้อมูลที่ดึงมาจากตารางอื่น
  final int? dormId; // 🆕 ไอดีหอพักสำหรับกดลิงก์
  final int? roomTypeId; // 🆕 ไอดีห้องพักสำหรับกดลิงก์
  final int? memberId; // 🆕 ไอดีเจ้าของประกาศ ใช้เช็คว่าเป็นประกาศของตัวเองไหม
  final String memberName;
  final String? memberImage;
  final String? memberGender; // 🆕 เพศของเจ้าของประกาศ
  final String? dormName;
  final String? roomTypeName;
  final double? roomPrice;

  // 🆕 พิกัดหอพักที่ผู้ประกาศระบุ — ใช้คำนวณระยะทาง "ใกล้ฉัน" ตอนเรียงลำดับที่หน้า Feed รูมเมท
  final double? dormLatitude;
  final double? dormLongitude;

  // 🚀 มีค่าเมื่อประกาศนี้สร้างมาจากปุ่ม "ประกาศหารูมเมท" บนใบจองที่ยืนยันแล้ว
  // (ไม่ใช่เลือกห้องจาก Bottom Sheet เอง) ใช้โชว์ badge "มีห้องแล้ว" ในหน้า Feed/รายละเอียด
  final int? bookingId;
  bool get hasRoomAlready => bookingId != null;

  // 🚀 จำนวนคนที่จับคู่ (Matched) แล้วสำหรับประกาศนี้ — มีค่าเฉพาะตอนดึงผ่าน getMyPosts
  // (0 เป็นค่าเริ่มต้นเมื่อ endpoint อื่นไม่ได้แนบมาด้วย) ใช้ในหน้า "รูมเมทของฉัน" เพื่อกรอง
  // ประกาศที่จับคู่ได้อย่างน้อย 1 คนแล้ว และเช็คว่าพร้อมกดจองห้องหรือยัง (postStatus=='Found')
  final int matchedCount;
  bool get readyToBook => postStatus == 'Found' && bookingId == null;

  // 🚀 มีค่าเฉพาะตอนดึงผ่าน getMyMatchedPosts (ในฐานะผู้ขอ) — สถานะคำขอจับคู่ "ของฉัน" กับ
  // ประกาศนี้โดยเฉพาะ (Pending/Matched/Rejected/Unmatched/Cancelled) ต่างจาก postStatus ที่เป็น
  // สถานะของประกาศเอง (Searching/Found) ใช้โชว์ filter ดูประวัติที่แท็บ "ที่ฉันจับคู่ด้วย"
  final String? myMatchStatus;

  RoommatePostModel({
    required this.postId,
    required this.reqPersons,
    required this.reqGender,
    required this.reqAgeRange,
    required this.sleepTime,
    required this.smokingAllowed,
    required this.petAllowed,
    required this.cleanliness,
    this.additionalNotes,
    this.createdAt,
    required this.postStatus,
    this.dormId,
    this.roomTypeId,
    this.memberId,
    required this.memberName,
    this.memberImage,
    this.memberGender,
    this.dormName,
    this.roomTypeName,
    this.roomPrice,
    this.dormLatitude,
    this.dormLongitude,
    this.bookingId,
    this.matchedCount = 0,
    this.myMatchStatus,
  });

  factory RoommatePostModel.fromJson(Map<String, dynamic> json) {
    final member = json['Member'];
    String fullName = 'ผู้ใช้งานทั่วไป';
    if (member != null) {
      if (member['First_Name'] != null) {
        fullName = '${member['First_Name']} ${member['Last_Name'] ?? ''}'
            .trim();
      } else if (member['Username'] != null) {
        fullName = member['Username'];
      }
    }

    return RoommatePostModel(
      postId: json['Post_ID'] ?? 0,
      reqPersons: json['Req_Persons'] ?? 1,
      reqGender: json['Req_Gender'] ?? 'Any',
      reqAgeRange: json['Req_Age_Range'] ?? 'Any',
      sleepTime: json['Sleep_Time'] ?? 'Any',
      smokingAllowed: json['Smoking_Allowed'] ?? 'Any',
      petAllowed: json['Pet_Allowed'] ?? 'Any',
      cleanliness: json['Cleanliness'] ?? 'Any',
      additionalNotes: json['Additional_Notes'],
      createdAt: json['Created_At'] != null
          ? DateTime.tryParse(json['Created_At'])
          : null,
      postStatus: json['Post_Status'] ?? 'Searching',

      dormId: json['Dorm_ID'],
      roomTypeId: json['Room_Type_ID'],
      memberId: json['Member_ID'],
      memberName: fullName,
      memberImage: member?['Profile_Image'],
      memberGender: member?['Gender'] ?? 'ไม่ระบุ',
      dormName: json['Dorm']?['Dorm_Name'] ?? 'ไม่ระบุหอพัก',

      // ✅ แก้ไขตรงนี้: ให้ดึง Room_Type_Name มาก่อน ถ้าไม่มีให้ดึง Room_Type
      roomTypeName:
          json['Room_Type']?['Room_Type_Name'] ??
          json['Room_Type']?['Room_Type'] ??
          'ไม่ระบุประเภทห้อง',

      roomPrice: json['Room_Type']?['Price_Per_Month'] != null
          ? double.tryParse(json['Room_Type']['Price_Per_Month'].toString())
          : null,
      dormLatitude: json['Dorm']?['Latitude'] != null
          ? double.tryParse(json['Dorm']['Latitude'].toString())
          : null,
      dormLongitude: json['Dorm']?['Longitude'] != null
          ? double.tryParse(json['Dorm']['Longitude'].toString())
          : null,
      bookingId: json['Booking_ID'],
      matchedCount: json['Matched_Count'] ?? 0,
      myMatchStatus: json['My_Match_Status'],
    );
  }

  // 🚀 ใช้หลังแก้ไขประกาศสำเร็จ — สร้างสำเนาที่อัปเดตเฉพาะเงื่อนไขรูมเมท (fields อื่นเช่น
  // ข้อมูลหอ/ห้อง/เจ้าของประกาศไม่เปลี่ยน เพราะแก้ไขได้แค่เงื่อนไขที่ต้องการเท่านั้น)
  RoommatePostModel copyWith({
    int? reqPersons,
    String? reqGender,
    String? reqAgeRange,
    String? sleepTime,
    String? smokingAllowed,
    String? petAllowed,
    String? cleanliness,
    String? additionalNotes,
  }) {
    return RoommatePostModel(
      postId: postId,
      reqPersons: reqPersons ?? this.reqPersons,
      reqGender: reqGender ?? this.reqGender,
      reqAgeRange: reqAgeRange ?? this.reqAgeRange,
      sleepTime: sleepTime ?? this.sleepTime,
      smokingAllowed: smokingAllowed ?? this.smokingAllowed,
      petAllowed: petAllowed ?? this.petAllowed,
      cleanliness: cleanliness ?? this.cleanliness,
      additionalNotes: additionalNotes ?? this.additionalNotes,
      createdAt: createdAt,
      postStatus: postStatus,
      dormId: dormId,
      roomTypeId: roomTypeId,
      memberId: memberId,
      memberName: memberName,
      memberImage: memberImage,
      memberGender: memberGender,
      dormName: dormName,
      roomTypeName: roomTypeName,
      roomPrice: roomPrice,
      dormLatitude: dormLatitude,
      dormLongitude: dormLongitude,
      bookingId: bookingId,
      matchedCount: matchedCount,
      myMatchStatus: myMatchStatus,
    );
  }
}
