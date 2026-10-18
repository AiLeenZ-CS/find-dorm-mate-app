import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../data/dorm_repository.dart';
import '../domain/dorm_model.dart';
import 'dart:math' as math;

class DormMapScreen extends ConsumerStatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const DormMapScreen({super.key, this.initialLat, this.initialLng});

  @override
  ConsumerState<DormMapScreen> createState() => _DormMapScreenState();
}

class _DormMapScreenState extends ConsumerState<DormMapScreen> {
  GoogleMapController? mapController;

  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _suggestions = [];
  Timer? _debounce;
  bool _isSearching = false;

  late LatLng _centerPoint;
  late double _radiusInKm;

  // 🚀 ตัวแปรเช็คว่าเป็น "โหมดดูหอพักเดียว" หรือไม่
  late bool _isSingleView;

  // 🚀 แคชรูปหมุด "ชื่อหอ + ช่วงราคา" ที่วาดขึ้นเองต่อหอ (คีย์ด้วย Dorm_ID)
  // กันไม่ให้วาดซ้ำทุกครั้งที่ build() เพราะการวาด bitmap มีต้นทุนพอสมควร
  final Map<int, BitmapDescriptor> _dormMarkerIcons = {};
  final Set<int> _generatingMarkerIds = {};
  late final double _devicePixelRatio;

  @override
  void initState() {
    super.initState();
    // ถ้ามีการส่งพิกัดมา แสดงว่าเป็นโหมดดูหอพักเดียว (จากหน้ารายละเอียด)
    _isSingleView = widget.initialLat != null && widget.initialLng != null;
    _devicePixelRatio =
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;

    if (_isSingleView) {
      _centerPoint = LatLng(widget.initialLat!, widget.initialLng!);
      _radiusInKm = 1.0;
    } else {
      _centerPoint = const LatLng(16.2468, 103.2494); // มมส.
      _radiusInKm = 3.0;
    }
  }

  // 🚀 ข้อความช่วงราคาที่จะโชว์บนหมุด: "฿2,500-4,500" หรือ "฿2,500/ด" ถ้ามีราคาเดียว
  String _priceRangeLabel(DormModel dorm) {
    if (dorm.startingPrice == null) return 'ดูรายละเอียด';
    final formatter = NumberFormat('#,##0');
    final min = formatter.format(dorm.startingPrice);
    if (dorm.maxPrice == null || dorm.maxPrice == dorm.startingPrice) {
      return '฿$min/ด';
    }
    final max = formatter.format(dorm.maxPrice);
    return '฿$min-$max';
  }

  // 🚀 วาดหมุดแบบ "ป้ายราคา" เอง (ชื่อหอ + ช่วงราคา) แทนหมุดเปล่าๆ ของ Google Maps
  // เพราะ InfoWindow ของ google_maps_flutter โชว์ได้แค่ตอนแตะเท่านั้น ถ้าอยากให้เห็น
  // ชื่อ/ราคาตลอดเวลาบนแผนที่ต้องวาด bitmap เองแล้วส่งเป็น marker icon
  Future<BitmapDescriptor> _buildPriceTagIcon({
    required String name,
    required String priceLabel,
  }) async {
    const double padding = 10;
    const double gap = 2;
    const double cornerRadius = 14;
    const double pointerWidth = 14;
    const double pointerHeight = 9;
    const double maxTextWidth = 150;

    final namePainter = TextPainter(
      text: TextSpan(
        text: name,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          height: 1.15,
        ),
      ),
      maxLines: 1,
      ellipsis: '…',
      // 🚨 ต้องระบุ ui.TextDirection แบบเจาะจง เพราะ package:intl มีคลาส TextDirection
      // ของตัวเอง (ค่าเป็น .LTR ตัวใหญ่) ชนกับ dart:ui/material ถ้าเขียนแบบไม่ระบุ prefix
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: maxTextWidth);

    final pricePainter = TextPainter(
      text: TextSpan(
        text: priceLabel,
        style: const TextStyle(
          color: Color(0xFFFFD54F), // เหลืองทอง ให้ราคาเด่นบนพื้นม่วง
          fontSize: 13,
          fontWeight: FontWeight.w800,
          height: 1.15,
        ),
      ),
      maxLines: 1,
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: maxTextWidth);

