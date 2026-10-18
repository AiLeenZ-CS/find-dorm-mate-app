import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DormMapPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const DormMapPickerScreen({super.key, this.initialLat, this.initialLng});

  @override
  State<DormMapPickerScreen> createState() => _DormMapPickerScreenState();
}

class _DormMapPickerScreenState extends State<DormMapPickerScreen> {
  LatLng? _pickedLocation;

  // พิกัดเริ่มต้น (ตั้งไว้ที่ ม.มหาสารคาม ขามเรียง)
  final LatLng _defaultLocation = const LatLng(16.243201, 103.238885);

  @override
  void initState() {
    super.initState();
    // ถ้าเคยมีพิกัดอยู่แล้ว (ตอนแก้ไข) ให้เอามาแสดง
    if (widget.initialLat != null && widget.initialLng != null) {
      _pickedLocation = LatLng(widget.initialLat!, widget.initialLng!);
    }
  }

  // ฟังก์ชันเมื่อผู้ใช้จิ้มบนแผนที่
  void _selectLocation(LatLng position) {
    setState(() {
      _pickedLocation = position;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ปักหมุดตำแหน่งหอพัก'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          // โชว์ปุ่ม "ยืนยัน" เฉพาะตอนที่จิ้มเลือกพิกัดแล้วเท่านั้น
          if (_pickedLocation != null)
            IconButton(
              icon: const Icon(Icons.check_circle, size: 28),
              tooltip: 'ยืนยันพิกัด',
              onPressed: () {
                Navigator.of(context).pop(_pickedLocation);
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _pickedLocation ?? _defaultLocation,
              zoom: 15,
            ),
            onTap: _selectLocation,
            markers: (_pickedLocation == null)
                ? {}
                : {
                    Marker(
                      markerId: const MarkerId('dorm_pin'),
                      position: _pickedLocation!,
                      infoWindow: const InfoWindow(title: 'ตำแหน่งหอพักของคุณ'),
                    ),
                  },
          ),

          // กล่องข้อความแนะนำตัวลอยๆ ด้านล่าง
          if (_pickedLocation == null)
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.touch_app, color: Colors.teal, size: 30),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'แตะพื้นที่บนแผนที่ 1 ครั้ง\nเพื่อเลือกตำแหน่งหอพักของคุณ',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.teal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
