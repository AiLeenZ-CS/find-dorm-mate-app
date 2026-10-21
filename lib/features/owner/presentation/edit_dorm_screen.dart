// 📄 ไฟล์นี้ทำหน้าที่: หน้าฟอร์มแก้ไขข้อมูลหอพักที่มีอยู่แล้ว ฝั่งเจ้าของหอ (owner)
// รับข้อมูลตั้งต้นจาก router extra หรือโหลดเองจาก API ถ้าไม่มี แล้วอัปเดตผ่าน dormRepository
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:find_dorm_mate/core/services/storage_service.dart';
import 'package:find_dorm_mate/core/utils/json_list_parser.dart';
import 'package:find_dorm_mate/features/dormitory/data/dorm_repository.dart';
import 'package:find_dorm_mate/features/dormitory/domain/dorm_detail_model.dart';
import 'package:find_dorm_mate/features/owner/presentation/dorm_map_picker_screen.dart';
import 'package:find_dorm_mate/core/widgets/app_text_field.dart';
import 'package:find_dorm_mate/core/widgets/primary_button.dart';
import 'package:find_dorm_mate/core/widgets/section_title.dart';
import 'package:find_dorm_mate/core/widgets/soft_card.dart';

const _tealAccent = Colors.teal;

/// หน้าแก้ไขข้อมูลหอพัก — ครบทุกฟิลด์ที่แก้ได้ตอนสร้างหอพัก รวมถึงรูปภาพหอพักด้วย
/// (ยกเว้นเอกสารยืนยันความเป็นเจ้าของ ซึ่งยังไม่รองรับการแก้ไขในรอบนี้)
/// รับข้อมูลตั้งต้นจาก DormDetailModel ที่ส่งมาผ่าน router extra
/// ถ้าไม่มี (เช่น เข้าถึง route ตรงๆ) จะโหลดข้อมูลจาก API ให้เอง
class EditDormScreen extends ConsumerStatefulWidget {
  final int dormId;
  final DormDetailModel? dorm;

  const EditDormScreen({super.key, required this.dormId, this.dorm});

  @override
  ConsumerState<EditDormScreen> createState() => _EditDormScreenState();
}

class _EditDormScreenState extends ConsumerState<EditDormScreen> {
  final _formKey = GlobalKey<FormState>();
  final StorageService _storageService = StorageService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _waterRateController = TextEditingController();
  final TextEditingController _electricRateController =
      TextEditingController();
  final TextEditingController _depositController = TextEditingController();
  final TextEditingController _insuranceController = TextEditingController();
  final TextEditingController _contractDurationController =
      TextEditingController();
  final TextEditingController _descriptionController =
      TextEditingController();
  final TextEditingController _customFacilityController =
      TextEditingController();

  String _dormType = 'รวม';
  bool _isPetFriendly = false;
  bool _isSmokingAllowed = false;

  bool _isSaving = false;
  bool _isLoadingInitial = false;
  String? _loadError;

  LatLng? _selectedLocation;
  final LatLng _defaultMiniMapLocation = const LatLng(16.243201, 103.238885);

  final List<int> _selectedFacilities = [];
  final List<String> _customFacilities = [];

  // 🚀 รูปภาพหอพัก — แยกเก็บ "รูปเดิมที่ยังเก็บไว้" (URL จาก API) กับ "รูปใหม่ที่เพิ่งเลือก"
  // (ไฟล์ในเครื่อง ยังไม่ได้อัปโหลด) ตอนบันทึกจะอัปโหลดรูปใหม่แล้วรวมกับรูปเดิมที่เหลือ
  // ส่งเป็น "รายการทั้งหมดที่ต้องการเก็บไว้" เหมือน Facilities
  final List<String> _existingImages = [];
  final List<File> _newImages = [];

