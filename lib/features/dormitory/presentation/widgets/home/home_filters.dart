// 📄 ไฟล์นี้ทำหน้าที่: โมเดลเก็บค่าตัวกรองทั้งหมดของหน้า Home ส่งผ่านระหว่าง home_screen.dart
// กับ home_filter_sheet.dart
import 'package:flutter/material.dart';

/// รวมค่าตัวกรองทั้งหมดของหน้า Home ไว้ในที่เดียว ส่งผ่านเข้า/ออกจาก HomeFilterSheet
class HomeFilters {
  final String dormType; // 'All', 'Male', 'Female', 'Mixed'
  final String airFan; // 'All', 'Air', 'Fan'
  final RangeValues priceRange;

  // 🚀 เลือกได้หลายรายการ (multi-select) — เทียบด้วยชื่อ (Facility_Name) ไม่ใช่ ID เพราะ
  // DormModel เก็บสิ่งอำนวยความสะดวกเป็นชื่อล้วนอยู่แล้ว (ดู dorm_model.dart) หลีกเลี่ยงการ
  // เพิ่ม field ID คู่ขนานที่ไม่จำเป็น — ชื่อในตาราง Master ถือว่าไม่ซ้ำกันอยู่แล้วในทางปฏิบัติ
  final Set<String> dormFacilities; // สิ่งอำนวยความสะดวกระดับหอพัก
  final Set<String> roomFacilities; // สิ่งอำนวยความสะดวกระดับห้องพัก

  // 🚀 คะแนนรีวิวขั้นต่ำ (แบบ "X ดาวขึ้นไป") — 0 = ไม่กรอง, 1-5 = ต้องมีคะแนนเฉลี่ย >= ค่านี้
  final int minRating;

  const HomeFilters({
    required this.dormType,
    required this.airFan,
    required this.priceRange,
    this.dormFacilities = const {},
    this.roomFacilities = const {},
    this.minRating = 0,
  });

  bool get hasActiveFilters =>
      dormType != 'All' ||
      airFan != 'All' ||
      priceRange.start > 0 ||
      priceRange.end < 15000 ||
      dormFacilities.isNotEmpty ||
      roomFacilities.isNotEmpty ||
      minRating > 0;

  // 🚀 นับจำนวนตัวกรองที่เปิดใช้งานอยู่ (ไม่รวมช่วงราคาเป็น 1 อย่างเดียว ให้สิ่งอำนวยความ
  // สะดวกแต่ละรายการนับแยก) ใช้โชว์ badge ตัวเลขที่ปุ่มตัวกรองในหน้า Home
  int get activeFilterCount {
    int count = 0;
    if (dormType != 'All') count++;
    if (airFan != 'All') count++;
    if (priceRange.start > 0 || priceRange.end < 15000) count++;
    count += dormFacilities.length;
    count += roomFacilities.length;
    if (minRating > 0) count++;
    return count;
  }

  HomeFilters copyWith({
    String? dormType,
    String? airFan,
    RangeValues? priceRange,
    Set<String>? dormFacilities,
    Set<String>? roomFacilities,
    int? minRating,
  }) {
    return HomeFilters(
      dormType: dormType ?? this.dormType,
      airFan: airFan ?? this.airFan,
      priceRange: priceRange ?? this.priceRange,
      dormFacilities: dormFacilities ?? this.dormFacilities,
      roomFacilities: roomFacilities ?? this.roomFacilities,
      minRating: minRating ?? this.minRating,
    );
  }
}
