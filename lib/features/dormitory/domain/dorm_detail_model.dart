import 'package:find_dorm_mate/core/utils/json_list_parser.dart';

class DormDetailModel {
  final int id;
  final String name;
  final String? address;
  final String? dormType;
  final String? images;
  final double? depositFee;
  final double? insuranceFee;
  final String? waterRate; // 🚀 เก็บเป็น String เพราะฝั่ง backend/DB เป็นข้อความอิสระ เช่น "เหมา 100/ด"
  final String? electricRate;
  final int? contractDuration; // เดือน
  final bool isPetFriendly;
  final bool isSmokingAllowed;
  final String? contactInfo;
  final String? description; // 🚀 ข้อความแนะนำหอพักแบบยาวที่เจ้าของพิมพ์เอง
  final List<String> facilities; // Master Facilities (เลือกจาก D5) - ชื่อ ใช้แสดงผล
  final List<int> facilityIds; // 🚀 ID เดียวกัน ใช้ pre-select ตอนแก้ไข
  final List<String> customFacilities; // 🚀 สิ่งอำนวยความสะดวกที่เจ้าของพิมพ์เพิ่มเอง
  final List<RoomTypeModel> roomTypes;
  final double? latitude;
  final double? longitude;
  final double? averageRating;
  final int reviewCount;

  DormDetailModel({
    required this.id,
    required this.name,
    this.address,
    this.dormType,
    this.images,
    this.depositFee,
    this.insuranceFee,
    this.waterRate,
    this.electricRate,
    this.contractDuration,
    this.isPetFriendly = false,
    this.isSmokingAllowed = false,
    this.contactInfo,
    this.description,
    required this.facilities,
    this.facilityIds = const [],
    this.customFacilities = const [],
    required this.roomTypes,
    this.latitude,
    this.longitude,
    this.averageRating,
    this.reviewCount = 0,
  });

  factory DormDetailModel.fromJson(Map<String, dynamic> json) {
    var roomList = json['Room_Types'] as List? ?? [];
    List<RoomTypeModel> rooms = roomList
        .map((r) => RoomTypeModel.fromJson(r))
        .toList();

    return DormDetailModel(
      id: json['Dorm_ID'],
      name: json['Dorm_Name'] ?? 'ไม่มีชื่อหอพัก',
      address: json['Address'],
      dormType: json['Dorm_Type'],
      images: json['Dorm_Images'],
      depositFee: json['Deposit_Fee'] != null
          ? double.tryParse(json['Deposit_Fee'].toString())
          : null,
      insuranceFee: json['Insurance_Fee'] != null
          ? double.tryParse(json['Insurance_Fee'].toString())
          : null,
      waterRate: json['Water_Rate'],
      electricRate: json['Electric_Rate'],
      contractDuration: json['Contract_Duration'],
      // 🚀 แก้บั๊ก: เดิมอ่าน key 'Pet_Friendly'/'Smoking_Allowed' ที่ไม่มีจริงใน response
      // (backend ส่งมาเป็น 'Is_Pet_Friendly'/'Is_Smoking_Allowed' แบบ Boolean) ทำให้
      // หน้าจอแสดง "ไม่อนุญาต" เสมอไม่ว่าค่าจริงจะเป็นอะไร
      isPetFriendly: json['Is_Pet_Friendly'] == true,
      isSmokingAllowed: json['Is_Smoking_Allowed'] == true,
      contactInfo: json['Contact_Info'],
      description: json['Dorm_Description'],
      facilities:
          (json['Facilities'] as List?)
              ?.map((f) => f['Facility_Name'].toString())
              .toList() ??
          [],
      facilityIds:
          (json['Facilities'] as List?)
              ?.map((f) => f['Facility_ID'] as int)
              .toList() ??
          [],
      customFacilities: parseStringListJson(json['Custom_Facilities']),

      roomTypes: rooms,
      latitude: json['Latitude'] != null
          ? double.tryParse(json['Latitude'].toString())
          : null,
      longitude: json['Longitude'] != null
          ? double.tryParse(json['Longitude'].toString())
          : null,
      averageRating: json['Average_Rating'] != null
          ? double.tryParse(json['Average_Rating'].toString())
          : null,
      reviewCount: json['Review_Count'] ?? 0,
    );
  }
}

class RoomTypeModel {
  final int id;
  final String? name;
  final String? type; // 🆕 เพิ่มตัวแปรสำหรับเก็บคำว่า Air / Fan เผื่อใช้งาน
  final double? price;
  final int? remaining;
  final String? status;

  RoomTypeModel({
    required this.id,
    this.name,
    this.type, // 🆕
    this.price,
    this.remaining,
    this.status,
  });

  factory RoomTypeModel.fromJson(Map<String, dynamic> json) {
    return RoomTypeModel(
      id: json['Room_Type_ID'],
      // 🚀 ดึง Room_Type_Name มาแสดง ถ้าไม่มีให้ดึง Room_Type แทน
      name: json['Room_Type_Name'] ?? json['Room_Type'] ?? 'ไม่ระบุชื่อห้อง',
      type: json['Room_Type'], // 🆕
      price: json['Price_Per_Month'] != null
          ? double.tryParse(json['Price_Per_Month'].toString())
          : null,
      remaining: json['Remaining_Rooms'],
      status: json['Room_Status'],
    );
  }
}
