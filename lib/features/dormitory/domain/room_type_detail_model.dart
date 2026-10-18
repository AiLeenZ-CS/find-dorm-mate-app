import 'package:find_dorm_mate/core/utils/json_list_parser.dart';

class RoomTypeDetailModel {
  final int id;
  final String? name;
  final String? type; // 🆕 เพิ่มตัวแปรสำหรับเก็บคำว่า Air / Fan เผื่อใช้งาน
  final double? price;
  final int? totalRooms;
  final int? remainingRooms;
  final String? roomImages;
  final String? roomStatus;
  final List<String> facilities; // Master Facilities (เลือกจาก D5)
  final List<int> facilityIds; // 🚀 ID เดียวกัน ใช้ pre-select ตอนแก้ไข
  final List<String> customFacilities; // 🚀 สิ่งอำนวยความสะดวกที่เจ้าของพิมพ์เพิ่มเอง
  final String? dormName;
  final int? dormId; // 🚀 ใช้ตอนกดแก้ไขห้อง (ต้องรู้ว่าห้องนี้อยู่หอไหน)

  RoomTypeDetailModel({
    required this.id,
    this.name,
    this.type, // 🆕
    this.price,
    this.totalRooms,
    this.remainingRooms,
    this.roomImages,
    this.roomStatus,
    required this.facilities,
    this.facilityIds = const [],
    this.customFacilities = const [],
    this.dormName,
    this.dormId,
  });

  factory RoomTypeDetailModel.fromJson(Map<String, dynamic> json) {
    return RoomTypeDetailModel(
      id: json['Room_Type_ID'],
      // 🚀 ดึง Room_Type_Name มาแสดง ถ้าไม่มีให้ดึง Room_Type แทน
      name: json['Room_Type_Name'] ?? json['Room_Type'] ?? 'ไม่ระบุชื่อห้อง',
      type: json['Room_Type'], // 🆕
      price: json['Price_Per_Month'] != null
          ? double.tryParse(json['Price_Per_Month'].toString())
          : null,
      totalRooms: json['Total_Rooms'],
      remainingRooms: json['Remaining_Rooms'],
      roomImages: json['Room_Images'],
      roomStatus: json['Room_Status'],
      facilities:
          (json['Facilities'] as List?)
              ?.map((f) => f['Facility_Name'].toString())
              .toList() ??
          [],
      facilityIds:
          (json['Facilities'] as List?)
              ?.map((f) => f['Facility_ID'] as int)
              .toList() ??
          const [],
      customFacilities: parseStringListJson(json['Custom_Facilities']),

      dormName: json['Dorm'] != null ? json['Dorm']['Dorm_Name'] : 'ไม่ระบุ',
      dormId: json['Dorm_ID'],
    );
  }
}
