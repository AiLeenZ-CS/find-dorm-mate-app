// 📄 ไฟล์นี้ทำหน้าที่: หน้าแก้ไขข้อมูลส่วนตัว ใช้ร่วมกันทั้ง Member และ Owner โดยรับข้อมูล
// ผู้ใช้ปัจจุบันมาจาก ProfileScreen ผ่าน router extra แล้วส่งต่อให้ AuthRepository.updateProfile
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:find_dorm_mate/core/services/storage_service.dart';
import 'package:find_dorm_mate/core/widgets/app_text_field.dart';
import 'package:find_dorm_mate/core/widgets/primary_button.dart';
import 'package:find_dorm_mate/core/widgets/section_title.dart';
import 'package:find_dorm_mate/core/widgets/soft_card.dart';
import '../../auth/data/auth_repository.dart';

/// หน้าแก้ไขข้อมูลส่วนตัว — ใช้ร่วมกันทั้ง Member และ Owner โดยแยกฟิลด์ตาม role
/// (Owner ไม่มี Nickname/Gender/Birthdate เพราะ D2_Owners เป็นคนละตารางกับ D1_Members)
/// รับข้อมูลผู้ใช้ปัจจุบันมาจาก ProfileScreen ผ่าน router extra เพื่อไม่ต้องยิง API ซ้ำ
class EditProfileScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> user;
  final bool isOwner;

  const EditProfileScreen({
    super.key,
    required this.user,
    required this.isOwner,
  });

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final StorageService _storageService = StorageService();

  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _nicknameController;
  late final TextEditingController _phoneController;

  String? _selectedGender;
  DateTime? _selectedBirthdate;
  String? _existingProfileImage;
  File? _newProfileImage;
  bool _isSaving = false;

  Color get _accent => widget.isOwner ? Colors.teal : Colors.deepPurple;

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    _firstNameController = TextEditingController(text: user['First_Name'] ?? '');
    _lastNameController = TextEditingController(text: user['Last_Name'] ?? '');
    _nicknameController = TextEditingController(text: user['Nickname'] ?? '');
    _phoneController = TextEditingController(text: user['Phone'] ?? '');
    _selectedGender = user['Gender'];
    _existingProfileImage = user['Profile_Image'];

    final birthdateStr = user['Birthdate'];
    if (birthdateStr != null) {
      _selectedBirthdate = DateTime.tryParse(birthdateStr.toString());
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _nicknameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final file = await _storageService.pickImage();
    if (file != null) {
      setState(() => _newProfileImage = file);
    }
  }

  Future<void> _pickBirthdate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthdate ??
          DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedBirthdate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      String? uploadedImageUrl;
      if (_newProfileImage != null) {
        uploadedImageUrl = await _storageService.uploadImage(
          _newProfileImage!,
          folderName: 'profiles',
        );
      }

      String? birthdateStr;
      if (!widget.isOwner && _selectedBirthdate != null) {
        birthdateStr = DateFormat('yyyy-MM-dd').format(_selectedBirthdate!);
      }

      await ref.read(authRepositoryProvider).updateProfile(
            isOwner: widget.isOwner,
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            phone: _phoneController.text.trim(),
            nickname: widget.isOwner ? null : _nicknameController.text.trim(),
            gender: widget.isOwner ? null : _selectedGender,
            birthdate: birthdateStr,
            profileImage: uploadedImageUrl,
          );

      // 🚀 กันปัญหาเดียวกับหน้า Login: ProfileScreen ถูก eager-build อยู่ใน IndexedStack
      // ตลอดเวลา ต้อง invalidate เองตรงนี้ก่อน pop ไม่งั้นข้อมูลเก่าจะค้างจนกว่าจะรีสตาร์ทแอป
      ref.invalidate(userProfileProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('บันทึกข้อมูลส่วนตัวสำเร็จ'),
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
        title: const Text('แก้ไขข้อมูลส่วนตัว'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: _buildAvatarPicker()),
              const SizedBox(height: 28),

              SectionTitle(
                title: 'ข้อมูลส่วนตัว',
                icon: Icons.badge_outlined,
                accentColor: _accent,
              ),
              const SizedBox(height: 12),
              SoftCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _firstNameController,
                            labelText: 'ชื่อจริง',
                            prefixIcon: Icons.face,
                            accentColor: _accent,
                            validator: (v) =>
                                v!.trim().isEmpty ? 'กรุณากรอกชื่อจริง' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            controller: _lastNameController,
                            labelText: 'นามสกุล',
                            prefixIcon: Icons.family_restroom,
                            accentColor: _accent,
                            validator: (v) =>
                                v!.trim().isEmpty ? 'กรุณากรอกนามสกุล' : null,
                          ),
                        ),
                      ],
                    ),
                    if (!widget.isOwner) ...[
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _nicknameController,
                        labelText: 'ชื่อเล่น',
                        prefixIcon: Icons.tag_faces_outlined,
                        accentColor: _accent,
                      ),
                    ],
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _phoneController,
                      labelText: 'เบอร์โทรศัพท์',
                      prefixIcon: Icons.phone_android,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      accentColor: _accent,
                      validator: (v) => v!.trim().length != 10
                          ? 'กรุณากรอกเบอร์โทร 10 หลัก'
                          : null,
                    ),
                    if (!widget.isOwner) ...[
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: 'เพศ',
                                prefixIcon: Icon(Icons.wc, color: _accent),
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              value: _selectedGender,
                              items: ['Male', 'Female', 'Other']
                                  .map(
                                    (v) => DropdownMenuItem(
                                      value: v,
                                      child: Text(
                                        v == 'Male'
                                            ? 'ชาย'
                                            : v == 'Female'
                                            ? 'หญิง'
                                            : 'อื่นๆ',
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedGender = v),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: _pickBirthdate,
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'วันเกิด',
                                  prefixIcon: Icon(
                                    Icons.cake_outlined,
                                    color: _accent,
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade100,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                child: Text(
                                  _selectedBirthdate == null
                                      ? 'เลือก'
                                      : DateFormat(
                                          'dd/MM/yyyy',
                                        ).format(_selectedBirthdate!),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),

              PrimaryButton(
                label: 'บันทึกการแก้ไข',
                onPressed: _save,
                isLoading: _isSaving,
                backgroundColor: _accent,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarPicker() {
    return GestureDetector(
      onTap: _pickProfileImage,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 52,
            backgroundColor: _accent.withValues(alpha: 0.1),
            backgroundImage: _newProfileImage != null
                ? FileImage(_newProfileImage!)
                : (_existingProfileImage != null
                    ? NetworkImage(_existingProfileImage!)
                    : null) as ImageProvider?,
            child: (_newProfileImage == null && _existingProfileImage == null)
                ? Icon(Icons.person, size: 52, color: _accent)
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _accent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.camera_alt,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