    final contentWidth = math.max(namePainter.width, pricePainter.width);
    final chipWidth = contentWidth + padding * 2;
    final chipHeight =
        namePainter.height + pricePainter.height + gap + padding * 2;
    final totalHeight = chipHeight + pointerHeight;

    final recorder = ui.PictureRecorder();
    // 🚨 ห้ามส่ง cullRect แบบพิกัด logical (ไม่ scale) เข้า Canvas() ตรงนี้ — cullRect
    // ผูกกับพิกัดที่บันทึกจริงหลัง canvas.scale() แล้ว ถ้าใส่กรอบแคบแบบ unscaled มา
    // เนื้อหาที่วาดหลังจาก scale (ซึ่งพิกัดจะโตขึ้นตาม devicePixelRatio) จะโดนตัดขอบจนแทบไม่เหลือ
    // เคยเจอปัญหานี้มาก่อน: bitmap สร้างสำเร็จไม่มี error แต่ภาพว่างเปล่าเพราะโดน clip เกือบหมด
    final canvas = Canvas(recorder);
    canvas.scale(_devicePixelRatio);

    final bgPaint = Paint()..color = const Color(0xFF5E35B1);
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, chipWidth, chipHeight),
      const Radius.circular(cornerRadius),
    );

    canvas.drawShadow(Path()..addRRect(bodyRect), Colors.black45, 3, true);
    canvas.drawRRect(bodyRect, bgPaint);

    // หางป้ายชี้ลงล่าง — ให้ปลายหางตรงกับพิกัดจริงของหอพัก
    final pointerPath = Path()
      ..moveTo(chipWidth / 2 - pointerWidth / 2, chipHeight - 1)
      ..lineTo(chipWidth / 2, totalHeight)
      ..lineTo(chipWidth / 2 + pointerWidth / 2, chipHeight - 1)
      ..close();
    canvas.drawPath(pointerPath, bgPaint);

    namePainter.paint(canvas, Offset(padding, padding));
    pricePainter.paint(
      canvas,
      Offset(padding, padding + namePainter.height + gap),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (chipWidth * _devicePixelRatio).ceil(),
      (totalHeight * _devicePixelRatio).ceil(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    // 🚨 ห้ามส่ง width/height พร้อมกับ imagePixelRatio — ตาม docs ของแพ็กเกจ
    // imagePixelRatio จะถูก "ignore" ทันทีถ้ามี width หรือ height มาด้วย ส่งแค่
    // imagePixelRatio อย่างเดียวพอ เพราะ byte ที่วาดมาคือขนาดจริงที่ scale ด้วย
    // devicePixelRatio แล้ว ให้ตัว renderer คำนวณขนาด logical เองจากค่านี้
    return BitmapDescriptor.bytes(bytes, imagePixelRatio: _devicePixelRatio);
  }

  // 🚀 สร้าง/แคชไอคอนของหอพักแต่ละหอแบบ lazy — เรียกจากใน build() แต่ทำงานนอกรอบ build
  // (สั่ง setState ทีหลังตอนวาดเสร็จ) กันไม่ให้ build() ต้อง await และบล็อกเฟรม
  void _ensureMarkerIcon(DormModel dorm) {
    if (_dormMarkerIcons.containsKey(dorm.id) ||
        _generatingMarkerIds.contains(dorm.id)) {
      return;
    }
    _generatingMarkerIds.add(dorm.id);
    _buildPriceTagIcon(name: dorm.name, priceLabel: _priceRangeLabel(dorm))
        .then((icon) {
          if (!mounted) return;
          setState(() => _dormMarkerIcons[dorm.id] = icon);
        })
        .catchError((error, stack) {
          debugPrint('สร้างหมุดหอพัก ${dorm.id} ไม่สำเร็จ: $error');
          _generatingMarkerIds.remove(dorm.id);
        });
  }

  // ==========================================
  // ฟังก์ชันค้นหาสถานที่แบบ Autocomplete
  // ==========================================
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.trim().isEmpty) {
      setState(() => _suggestions = []);
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _isSearching = true);

      final url =
          'https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=5&countrycodes=th';

      try {
        final response = await http.get(
          Uri.parse(url),
          headers: {
            'User-Agent': 'FindDormMateApp/1.0',
            'Accept-Language': 'th-TH,th;q=0.9',
          },
        );

        if (response.statusCode == 200) {
          final List data = json.decode(response.body);
          setState(() {
            _suggestions = data;
          });
        }
      } catch (e) {
        debugPrint('ค้นหา Error: $e');
      } finally {
        setState(() => _isSearching = false);
      }
    });
  }

  void _selectLocation(dynamic suggestion) {
    FocusScope.of(context).unfocus();

    final double lat = double.parse(suggestion['lat'].toString());
    final double lon = double.parse(suggestion['lon'].toString());
    final newLatLng = LatLng(lat, lon);
    final String displayName = suggestion['display_name'];
    final String shortName = displayName.split(',').first;

    setState(() {
      _centerPoint = newLatLng;
      _searchController.text = shortName;
      _suggestions = [];
    });

    if (mapController != null) {
      double zoomLevel = 14.5 - (math.log(_radiusInKm) / math.log(2));
      mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(newLatLng, zoomLevel),
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('กรุณาเปิด GPS')));
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    setState(() => _isSearching = true);
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final newLatLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _centerPoint = newLatLng;
        _searchController.text = 'ตำแหน่งปัจจุบันของฉัน';
      });

      if (mapController != null) {
        mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            newLatLng,
            14.5 - (math.log(_radiusInKm) / math.log(2)),
          ),
        );
      }
    } catch (e) {
      debugPrint('GPS Error: $e');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dormListAsync = ref.watch(dormListProvider);

    return Scaffold(
      appBar: AppBar(
        // 🚀 เปลี่ยนชื่อหัวข้อตามโหมด
        title: Text(
          _isSingleView ? 'ตำแหน่งหอพัก' : 'ค้นหาหอพักรอบตัว',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // 🚀 เว้นพื้นที่ด้านบนเฉพาะตอนเป็นโหมดค้นหาปกติ
              if (!_isSingleView) const SizedBox(height: 70),

              // --- แถบปรับรัศมี (ซ่อนในโหมดดูหอพักเดียว) ---
              if (!_isSingleView)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      // 🚀 แก้ alpha ที่เดิมตั้งไว้ 0.6 (เงาเข้มเกินไปจนดูเหมือนเส้นขอบทึบ)
                      // ให้เป็นเงานุ่มนวลแบบเดียวกับที่ใช้ทั้งแอป
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.radar, color: Colors.deepPurple),
                      const SizedBox(width: 8),
                      const Text(
                        'รัศมี:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Expanded(
                        child: Slider(
                          value: _radiusInKm,
                          min: 1,
                          max: 15,
                          divisions: 14,
                          activeColor: Colors.deepPurple,
                          inactiveColor: Colors.deepPurple.shade100,
                          label: '${_radiusInKm.round()} กม.',
                          onChanged: (value) {
                            setState(() => _radiusInKm = value);
                            if (mapController != null) {
                              double zoomLevel =
                                  14.5 - (math.log(value) / math.log(2));
                              mapController!.animateCamera(
                                CameraUpdate.newLatLngZoom(
                                  _centerPoint,
                                  zoomLevel,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      Text(
                        '${_radiusInKm.round()} กม.',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ],
                  ),
                ),

              // --- แผนที่ ---
              Expanded(
                child: dormListAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: Colors.deepPurple),
                  ),
                  error: (err, stack) =>
                      Center(child: Text('เกิดข้อผิดพลาด: $err')),
                  data: (dorms) {
                    Set<Marker> activeMarkers = {};

                    if (_isSingleView) {
                      // 🟢 โหมดดูหอพักเดียว: โชว์แค่หมุดหอพักนั้นหมุดเดียว
                      activeMarkers.add(
                        Marker(
                          markerId: const MarkerId('target_dorm'),
                          position: LatLng(
                            widget.initialLat!,
                            widget.initialLng!,
                          ),
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueViolet,
                          ),
                          infoWindow: const InfoWindow(
                            title: 'ตำแหน่งหอพักนี้',
                          ),
                        ),
                      );
                    } else {
                      // 🔵 โหมดค้นหาปกติ: โชว์หมุดแดงจุดศูนย์กลาง + หอพักในรัศมี
                      activeMarkers.add(
                        Marker(
                          markerId: const MarkerId('center_point'),
                          position: _centerPoint,
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueRed,
                          ),
                          infoWindow: const InfoWindow(
                            title: 'จุดศูนย์กลางการค้นหา',
                          ),
                          zIndexInt: 2,
                        ),
                      );

                      for (var dorm in dorms) {
                        if (dorm.latitude != null &&
                            dorm.longitude != null &&
                            dorm.status?.toLowerCase() == 'approved') {
                          double distanceInMeters = Geolocator.distanceBetween(
                            _centerPoint.latitude,
                            _centerPoint.longitude,
                            dorm.latitude!,
                            dorm.longitude!,
                          );

                          if (distanceInMeters <= (_radiusInKm * 1000)) {
                            // 🚀 สร้างหมุด "ชื่อหอ + ช่วงราคา" แบบ lazy (วาดครั้งเดียวแคชไว้)
                            // แทนหมุดเปล่าที่ต้องแตะถึงจะเห็นชื่อ/ราคา
                            _ensureMarkerIcon(dorm);
                            final customIcon = _dormMarkerIcons[dorm.id];

                            activeMarkers.add(
                              Marker(
                                markerId: MarkerId('dorm_${dorm.id}'),
                                position: LatLng(
                                  dorm.latitude!,
                                  dorm.longitude!,
                                ),
                                anchor: const Offset(0.5, 1.0),
                                onTap: () => context.push('/dorm/${dorm.id}'),
                                icon:
                                    customIcon ??
                                    BitmapDescriptor.defaultMarkerWithHue(
                                      BitmapDescriptor.hueViolet,
                                    ),
                                zIndexInt: 1,
                              ),
                            );
                          }
                        }
                      }
                    }

                    return GoogleMap(
                      onMapCreated: (controller) => mapController = controller,
                      initialCameraPosition: CameraPosition(
                        target: _centerPoint,
                        zoom: _isSingleView
                            ? 16.0
                            : 14.5 - (math.log(_radiusInKm) / math.log(2)),
                      ),
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      markers: activeMarkers,
                      circles: _isSingleView
                          ? {}
                          : {
                              Circle(
                                circleId: const CircleId('search_radius'),
                                center: _centerPoint,
                                radius: _radiusInKm * 1000,
                                fillColor: Colors.deepPurple.withValues(
                                  alpha: 0.15,
                                ),
                                strokeColor: Colors.deepPurple,
                                strokeWidth: 2,
                              ),
                            },
                      onLongPress: _isSingleView
                          ? null
                          : (latLng) {
                              // ปิดการเปลี่ยนจุดศูนย์กลาง ถ้าเป็นโหมดดูหอพักเดียว
                              setState(() {
                                _centerPoint = latLng;
                                _searchController.text =
                                    'จุดที่เลือกล่าสุดบนแผนที่';
                              });
                            },
                    );
                  },
                ),
              ),
            ],
          ),

          // --- 🔍 กล่องค้นหาลอย (ซ่อนในโหมดดูหอพักเดียว) ---
          if (!_isSingleView)
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Material(
                          elevation: 4,
                          shadowColor: Colors.black26,
                          borderRadius: BorderRadius.circular(12),
                          child: TextField(
                            controller: _searchController,
                            onChanged: _onSearchChanged,
                            decoration: InputDecoration(
                              hintText: 'พิมพ์ชื่อสถานที่, มหาวิทยาลัย...',
                              prefixIcon: const Icon(
                                Icons.search,
                                color: Colors.deepPurple,
                              ),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 20),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _suggestions = []);
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: _getCurrentLocation,
                        child: Material(
                          elevation: 4,
                          shadowColor: Colors.black26,
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.deepPurple,
                          child: Container(
                            height: 50,
                            width: 50,
                            alignment: Alignment.center,
                            child: _isSearching
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.my_location,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (_suggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      constraints: const BoxConstraints(maxHeight: 250),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 6,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _suggestions.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final suggestion = _suggestions[index];
                          return ListTile(
                            leading: const Icon(
                              Icons.location_on,
                              color: Colors.redAccent,
                            ),
                            title: Text(
                              suggestion['display_name'].split(',').first,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              suggestion['display_name'],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                            onTap: () => _selectLocation(suggestion),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
