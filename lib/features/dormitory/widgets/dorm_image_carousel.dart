// 📄 ไฟล์นี้ทำหน้าที่: widget แสดงรูปภาพหอพัก/ห้องพักแบบเลื่อนดูได้หลายรูป (parse string รูปจาก DB)
// ใช้ร่วมกันหลายที่ เช่น dorm_card.dart ในหน้า Home
import 'dart:convert';
import 'package:flutter/material.dart';

class DormImageCarousel extends StatefulWidget {
  final String? imageString; // รับค่า String ของรูปภาพมาจาก Database
  final double height; // กำหนดความสูงของกรอบรูป (ค่าเริ่มต้น 200)

  const DormImageCarousel({
    super.key,
    required this.imageString,
    this.height = 200,
  });

  @override
  State<DormImageCarousel> createState() => _DormImageCarouselState();
}

class _DormImageCarouselState extends State<DormImageCarousel> {
  int _currentImageIndex = 0;

  List<String> _parseImages(String? dataString) {
    if (dataString == null || dataString.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(dataString);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (e) {
      String cleaned = dataString.replaceAll(RegExp(r'[\[\]"]'), '');
      return cleaned
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final images = _parseImages(widget.imageString);

    // ถ้าไม่มีรูปภาพเลย ให้แสดงไอคอนตึก
    if (images.isEmpty) {
      return Container(
        height: widget.height,
        width: double.infinity,
        color: Colors.grey.shade200,
        child: const Center(
          child: Icon(Icons.apartment, size: 64, color: Colors.grey),
        ),
      );
    }

    // ถ้ามีรูปเดียว ไม่ต้องใส่ PageView ให้เลื่อน
    if (images.length == 1) {
      return SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Image.network(
          images[0],
          fit: BoxFit.cover,
          // 🚀 จำกัดขนาด decode ไว้ไม่ให้เกินความละเอียดที่ใช้แสดงผลจริง กันรูปต้นฉบับ
          // ความละเอียดสูง (เช่นจากกล้องมือถือ) กิน RAM เกินจำเป็นตอนโหลดในลิสต์การ์ดจำนวนมาก
          cacheWidth: 800,
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.grey.shade200,
            child: const Center(
              child: Icon(Icons.broken_image, color: Colors.grey),
            ),
          ),
        ),
      );
    }

    // ถ้ามีหลายรูป สร้าง PageView ปัดซ้ายขวาได้
    return Stack(
      children: [
        SizedBox(
          height: widget.height,
          width: double.infinity,
          child: PageView.builder(
            itemCount: images.length,
            onPageChanged: (index) {
              setState(() {
                _currentImageIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return Image.network(
                images[index],
                fit: BoxFit.cover,
                cacheWidth: 800,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
              );
            },
          ),
        ),

        // 📌 ตัวเลขแสดงหน้า (เช่น 1 / 5) จะโชว์เฉพาะเวลามีรูปมากกว่า 1 รูป
        Positioned(
          bottom: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_currentImageIndex + 1} / ${images.length}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
