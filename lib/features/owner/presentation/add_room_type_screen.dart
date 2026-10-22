// 📄 ไฟล์นี้ทำหน้าที่: หน้าฟอร์มจัดการ "ประเภทห้องพัก" ฝั่งเจ้าของหอ (owner) ใช้ได้สองโหมดในหน้าเดียว
// — โหมดเพิ่มห้องใหม่ (ไม่ส่ง existingRoom) และโหมดแก้ไขห้องเดิม (ส่ง existingRoom มาเติมฟอร์ม)
import 'dart:io';
import 'dart:convert';
import 'package:find_dorm_mate/core/services/storage_service.dart';
import 'package:find_dorm_mate/core/utils/json_list_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:find_dorm_mate/features/dormitory/data/dorm_repository.dart';
import 'package:find_dorm_mate/features/dormitory/domain/room_type_detail_model.dart';
import 'package:find_dorm_mate/core/widgets/app_text_field.dart';
import 'package:find_dorm_mate/core/widgets/primary_button.dart';
import 'package:find_dorm_mate/core/widgets/numbered_section_title.dart';
import 'package:find_dorm_mate/core/widgets/soft_card.dart';

const _tealAccent = Colors.teal;

class AddRoomTypeScreen extends ConsumerStatefulWidget {
  final int dormId;
  // 🚀 มีค่า = โหมดแก้ไขห้องพักเดิม (ดึงค่าเริ่มต้นจากห้องนี้มาเติมในฟอร์ม และตอนบันทึก
  // จะเรียก updateRoomType แทน createRoomType) — ไม่มีค่า = โหมดเพิ่มห้องใหม่ตามปกติ
  final RoomTypeDetailModel? existingRoom;

  const AddRoomTypeScreen({
    super.key,
    required this.dormId,
    this.existingRoom,
  });

  @override
  ConsumerState<AddRoomTypeScreen> createState() => _AddRoomTypeScreenState();
}

class _AddRoomTypeScreenState extends ConsumerState<AddRoomTypeScreen> {
  final _formKey = GlobalKey<FormState>();
  final StorageService _storageService = StorageService();

  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _totalRoomsController = TextEditingController();
  final _remainingRoomsController = TextEditingController();

  String _roomType = 'Air';
  String _roomStatus = 'Available';

  List<File> _selectedImages = [];
  // 🚀 รูปเดิมของห้อง (เฉพาะโหมดแก้ไข) — URL จาก API ที่ยังเลือกเก็บไว้
  final List<String> _existingImages = [];
  final List<int> _selectedFacilities = []; // Master Facilities (เลือกจาก D5)
  bool _isLoading = false;
  bool _isDeleting = false;

  bool get _isEditMode => widget.existingRoom != null;

  // 🚀 Custom Facilities: สิ่งอำนวยความสะดวกของห้องที่เจ้าของพิมพ์เพิ่มเอง
  final List<String> _customFacilities = [];
  final TextEditingController _customFacilityController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    final existing = widget.existingRoom;
    if (existing == null) return;

