// 📄 ไฟล์นี้ทำหน้าที่: โมเดลข้อมูล "หอพัก" แบบย่อ ใช้แสดงในหน้า Home (รายการ/ค้นหา/กรอง) และแผนที่
// เก็บข้อมูลสรุปที่พอใช้แสดงการ์ด/หมุด โดยไม่ต้องดึงรายละเอียดเต็มแบบ DormDetailModel
import 'package:find_dorm_mate/core/utils/json_list_parser.dart';

class DormModel {
  final int id;
  final String name;
  final String? address;
  final double? startingPrice;
  final double? maxPrice; // 🚀 ราคาสูงสุดของห้องในหอนี้ ใช้คู่กับ startingPrice โชว์เป็นช่วงราคาบนแผนที่
  final String? dormType;
  final double? latitude;
  final double? longitude;
  final List<dynamic>? roomTypes;

  // ✅ 1. เพิ่มตัวแปรสำหรับเก็บรูปภาพและสถานะ
  final String? images;
  final String? status;

  // 🚀 สิ่งอำนวยความสะดวกของหอพัก (Master + Custom) เอาไว้ให้หน้า Home ค้นหา/กรองได้
  final List<String> facilities;
  final List<String> customFacilities;

  // 🚀 คะแนนรีวิวเฉลี่ย (1-5 ดาว) และจำนวนรีวิว — ใช้กรอง/โชว์ดาวที่หน้า Home
  // null = ยังไม่มีรีวิวเลย (ไม่ใช่ 0 ดาว เพื่อไม่ให้ไปโผล่ตอนกรองขั้นต่ำ)
  final double? averageRating;
  final int reviewCount;

  DormModel({
    required this.id,
    required this.name,
    this.address,
    this.startingPrice,
    this.maxPrice,
    this.dormType,
    this.roomTypes,
    this.latitude,
    this.longitude,
    this.images, // ✅ 2. เพิ่มใน Constructor
    this.status, // ✅ 2. เพิ่มใน Constructor
    this.facilities = const [],
    this.customFacilities = const [],
    this.averageRating,
    this.reviewCount = 0,
  });

  factory DormModel.fromJson(Map<String, dynamic> json) {
    double? minPrice;
    double? maxPriceValue;
    if (json['Room_Types'] != null && (json['Room_Types'] as List).isNotEmpty) {
      final prices = (json['Room_Types'] as List)
          .map((r) => r['Price_Per_Month'])
          .where((p) => p != null)
          .map((p) => double.tryParse(p.toString()) ?? 0.0)
          .toList();
      if (prices.isNotEmpty) {
        minPrice = prices.reduce((curr, next) => curr < next ? curr : next);
        maxPriceValue = prices.reduce((curr, next) => curr > next ? curr : next);
      }
    }

    return DormModel(
      id: json['Dorm_ID'],
      name: json['Dorm_Name'],
      address: json['Address'],
      dormType: json['Dorm_Type'],
      startingPrice: minPrice,
      maxPrice: maxPriceValue,
      latitude: json['Latitude'] != null
          ? double.tryParse(json['Latitude'].toString())
          : null,
      longitude: json['Longitude'] != null
          ? double.tryParse(json['Longitude'].toString())
          : null,

      // ✅ 3. ดึงค่ารูปภาพและสถานะจาก JSON ที่ Backend ส่งมา
      images: json['Dorm_Images'],
      status: json['Approval_Status'] ?? json['Status'],
      roomTypes: json['Room_Types'] as List<dynamic>?,
      facilities:
          (json['Facilities'] as List?)
              ?.map((f) => f['Facility_Name'].toString())
              .toList() ??
          const [],
      customFacilities: parseStringListJson(json['Custom_Facilities']),
      averageRating: json['Average_Rating'] != null
          ? double.tryParse(json['Average_Rating'].toString())
          : null,
      reviewCount: json['Review_Count'] != null
          ? int.tryParse(json['Review_Count'].toString()) ?? 0
          : 0,
    );
  }
}
