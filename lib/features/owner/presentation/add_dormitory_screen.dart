// 📄 ไฟล์นี้ทำหน้าที่: หน้าฟอร์ม "ลงประกาศหอพักใหม่" ฝั่งเจ้าของหอ (owner) — กรอกข้อมูลหอพัก,
// อัปโหลดรูปภาพ/เอกสารยืนยันความเป็นเจ้าของ, ปักหมุดแผนที่ แล้วส่งให้แอดมินตรวจสอบก่อนเผยแพร่
import 'dart:convert';
import 'dart:io';
import 'package:find_dorm_mate/core/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:find_dorm_mate/features/dormitory/data/dorm_repository.dart';
import 'package:find_dorm_mate/features/owner/presentation/dorm_map_picker_screen.dart';
import 'package:find_dorm_mate/core/widgets/app_text_field.dart';
import 'package:find_dorm_mate/core/widgets/primary_button.dart';
import 'package:find_dorm_mate/core/widgets/numbered_section_title.dart';
import 'package:find_dorm_mate/core/widgets/soft_card.dart';

const _tealAccent = Colors.teal;

class AddDormitoryScreen extends ConsumerStatefulWidget {
  const AddDormitoryScreen({super.key});

  @override
  ConsumerState<AddDormitoryScreen> createState() => _AddDormitoryScreenState();
}