    // 🚀 โหมดแก้ไข — เติมค่าเดิมของห้องลงในฟอร์มทั้งหมด รวมถึงรูปภาพเดิมด้วย
    _nameController.text = existing.name ?? '';
    _priceController.text = existing.price != null
        ? existing.price!.toStringAsFixed(0)
        : '';
    _totalRoomsController.text = existing.totalRooms?.toString() ?? '';
    _remainingRoomsController.text = existing.remainingRooms?.toString() ?? '';
    _roomType = existing.type ?? 'Air';
    _roomStatus = existing.roomStatus ?? 'Available';
    _selectedFacilities.addAll(existing.facilityIds);
    _customFacilities.addAll(existing.customFacilities);
    _existingImages.addAll(parseStringListJson(existing.roomImages));
  }

  int get _totalImageCount => _existingImages.length + _selectedImages.length;

  void _removeExistingImage(int index) {
    setState(() => _existingImages.removeAt(index));
  }

  void _addCustomFacility() {
    final text = _customFacilityController.text.trim();
    if (text.isEmpty) return;
    if (_customFacilities.contains(text)) {
      _customFacilityController.clear();
      return;
    }
    setState(() {
      _customFacilities.add(text);
      _customFacilityController.clear();
    });
  }

  void _removeCustomFacility(int index) {
    setState(() => _customFacilities.removeAt(index));
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(imageQuality: 80);

    if (pickedFiles.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(pickedFiles.map((file) => File(file.path)));

        final overflow = _totalImageCount - 8;
        if (overflow > 0) {
          _selectedImages = _selectedImages.sublist(
            0,
            _selectedImages.length - overflow,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('เลือกรูปได้สูงสุด 8 รูปเท่านั้น')),
          );
        }
      });
    }
  }

  Future<List<String>> _uploadImages() async {
    List<String> uploadedUrls = [];
    for (var file in _selectedImages) {
      final url = await _storageService.uploadImage(
        file,
        folderName: 'room_images',
      );
      uploadedUrls.add(url);
    }
    return uploadedUrls;
  }

  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) return;

    if (_totalImageCount < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'กรุณามีรูปภาพอย่างน้อย 3 รูป',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 🚀 อัปโหลดเฉพาะรูปใหม่ที่ยังเป็นไฟล์ในเครื่อง แล้วรวมกับรูปเดิมที่เหลืออยู่
      // (ใช้ร่วมกันทั้งโหมดสร้างใหม่และแก้ไข — โหมดสร้างใหม่ _existingImages จะว่างอยู่แล้ว)
      final uploadedUrls = await _uploadImages();
      if (uploadedUrls.length != _selectedImages.length) {
        throw Exception('อัปโหลดรูปภาพบางส่วนไม่สำเร็จ กรุณาลองใหม่');
      }
      final allImages = [..._existingImages, ...uploadedUrls];

      if (_isEditMode) {
        final roomData = {
          "Room_Type_Name": _nameController.text,
          "Room_Type": _roomType,
          "Price_Per_Month": _priceController.text,
          "Total_Rooms": _totalRoomsController.text,
          "Remaining_Rooms": _remainingRoomsController.text,
          "Room_Status": _roomStatus,
          "Room_Images": jsonEncode(allImages),
          "Facilities": _selectedFacilities,
          "Custom_Facilities": _customFacilities,
        };

        await ref
            .read(dormRepositoryProvider)
            .updateRoomType(widget.existingRoom!.id, roomData);
        ref.invalidate(roomTypeDetailProvider(widget.existingRoom!.id));
        ref.invalidate(dormDetailProvider(widget.dormId));

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('บันทึกการแก้ไขสำเร็จ'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
        return;
      }

      final roomData = {
        "Room_Type_Name": _nameController.text,
        "Room_Type": _roomType,
        "Price_Per_Month": _priceController.text,
        "Total_Rooms": _totalRoomsController.text,
        "Remaining_Rooms": _remainingRoomsController.text,
        "Room_Images": jsonEncode(allImages),
        "Room_Status": _roomStatus,
        "Dorm_ID": widget.dormId,
        "Facilities": _selectedFacilities,
        "Custom_Facilities": _customFacilities,
      };

      await ref.read(dormRepositoryProvider).createRoomType(roomData);
      ref.invalidate(dormDetailProvider(widget.dormId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เพิ่มข้อมูลห้องพักสำเร็จ! 🎉'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🚀 ลบห้องพักประเภทนี้ — backend จะปฏิเสธถ้ามีคนกำลังจอง/เข้าพักอยู่ (Booking_Status
  // Pending/Confirmed) กดแล้วต้องยืนยันอีกชั้นเพราะลบแล้วกู้คืนไม่ได้
  Future<void> _deleteRoom() async {
    final roomId = widget.existingRoom!.id;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'ลบห้องพักนี้?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('ลบแล้วกู้คืนไม่ได้ ยืนยันที่จะลบไหม?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            child: const Text('ยืนยันลบ'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);
    try {
      await ref.read(dormRepositoryProvider).deleteRoomType(roomId);
      ref.invalidate(roomTypeDetailProvider(roomId));
      ref.invalidate(dormDetailProvider(widget.dormId));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ลบห้องพักสำเร็จ'),
          backgroundColor: Colors.green,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'แก้ไขข้อมูลห้องพัก' : 'เพิ่มประเภทห้องพัก',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: _tealAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isEditMode)
            IconButton(
              onPressed: _isDeleting ? null : _deleteRoom,
              icon: _isDeleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.delete_outline),
              tooltip: 'ลบห้องพักนี้',
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.symmetric(
                  vertical: 32,
                  horizontal: 24,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: _tealAccent),
                    const SizedBox(height: 20),
                    Text(
                      _isEditMode
                          ? 'กำลังบันทึกการแก้ไข...'
                          : 'กำลังบันทึกข้อมูลห้องพัก...',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _tealAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'กรุณารอสักครู่ ห้ามปิดหน้านี้',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- หัวข้อแนะนำการกรอกฟอร์ม ---
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_tealAccent, _tealAccent.shade400],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.meeting_room_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'เพิ่มประเภทห้องพักใหม่',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'ระบุรายละเอียดห้องให้ครบถ้วนเพื่อให้ผู้เช่า'
                                  'ตัดสินใจได้ง่ายขึ้น',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12.5,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- 1. รูปภาพห้องพัก ---
                    _buildImageSection(),
                    const SizedBox(height: 20),

                    // --- 2. ข้อมูลทั่วไปของห้อง ---
                    NumberedSectionTitle(
                      step: 2,
                      title: 'ข้อมูลห้องพัก',
                      subtitle: 'รายละเอียด ราคา และจำนวนห้อง',
                      accentColor: _tealAccent,
                    ),
                    const SizedBox(height: 12),
                    SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppTextField(
                            controller: _nameController,
                            labelText: 'ชื่อห้องพัก (เช่น ห้อง VIP ริมระเบียง)',
                            prefixIcon: Icons.bedroom_parent_outlined,
                            accentColor: _tealAccent,
                            validator: (v) =>
                                v!.isEmpty ? 'กรุณากรอกข้อมูล' : null,
                          ),
                          const SizedBox(height: 20),
                          DropdownButtonFormField<String>(
                            value: _roomType,
                            decoration: InputDecoration(
                              labelText: 'ประเภทห้องพัก',
                              prefixIcon: const Icon(Icons.ac_unit, color: _tealAccent),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Air',
                                child: Text('ห้องแอร์'),
                              ),
                              DropdownMenuItem(
                                value: 'Fan',
                                child: Text('ห้องพัดลม'),
                              ),
                            ],
                            onChanged: (val) =>
                                setState(() => _roomType = val!),
                          ),
                          const SizedBox(height: 20),
                          AppTextField(
                            controller: _priceController,
                            labelText: 'ราคาต่อเดือน (บาท)',
                            prefixIcon: Icons.payments,
                            keyboardType: TextInputType.number,
                            accentColor: _tealAccent,
                            validator: (v) =>
                                v!.isEmpty ? 'กรุณากรอกข้อมูล' : null,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: AppTextField(
                                  controller: _totalRoomsController,
                                  labelText: 'จำนวนห้องทั้งหมด',
                                  prefixIcon: Icons.room_preferences,
                                  keyboardType: TextInputType.number,
                                  accentColor: _tealAccent,
                                  validator: (v) =>
                                      v!.isEmpty ? 'กรุณากรอกข้อมูล' : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: AppTextField(
                                  controller: _remainingRoomsController,
                                  labelText: 'จำนวนห้องว่าง',
                                  prefixIcon: Icons.event_available,
                                  keyboardType: TextInputType.number,
                                  accentColor: _tealAccent,
                                  validator: (v) =>
                                      v!.isEmpty ? 'กรุณากรอกข้อมูล' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          DropdownButtonFormField<String>(
                            value: _roomStatus,
                            decoration: InputDecoration(
                              labelText: 'สถานะห้องพัก',
                              prefixIcon: const Icon(Icons.info_outline, color: _tealAccent),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Available',
                                child: Text('ห้องว่าง'),
                              ),
                              DropdownMenuItem(
                                value: 'Full',
                                child: Text('ห้องเต็ม'),
                              ),
                              DropdownMenuItem(
                                value: 'Maintenance',
                                child: Text('กำลังปรับปรุง'),
                              ),
                            ],
                            onChanged: (val) =>
                                setState(() => _roomStatus = val!),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- 3. สิ่งอำนวยความสะดวก ---
                    NumberedSectionTitle(
                      step: 3,
                      title: 'สิ่งอำนวยความสะดวกในห้อง',
                      subtitle: 'เลือกสิ่งที่มีให้บริการในห้องนี้',
                      accentColor: _tealAccent,
                    ),
                    const SizedBox(height: 12),
                    SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'เลือกสิ่งอำนวยความสะดวกที่มีในห้องพักนี้',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 12),
                          _buildFacilitySection(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- 3.5 สิ่งอำนวยความสะดวกที่พิมพ์เพิ่มเอง (Custom Facilities) ---
                    NumberedSectionTitle(
                      step: 4,
                      title: 'สิ่งอำนวยความสะดวกอื่นๆ (พิมพ์เพิ่มเอง)',
                      subtitle: 'เพิ่มเติมสิ่งที่ไม่มีในรายการด้านบน',
                      accentColor: _tealAccent,
                    ),
                    const SizedBox(height: 12),
                    SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ถ้ามีสิ่งอำนวยความสะดวกที่ไม่อยู่ในรายการด้านบน พิมพ์เพิ่มได้เอง',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: AppTextField(
                                  controller: _customFacilityController,
                                  hintText: 'เช่น มีระเบียง',
                                  accentColor: _tealAccent,
                                  onFieldSubmitted: (_) => _addCustomFacility(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filled(
                                style: IconButton.styleFrom(
                                  backgroundColor: _tealAccent,
                                ),
                                onPressed: _addCustomFacility,
                                icon: const Icon(Icons.add),
                              ),
                            ],
                          ),
                          if (_customFacilities.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _customFacilities
                                  .asMap()
                                  .entries
                                  .map(
                                    (entry) => Chip(
                                      label: Text(entry.value),
                                      deleteIcon: const Icon(
                                        Icons.close,
                                        size: 18,
                                      ),
                                      onDeleted: () =>
                                          _removeCustomFacility(entry.key),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    PrimaryButton(
                      label: _isEditMode ? 'บันทึกการแก้ไข' : 'บันทึกข้อมูลห้องพัก',
                      onPressed: _submitData,
                      icon: _isEditMode ? Icons.save_outlined : Icons.cloud_upload,
                      backgroundColor: _tealAccent,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  // --- 🚀 ส่วนอัปโหลดรูปภาพห้องพัก — แสดงทั้งรูปเดิม (network, โหมดแก้ไข) และรูปใหม่
  // (file ในเครื่อง) รวมกันในกริดเดียว ลบได้ทั้งสองแบบ ---
  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const NumberedSectionTitle(
          step: 1,
          title: 'รูปภาพห้องพัก',
          subtitle: 'ภาพถ่ายจริงจะช่วยดึงดูดผู้เช่าได้มากขึ้น',
          accentColor: _tealAccent,
        ),
        const SizedBox(height: 12),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'อัปโหลดภาพบรรยากาศห้องพัก (3-8 รูป)',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._existingImages.asMap().entries.map((entry) {
                    final index = entry.key;
                    final url = entry.value;
                    return _buildImageTile(
                      image: Image.network(
                        url,
                        width: 110,
                        height: 110,
                        fit: BoxFit.cover,
                      ),
                      isCover: index == 0,
                      onRemove: () => _removeExistingImage(index),
                    );
                  }),
                  ..._selectedImages.asMap().entries.map((entry) {
                    final index = entry.key;
                    final imageFile = entry.value;
                    return _buildImageTile(
                      image: Image.file(
                        imageFile,
                        width: 110,
                        height: 110,
                        fit: BoxFit.cover,
                        cacheWidth: 220,
                      ),
                      isCover: _existingImages.isEmpty && index == 0,
                      onRemove: () =>
                          setState(() => _selectedImages.removeAt(index)),
                    );
                  }),
                  if (_totalImageCount < 8)
                    InkWell(
                      onTap: _pickImages,
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: _tealAccent.shade50,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _tealAccent.shade200,
                            width: 1.4,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo_outlined,
                              color: _tealAccent.shade400,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '$_totalImageCount/8',
                              style: TextStyle(
                                color: _tealAccent.shade700,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              if (_totalImageCount == 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    '* จำเป็นต้องมีอย่างน้อย 3 ภาพ',
                    style: TextStyle(color: Colors.red.shade400, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageTile({
    required Widget image,
    required bool isCover,
    required VoidCallback onRemove,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(borderRadius: BorderRadius.circular(18), child: image),
        ),
        if (isCover)
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _tealAccent.shade700,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'ภาพปก',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        Positioned(
          top: -8,
          right: -8,
          child: InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
              child: const Icon(Icons.cancel, color: Colors.redAccent, size: 22),
            ),
          ),
        ),
      ],
    );
  }

  // --- 🚀 จัดการส่วน Facilities (คงเดิมไว้) ---
  Widget _buildFacilitySection() {
    return ref
        .watch(roomFacilitiesProvider)
        .when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: _tealAccent),
          ),
          error: (e, s) =>
              Text('Error: $e', style: const TextStyle(color: Colors.red)),
          data: (facilities) {
            if (facilities.isEmpty) {
              return const Text('ยังไม่มีข้อมูลสิ่งอำนวยความสะดวกในระบบ');
            }
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 3.5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: facilities.length,
              itemBuilder: (context, index) {
                final f = facilities[index];
                final id = f['Facility_ID'];
                final isSelected = _selectedFacilities.contains(id);
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedFacilities.remove(id);
                      } else {
                        _selectedFacilities.add(id);
                      }
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _tealAccent.shade50
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? _tealAccent
                            : Colors.transparent,
                        width: isSelected ? 1.5 : 0,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: isSelected ? _tealAccent : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            f['Facility_Name'],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? _tealAccent.shade800
                                  : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
  }
}
