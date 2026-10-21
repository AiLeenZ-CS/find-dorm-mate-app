// 📄 ไฟล์นี้ทำหน้าที่: Data class เก็บค่าตัวกรองของหน้า Feed รูมเมท ส่งผ่านเข้า/ออกระหว่าง
// roommate_feed_screen และ roommate_filter_sheet
import 'package:flutter/material.dart';

/// รวมค่าตัวกรองทั้งหมดของหน้า Feed รูมเมท — กรองจากข้อมูลที่ผู้ประกาศระบุไว้ในประกาศเอง
/// (เพศที่ต้องการ, ช่วงอายุ, เวลานอน, บุหรี่, สัตว์เลี้ยง, ความสะอาด) ส่งผ่านเข้า/ออกจาก
/// RoommateFilterSheet
class RoommateFilters {
  final String reqGender; // 'Any' (ทั้งหมด ไม่กรอง), 'Male', 'Female', 'Any' (ไม่จำกัดเพศ)
  final String sleepTime; // 'All', 'Before midnight', 'After midnight', 'Any'
  final String smokingAllowed; // 'All', 'Smoking', 'Non_Smoking', 'Any'
  final String petAllowed; // 'All', 'Pet_Friendly', 'No_Pets', 'Any'
  final String cleanliness; // 'All', 'Very', 'Normal', 'Easy', 'Any'
  final RangeValues ageRange; // 18-50 เต็มช่วง = ไม่กรอง
  final bool onlyWithRoom; // true = โชว์เฉพาะประกาศที่ "มีห้องแล้ว"

  const RoommateFilters({
    this.reqGender = 'All',
    this.sleepTime = 'All',
    this.smokingAllowed = 'All',
    this.petAllowed = 'All',
    this.cleanliness = 'All',
    this.ageRange = const RangeValues(18, 50),
    this.onlyWithRoom = false,
  });

  bool get hasActiveFilters =>
      reqGender != 'All' ||
      sleepTime != 'All' ||
      smokingAllowed != 'All' ||
      petAllowed != 'All' ||
      cleanliness != 'All' ||
      ageRange.start > 18 ||
      ageRange.end < 50 ||
      onlyWithRoom;

  int get activeFilterCount {
    int count = 0;
    if (reqGender != 'All') count++;
    if (sleepTime != 'All') count++;
    if (smokingAllowed != 'All') count++;
    if (petAllowed != 'All') count++;
    if (cleanliness != 'All') count++;
    if (ageRange.start > 18 || ageRange.end < 50) count++;
    if (onlyWithRoom) count++;
    return count;
  }

  RoommateFilters copyWith({
    String? reqGender,
    String? sleepTime,
    String? smokingAllowed,
    String? petAllowed,
    String? cleanliness,
    RangeValues? ageRange,
    bool? onlyWithRoom,
  }) {
    return RoommateFilters(
      reqGender: reqGender ?? this.reqGender,
      sleepTime: sleepTime ?? this.sleepTime,
      smokingAllowed: smokingAllowed ?? this.smokingAllowed,
      petAllowed: petAllowed ?? this.petAllowed,
      cleanliness: cleanliness ?? this.cleanliness,
      ageRange: ageRange ?? this.ageRange,
      onlyWithRoom: onlyWithRoom ?? this.onlyWithRoom,
    );
  }
}