class _AddDormitoryScreenState extends ConsumerState<AddDormitoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final StorageService _storageService = StorageService();

  // --- Controllers สำหรับรับค่าจากฟอร์ม ---
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _waterRateController = TextEditingController();
  final TextEditingController _electricRateController = TextEditingController();
  final TextEditingController _depositController = TextEditingController();
  final TextEditingController _insuranceController = TextEditingController();
  final TextEditingController _contractDurationController =
      TextEditingController();
  final TextEditingController _descriptionController =
      TextEditingController(); // 🚀 รายละเอียดหอพักแบบยาว (Free-text)

  String _dormType = 'รวม';
  bool _isPetFriendly = false;
  bool _isSmokingAllowed = false;

  bool _isLoading = false;
  LatLng? _selectedLocation;
  final LatLng _defaultMiniMapLocation = const LatLng(16.243201, 103.238885);

  // 🚀 1. เปลี่ยนตัวแปรมาเก็บเป็น File แทน String URL
  final List<File> _ownershipImages = [];
  final List<File> _dormImages = [];

  final List<int> _selectedFacilities = []; // เก็บ ID ที่ผู้ใช้ติ๊กเลือก (Master Facilities)

  // 🚀 Custom Facilities: สิ่งอำนวยความสะดวกที่เจ้าของพิมพ์เพิ่มเอง (ไม่ได้อยู่ใน Master List)
  final List<String> _customFacilities = [];
  final TextEditingController _customFacilityController =
      TextEditingController();

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

  Future<void> _addOwnershipImage() async {
    if (_ownershipImages.length >= 5) return;

    File? file = await _storageService.pickImage();
    if (file != null) {
      setState(() {
        _ownershipImages.add(file);
      });
    }
  }

  Future<void> _addDormImage() async {
    if (_dormImages.length >= 10) return;

    File? file = await _storageService.pickImage();
    if (file != null) {
      setState(() {
        _dormImages.add(file);
      });
    }
  }

  Future<void> _openMapPicker() async {
    final selectedLocation = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DormMapPickerScreen(
          initialLat: _selectedLocation?.latitude,
          initialLng: _selectedLocation?.longitude,
        ),
      ),
    );

    if (selectedLocation != null) {
      setState(() => _selectedLocation = selectedLocation as LatLng);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ปักหมุดแผนที่สำเร็จ! 📍'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_ownershipImages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'กรุณาอัปโหลดเอกสารยืนยันความเป็นเจ้าของอย่างน้อย 1 ภาพ',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_dormImages.length < 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('กรุณาอัปโหลดรูปภาพหอพักอย่างน้อย 3 ภาพ'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_selectedLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('กรุณาปักหมุดพิกัดหอพักบนแผนที่'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        String mappedDormType = 'Mixed';
        if (_dormType == 'ชาย') mappedDormType = 'Male';
        if (_dormType == 'หญิง') mappedDormType = 'Female';

        List<String> uploadedOwnershipUrls = [];
        for (var file in _ownershipImages) {
          final url = await _storageService.uploadImage(
            file,
            folderName: 'ownership_proof',
          );
          uploadedOwnershipUrls.add(url);
        }

        List<String> uploadedDormUrls = [];
        for (var file in _dormImages) {
          final url = await _storageService.uploadImage(
            file,
            folderName: 'dorm_images',
          );
          uploadedDormUrls.add(url);
        }

        if (uploadedOwnershipUrls.isEmpty || uploadedDormUrls.length < 3) {
          throw Exception('การอัปโหลดรูปภาพไม่สมบูรณ์ กรุณาลองใหม่อีกครั้ง');
        }

        final newDormData = {
          "Dorm_Name": _nameController.text,
          "Dorm_Type": mappedDormType,
          "Address": _addressController.text,
          "Latitude": _selectedLocation!.latitude,
          "Longitude": _selectedLocation!.longitude,
          "Contact_Info": _contactController.text,
          "Dorm_Description": _descriptionController.text.isEmpty
              ? null
              : _descriptionController.text,
          "Water_Rate": _waterRateController.text.isEmpty
              ? null
              : _waterRateController.text,
          "Electric_Rate": _electricRateController.text.isEmpty
              ? null
              : _electricRateController.text,
          "Deposit_Fee": double.tryParse(_depositController.text),
          "Insurance_Fee": double.tryParse(_insuranceController.text),
          "Contract_Duration": int.tryParse(_contractDurationController.text),
          "Is_Pet_Friendly": _isPetFriendly,
          "Is_Smoking_Allowed": _isSmokingAllowed,

          "Ownership_Proof_Image": uploadedOwnershipUrls.first,
          "Dorm_Images": jsonEncode(uploadedDormUrls),
          "Facilities": _selectedFacilities,
          "Custom_Facilities": _customFacilities,
          // 🚀 ไม่ต้องส่ง Owner_ID เอง — Backend อ่านจาก JWT token ที่แนบไปกับ request แทน
        };

        await ref.read(dormRepositoryProvider).createDorm(newDormData);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ส่งข้อมูลสำเร็จ! รอแอดมินตรวจสอบ ⏳'),
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
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  // 🚀 แสดงผลจาก File แทน URL
  Widget _buildImageGallery(
    List<File> images,
    VoidCallback onAdd,
    int maxLimit,
    String hintText,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...images.asMap().entries.map((entry) {
              int index = entry.key;
              File file = entry.value;
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
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.file(
                        file,
                        width: 110,
                        height: 110,
                        fit: BoxFit.cover,
                        cacheWidth: 220,
                      ),
                    ),
                  ),
                  if (index == 0)
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
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
                      onTap: () => setState(() => images.removeAt(index)),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.cancel,
                          color: Colors.redAccent,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
            if (images.length < maxLimit)
              InkWell(
                onTap: onAdd,
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
                      Icon(Icons.add_a_photo_outlined, color: _tealAccent.shade400),
                      const SizedBox(height: 6),
                      Text(
                        '${images.length}/$maxLimit',
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
        if (images.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              hintText,
              style: TextStyle(color: Colors.red.shade400, fontSize: 12),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('ลงประกาศหอพัก'),
        centerTitle: true,
        backgroundColor: _tealAccent,
        foregroundColor: Colors.white,
        elevation: 0,
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
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: _tealAccent),
                    SizedBox(height: 20),
                    Text(
                      'กำลังอัปโหลดรูปภาพและบันทึกข้อมูล...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _tealAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
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
                              Icons.apartment_rounded,
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
                                  'ลงประกาศหอพักใหม่',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'กรอกข้อมูลให้ครบทุกขั้นตอนเพื่อให้ประกาศของคุณ'
                                  'ดูน่าเชื่อถือและอนุมัติได้เร็วขึ้น',
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

                    // --- 1. รูปภาพหลักฐาน (Ownership) ---
                    const NumberedSectionTitle(
                      step: 1,
                      title: 'เอกสารยืนยันความเป็นเจ้าของ',
                      subtitle: 'ใช้สำหรับตรวจสอบสิทธิ์การเป็นเจ้าของหอพัก',
                      accentColor: _tealAccent,
                    ),
                    const SizedBox(height: 12),
                    SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'อัปโหลดโฉนด, สัญญา หรือเอกสารยืนยัน (1-5 รูป)',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 12),
                          _buildImageGallery(
                            _ownershipImages,
                            _addOwnershipImage,
                            5,
                            '* จำเป็นต้องมีอย่างน้อย 1 ภาพ',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- 2. รูปภาพบรรยากาศหอพัก ---
                    const NumberedSectionTitle(
                      step: 2,
                      title: 'รูปภาพหอพัก',
                      subtitle: 'ภาพถ่ายจริงจะช่วยดึงดูดผู้เช่าได้มากขึ้น',
                      accentColor: _tealAccent,
                    ),
                    const SizedBox(height: 12),
                    SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'อัปโหลดภาพหน้าปกและบรรยากาศ (3-10 รูป)',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 12),
                          _buildImageGallery(
                            _dormImages,
                            _addDormImage,
                            10,
                            '* จำเป็นต้องมีอย่างน้อย 3 ภาพ',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- 3. ข้อมูลพื้นฐาน ---
                    const NumberedSectionTitle(
                      step: 3,
                      title: 'ข้อมูลพื้นฐาน',
                      subtitle: 'ชื่อ ประเภท และรายละเอียดหอพักของคุณ',
                      accentColor: _tealAccent,
                    ),
                    const SizedBox(height: 12),
                    SoftCard(
                      child: Column(
                        children: [
                          AppTextField(
                            controller: _nameController,
                            labelText: 'ชื่อหอพัก / อพาร์ตเมนต์',
                            prefixIcon: Icons.business,
                            accentColor: _tealAccent,
                            validator: (value) =>
                                value!.isEmpty ? 'กรุณากรอกชื่อหอพัก' : null,
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _dormType,
                            decoration: InputDecoration(
                              labelText: 'ประเภทหอพัก',
                              prefixIcon: const Icon(Icons.wc, color: _tealAccent),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            items: ['ชาย', 'หญิง', 'รวม']
                                .map(
                                  (type) => DropdownMenuItem(
                                    value: type,
                                    child: Text('หอพัก$type'),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _dormType = value!),
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            controller: _descriptionController,
                            labelText: 'รายละเอียดหอพัก (คำแนะนำเพิ่มเติม)',
                            hintText:
                                'เช่น จุดเด่นของหอพัก, บรรยากาศ, ระยะทางไปมหาวิทยาลัย ฯลฯ',
                            maxLines: 8,
                            minLines: 4,
                            accentColor: _tealAccent,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- 4. ค่าใช้จ่าย ---
                    const NumberedSectionTitle(
                      step: 4,
                      title: 'ค่าเช่าและค่าใช้จ่าย',
                      subtitle: 'ระบุค่าใช้จ่ายให้ชัดเจนเพื่อความโปร่งใส',
                      accentColor: _tealAccent,
                    ),
                    const SizedBox(height: 12),
                    SoftCard(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: AppTextField(
                                  controller: _depositController,
                                  labelText: 'ค่าล่วงหน้า (บาท)',
                                  keyboardType: TextInputType.number,
                                  accentColor: _tealAccent,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: AppTextField(
                                  controller: _insuranceController,
                                  labelText: 'ค่าประกัน (บาท)',
                                  keyboardType: TextInputType.number,
                                  accentColor: _tealAccent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            controller: _contractDurationController,
                            labelText: 'ระยะเวลาสัญญาขั้นต่ำ (เดือน)',
                            prefixIcon: Icons.calendar_month,
                            keyboardType: TextInputType.number,
                            accentColor: _tealAccent,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: AppTextField(
                                  controller: _waterRateController,
                                  labelText: 'ค่าน้ำ (เช่น เหมา 100/ด)',
                                  accentColor: _tealAccent,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: AppTextField(
                                  controller: _electricRateController,
                                  labelText: 'ค่าไฟ (บาท/หน่วย)',
                                  accentColor: _tealAccent,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- 5. สิ่งอำนวยความสะดวกส่วนกลาง (Facilities) ---
                    const NumberedSectionTitle(
                      step: 5,
                      title: 'สิ่งอำนวยความสะดวก',
                      subtitle: 'เลือกสิ่งที่มีให้บริการในหอพัก',
                      accentColor: _tealAccent,
                    ),
                    const SizedBox(height: 12),
                    SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'เลือกสิ่งอำนวยความสะดวกที่มีในหอพัก',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 12),
                          ref
                              .watch(dormFacilitiesProvider)
                              .when(
                                loading: () => const Center(
                                  child: CircularProgressIndicator(
                                    color: _tealAccent,
                                  ),
                                ),
                                error: (err, stack) => Text(
                                  'โหลดข้อมูลล้มเหลว: $err',
                                  style: const TextStyle(color: Colors.red),
                                ),
                                data: (facilities) {
                                  if (facilities.isEmpty) {
                                    return const Text(
                                      'ยังไม่มีข้อมูลสิ่งอำนวยความสะดวกในระบบ',
                                    );
                                  }
                                  return GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          childAspectRatio: 3.5,
                                          crossAxisSpacing: 10,
                                          mainAxisSpacing: 10,
                                        ),
                                    itemCount: facilities.length,
                                    itemBuilder: (context, index) {
                                      final facility = facilities[index];
                                      final int id = facility['Facility_ID'];
                                      final String name =
                                          facility['Facility_Name'];
                                      final bool isSelected =
                                          _selectedFacilities.contains(id);

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
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isSelected
                                                  ? _tealAccent
                                                  : Colors.transparent,
                                              width: isSelected ? 1.5 : 0,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                isSelected
                                                    ? Icons.check_circle
                                                    : Icons.circle_outlined,
                                                color: isSelected
                                                    ? _tealAccent
                                                    : Colors.grey,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  name,
                                                  style: TextStyle(
                                                    color: isSelected
                                                        ? _tealAccent.shade800
                                                        : Colors.black87,
                                                    fontWeight: isSelected
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                    fontSize: 13,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- 5.5 สิ่งอำนวยความสะดวกที่พิมพ์เพิ่มเอง (Custom Facilities) ---
                    const NumberedSectionTitle(
                      step: 6,
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
                                  hintText: 'เช่น ที่จอดรถ 24 ชม.',
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
                    const SizedBox(height: 20),

                    // --- 6. กฎระเบียบ ---
                    const NumberedSectionTitle(
                      step: 7,
                      title: 'กฎระเบียบ',
                      subtitle: 'แจ้งกฎการเข้าพักให้ผู้เช่าทราบล่วงหน้า',
                      accentColor: _tealAccent,
                    ),
                    const SizedBox(height: 12),
                    SoftCard(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text('อนุญาตให้เลี้ยงสัตว์'),
                            subtitle: Text(
                              _isPetFriendly
                                  ? 'เลี้ยงสัตว์ได้ (Pet Friendly)'
                                  : 'ไม่อนุญาตให้เลี้ยงสัตว์',
                            ),
                            value: _isPetFriendly,
                            activeColor: _tealAccent,
                            secondary: const Icon(Icons.pets),
                            onChanged: (bool value) =>
                                setState(() => _isPetFriendly = value),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            title: const Text('อนุญาตให้สูบบุหรี่'),
                            subtitle: Text(
                              _isSmokingAllowed
                                  ? 'มีพื้นที่สูบบุหรี่'
                                  : 'ห้ามสูบบุหรี่เด็ดขาด',
                            ),
                            value: _isSmokingAllowed,
                            activeColor: _tealAccent,
                            secondary: const Icon(Icons.smoking_rooms),
                            onChanged: (bool value) =>
                                setState(() => _isSmokingAllowed = value),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- 7. ที่ตั้งและการติดต่อ ---
                    const NumberedSectionTitle(
                      step: 8,
                      title: 'ที่ตั้งและการติดต่อ',
                      subtitle: 'ตำแหน่งและช่องทางติดต่อสำหรับผู้สนใจ',
                      accentColor: _tealAccent,
                    ),
                    const SizedBox(height: 12),
                    SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppTextField(
                            controller: _addressController,
                            labelText: 'ที่อยู่รายละเอียด',
                            prefixIcon: Icons.home_work,
                            maxLines: 2,
                            accentColor: _tealAccent,
                            validator: (value) =>
                                value!.isEmpty ? 'กรุณากรอกที่อยู่' : null,
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            controller: _contactController,
                            labelText: 'เบอร์โทร, Line, Facebook',
                            prefixIcon: Icons.contact_phone,
                            accentColor: _tealAccent,
                            validator: (value) => value!.isEmpty
                                ? 'กรุณากรอกข้อมูลติดต่อ'
                                : null,
                          ),
                          const SizedBox(height: 24),

                          Text(
                            'ตำแหน่งพิกัดหอพัก',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: _tealAccent.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _openMapPicker,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              height: 200,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _selectedLocation == null
                                      ? Colors.red.shade300
                                      : _tealAccent.shade300,
                                  width: 2,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                children: [
                                  IgnorePointer(
                                    child: GoogleMap(
                                      initialCameraPosition: CameraPosition(
                                        target:
                                            _selectedLocation ??
                                            _defaultMiniMapLocation,
                                        zoom: _selectedLocation == null
                                            ? 12
                                            : 16,
                                      ),
                                      zoomControlsEnabled: false,
                                      mapToolbarEnabled: false,
                                      myLocationButtonEnabled: false,
                                      markers: _selectedLocation == null
                                          ? {}
                                          : {
                                              Marker(
                                                markerId: const MarkerId(
                                                  'mini_pin',
                                                ),
                                                position: _selectedLocation!,
                                              ),
                                            },
                                    ),
                                  ),
                                  if (_selectedLocation == null)
                                    Container(
                                      color: Colors.black.withValues(
                                        alpha: 0.6,
                                      ),
                                      child: const Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.touch_app,
                                              color: Colors.white,
                                              size: 40,
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'แตะเพื่อเปิดแผนที่และปักหมุด',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (_selectedLocation == null)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 8.0,
                                left: 4,
                              ),
                              child: Text(
                                '* จำเป็นต้องระบุพิกัดบนแผนที่',
                                style: TextStyle(
                                  color: Colors.red.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // --- 8. ปุ่มบันทึก ---
                    PrimaryButton(
                      label: 'บันทึกและส่งข้อมูลให้แอดมินตรวจสอบ',
                      onPressed: _submitForm,
                      icon: Icons.cloud_upload,
                      backgroundColor: _tealAccent,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
}