  @override
  void initState() {
    super.initState();
    if (widget.dorm != null) {
      _applyDormData(widget.dorm!);
    } else {
      _fetchDorm();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    _waterRateController.dispose();
    _electricRateController.dispose();
    _depositController.dispose();
    _insuranceController.dispose();
    _contractDurationController.dispose();
    _descriptionController.dispose();
    _customFacilityController.dispose();
    super.dispose();
  }

  String _mapDormTypeToThai(String? type) {
    switch (type) {
      case 'Male':
        return 'ชาย';
      case 'Female':
        return 'หญิง';
      default:
        return 'รวม';
    }
  }

  void _applyDormData(DormDetailModel dorm) {
    _nameController.text = dorm.name;
    _addressController.text = dorm.address ?? '';
    _contactController.text = dorm.contactInfo ?? '';
    _waterRateController.text = dorm.waterRate ?? '';
    _electricRateController.text = dorm.electricRate ?? '';
    _depositController.text = dorm.depositFee != null
        ? dorm.depositFee!.toStringAsFixed(0)
        : '';
    _insuranceController.text = dorm.insuranceFee != null
        ? dorm.insuranceFee!.toStringAsFixed(0)
        : '';
    _contractDurationController.text = dorm.contractDuration?.toString() ?? '';
    _descriptionController.text = dorm.description ?? '';
    _dormType = _mapDormTypeToThai(dorm.dormType);
    _isPetFriendly = dorm.isPetFriendly;
    _isSmokingAllowed = dorm.isSmokingAllowed;

    _selectedFacilities
      ..clear()
      ..addAll(dorm.facilityIds);
    _customFacilities
      ..clear()
      ..addAll(dorm.customFacilities);
    _existingImages
      ..clear()
      ..addAll(parseStringListJson(dorm.images));

    if (dorm.latitude != null && dorm.longitude != null) {
      _selectedLocation = LatLng(dorm.latitude!, dorm.longitude!);
    }
  }

  Future<void> _fetchDorm() async {
    setState(() => _isLoadingInitial = true);
    try {
      final dorm = await ref.read(dormRepositoryProvider).getDormById(
        widget.dormId,
      );
      _applyDormData(dorm);
    } catch (e) {
      _loadError = e.toString().replaceAll('Exception: ', '');
    } finally {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  int get _totalImageCount => _existingImages.length + _newImages.length;

  Future<void> _addImage() async {
    if (_totalImageCount >= 10) return;
    final file = await _storageService.pickImage();
    if (file != null) {
      setState(() => _newImages.add(file));
    }
  }

  void _removeExistingImage(int index) {
    setState(() => _existingImages.removeAt(index));
  }

  void _removeNewImage(int index) {
    setState(() => _newImages.removeAt(index));
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_totalImageCount < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณามีรูปภาพหอพักอย่างน้อย 3 ภาพ'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      String mappedDormType = 'Mixed';
      if (_dormType == 'ชาย') mappedDormType = 'Male';
      if (_dormType == 'หญิง') mappedDormType = 'Female';

      // 🚀 อัปโหลดเฉพาะรูปใหม่ที่ยังเป็นไฟล์ในเครื่อง แล้วรวมกับรูปเดิมที่เหลืออยู่
      // (รูปที่ถูกลบออกจาก _existingImages ไปแล้วจะไม่ติดไปด้วย)
      final List<String> uploadedNewUrls = [];
      for (final file in _newImages) {
        final url = await _storageService.uploadImage(
          file,
          folderName: 'dorm_images',
        );
        uploadedNewUrls.add(url);
      }
      final allImages = [..._existingImages, ...uploadedNewUrls];

      final updateData = {
        "Dorm_Name": _nameController.text,
        "Dorm_Type": mappedDormType,
        "Address": _addressController.text,
        "Contact_Info": _contactController.text,
        "Dorm_Description": _descriptionController.text,
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
        "Facilities": _selectedFacilities,
        "Custom_Facilities": _customFacilities,
        "Dorm_Images": jsonEncode(allImages),
        if (_selectedLocation != null) "Latitude": _selectedLocation!.latitude,
        if (_selectedLocation != null)
          "Longitude": _selectedLocation!.longitude,
      };

      await ref.read(dormRepositoryProvider).updateDorm(
        widget.dormId,
        updateData,
      );

      ref.invalidate(dormDetailProvider(widget.dormId));
      ref.invalidate(ownerDormsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('บันทึกการแก้ไขสำเร็จ'),
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('แก้ไขข้อมูลหอพัก'),
        backgroundColor: _tealAccent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoadingInitial) {
      return const Center(child: CircularProgressIndicator(color: _tealAccent));
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                'โหลดข้อมูลไม่สำเร็จ: $_loadError',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'ลองใหม่อีกครั้ง',
                onPressed: _fetchDorm,
                backgroundColor: _tealAccent,
              ),
            ],
          ),
        ),
      );
    }

    if (_isSaving) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _tealAccent),
            SizedBox(height: 16),
            Text(
              'กำลังบันทึกข้อมูล...',
              style: TextStyle(color: _tealAccent, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 0. รูปภาพหอพัก ---
            const SectionTitle(
              title: 'รูปภาพหอพัก',
              icon: Icons.photo_library_outlined,
              accentColor: _tealAccent,
            ),
            const SizedBox(height: 12),
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'อัปโหลดภาพบรรยากาศหอพัก (อย่างน้อย 3 รูป)',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 12),
                  _buildImageGallery(),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- 1. ข้อมูลพื้นฐาน ---
            const SectionTitle(
              title: 'ข้อมูลพื้นฐาน',
              icon: Icons.info_outline,
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
                    onChanged: (value) => setState(() => _dormType = value!),
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

            // --- 2. ค่าใช้จ่าย ---
            const SectionTitle(
              title: 'ค่าเช่าและค่าใช้จ่าย',
              icon: Icons.payments_outlined,
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

            // --- 3. สิ่งอำนวยความสะดวกส่วนกลาง ---
            const SectionTitle(
              title: 'สิ่งอำนวยความสะดวก',
              icon: Icons.weekend_outlined,
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
                            physics: const NeverScrollableScrollPhysics(),
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
                              final String name = facility['Facility_Name'];
                              final bool isSelected = _selectedFacilities
                                  .contains(id);

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
                      ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- 3.5 สิ่งอำนวยความสะดวกที่พิมพ์เพิ่มเอง ---
            const SectionTitle(
              title: 'สิ่งอำนวยความสะดวกอื่นๆ (พิมพ์เพิ่มเอง)',
              icon: Icons.add_circle_outline,
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
                              deleteIcon: const Icon(Icons.close, size: 18),
                              onDeleted: () => _removeCustomFacility(entry.key),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- 4. กฎระเบียบ ---
            const SectionTitle(
              title: 'กฎระเบียบ',
              icon: Icons.rule_outlined,
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

            // --- 5. ที่ตั้งและการติดต่อ ---
            const SectionTitle(
              title: 'ที่ตั้งและการติดต่อ',
              icon: Icons.location_on_outlined,
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
                    validator: (value) =>
                        value!.isEmpty ? 'กรุณากรอกข้อมูลติดต่อ' : null,
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
                                zoom: _selectedLocation == null ? 12 : 16,
                              ),
                              zoomControlsEnabled: false,
                              mapToolbarEnabled: false,
                              myLocationButtonEnabled: false,
                              markers: _selectedLocation == null
                                  ? {}
                                  : {
                                      Marker(
                                        markerId: const MarkerId('mini_pin'),
                                        position: _selectedLocation!,
                                      ),
                                    },
                            ),
                          ),
                          if (_selectedLocation == null)
                            Container(
                              color: Colors.black.withValues(alpha: 0.6),
                              child: const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
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
                ],
              ),
            ),
            const SizedBox(height: 32),

            // --- 6. ปุ่มบันทึก ---
            PrimaryButton(
              label: 'บันทึกการแก้ไข',
              onPressed: _save,
              icon: Icons.save_outlined,
              backgroundColor: _tealAccent,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // 🚀 แสดงรูปเดิม (จาก network) และรูปใหม่ (จากเครื่อง) รวมกันในกริดเดียว ลบได้ทั้งสองแบบ
  Widget _buildImageGallery() {
    final int maxLimit = 10;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            ..._newImages.asMap().entries.map((entry) {
              final index = entry.key;
              final file = entry.value;
              return _buildImageTile(
                image: Image.file(
                  file,
                  width: 110,
                  height: 110,
                  fit: BoxFit.cover,
                  cacheWidth: 220,
                ),
                isCover: _existingImages.isEmpty && index == 0,
                onRemove: () => _removeNewImage(index),
              );
            }),
            if (_totalImageCount < maxLimit)
              InkWell(
                onTap: _addImage,
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
                        '$_totalImageCount/$maxLimit',
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
}
