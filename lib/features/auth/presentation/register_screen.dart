import 'dart:io';
import 'package:find_dorm_mate/core/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../data/auth_repository.dart';
import 'package:find_dorm_mate/core/widgets/app_text_field.dart';
import 'package:find_dorm_mate/core/widgets/primary_button.dart';
import 'package:find_dorm_mate/core/widgets/section_title.dart';
import 'package:find_dorm_mate/core/widgets/soft_card.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _idCardController = TextEditingController();

  String? _selectedGender;
  String _selectedRole = 'Member';
  DateTime? _selectedBirthdate;

  File? _selectedProfileImage;
  File? _selectedIdCardImage;
  bool _isLoading = false;

  final StorageService _storageService = StorageService();

  Future<void> _pickProfileImage() async {
    final file = await _storageService.pickImage();
    if (file != null) {
      setState(() => _selectedProfileImage = file);
    }
  }

  Future<void> _pickIdCardImage() async {
    final file = await _storageService.pickImage();
    if (file != null) {
      setState(() => _selectedIdCardImage = file);
    }
  }

  Future<void> _pickBirthdate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedBirthdate = picked);
    }
  }

  Future<void> _submitRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('รหัสผ่านและยืนยันรหัสผ่านไม่ตรงกัน'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_selectedRole == 'Owner' && _selectedIdCardImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('กรุณาอัปโหลดรูปภาพบัตรประชาชนด้วยครับ'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      String? birthdateStr;
      if (_selectedBirthdate != null) {
        birthdateStr = DateFormat('yyyy-MM-dd').format(_selectedBirthdate!);
      }
      String? profileImageUrl;
      String? idCardImageUrl;

      if (_selectedProfileImage != null) {
        profileImageUrl = await _storageService.uploadImage(
          _selectedProfileImage!,
          folderName: 'profiles',
        );
      }
      if (_selectedRole == 'Owner' && _selectedIdCardImage != null) {
        idCardImageUrl = await _storageService.uploadImage(
          _selectedIdCardImage!,
          folderName: 'id_cards',
        );
      }
      await ref
          .read(authRepositoryProvider)
          .register(
            username: _usernameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            nickname: _nicknameController.text.trim(),
            phone: _phoneController.text.trim(),
            gender: _selectedGender,
            birthdate: birthdateStr,
            userRole: _selectedRole,
            idCardNo: _selectedRole == 'Owner'
                ? _idCardController.text.trim()
                : null,
            profileImage: profileImageUrl,
            idCardImage: idCardImageUrl,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedRole == 'Owner'
                      ? 'สมัครสมาชิกสำเร็จ! กรุณารอแอดมินตรวจสอบ'
                      : 'สมัครสมาชิกสำเร็จ! ยินดีต้อนรับเข้าสู่ระบบ',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'สร้างบัญชีใหม่',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.grey.shade50,
        foregroundColor: colorScheme.onSurface,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'กำลังสร้างบัญชีผู้ใช้และอัปโหลดรูปภาพ...',
                    style: TextStyle(color: colorScheme.primary),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // --- 📸 รูปโปรไฟล์ ---
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 56,
                            backgroundColor: colorScheme.primaryContainer,
                            backgroundImage: _selectedProfileImage != null
                                ? FileImage(_selectedProfileImage!)
                                : null,
                            child: _selectedProfileImage == null
                                ? Icon(
                                    Icons.person,
                                    size: 60,
                                    color: colorScheme.onPrimaryContainer,
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: InkWell(
                              onTap: _pickProfileImage,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.camera_alt,
                                  color: colorScheme.onPrimary,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- 1. เลือกบทบาทผู้ใช้ (ย้ายมาไว้บนสุด) ---
                    // 🚀 ให้เลือกก่อนเสมอ เพราะฟิลด์ข้างล่างบางส่วน (ชื่อเล่น/เพศ/วันเกิด)
                    // แสดงเฉพาะ Member เท่านั้น — เลือกบทบาทก่อนแล้วฟอร์มจะปรับให้ตรงกับที่
                    // ตารางฐานข้อมูลของบทบาทนั้นๆ มีจริงตั้งแต่ต้น ไม่ต้องกรอกแล้วโดนซ่อนทีหลัง
                    const SectionTitle(
                      title: 'บทบาทผู้ใช้งาน',
                      icon: Icons.supervised_user_circle_outlined,
                    ),
                    const SizedBox(height: 12),
                    SoftCard(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            title: const Text('สมาชิกทั่วไป'),
                            value: 'Member',
                            groupValue: _selectedRole,
                            activeColor: colorScheme.primary,
                            onChanged: (v) =>
                                setState(() => _selectedRole = v!),
                          ),
                          RadioListTile<String>(
                            title: const Text('เจ้าของหอพัก'),
                            value: 'Owner',
                            groupValue: _selectedRole,
                            activeColor: colorScheme.primary,
                            onChanged: (v) =>
                                setState(() => _selectedRole = v!),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- 2. ข้อมูลบัญชี ---
                    const SectionTitle(
                      title: 'ข้อมูลความปลอดภัย',
                      icon: Icons.lock_outline,
                    ),
                    const SizedBox(height: 12),
                    SoftCard(
                      child: Column(
                        children: [
                          AppTextField(
                            controller: _usernameController,
                            labelText: 'ชื่อผู้ใช้ (Username) *',
                            prefixIcon: Icons.person_outline,
                            validator: (v) =>
                                v!.isEmpty ? 'กรุณากรอกชื่อผู้ใช้' : null,
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            controller: _emailController,
                            labelText: 'อีเมล *',
                            prefixIcon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) =>
                                !v!.contains('@') ? 'อีเมลไม่ถูกต้อง' : null,
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            controller: _passwordController,
                            labelText: 'รหัสผ่าน *',
                            prefixIcon: Icons.key_outlined,
                            isPassword: true,
                            validator: (v) => v!.length < 6
                                ? 'รหัสผ่านต้องมี 6 ตัวขึ้นไป'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            controller: _confirmPasswordController,
                            labelText: 'ยืนยันรหัสผ่าน *',
                            prefixIcon: Icons.key_outlined,
                            isPassword: true,
                            validator: (v) =>
                                v!.isEmpty ? 'กรุณายืนยันรหัสผ่าน' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- 3. ข้อมูลส่วนตัว ---
                    const SectionTitle(
                      title: 'ข้อมูลส่วนตัว',
                      icon: Icons.badge_outlined,
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
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: AppTextField(
                                  controller: _lastNameController,
                                  labelText: 'นามสกุล',
                                  prefixIcon: Icons.family_restroom,
                                ),
                              ),
                            ],
                          ),
                          // 🚀 ชื่อเล่น/เพศ/วันเกิด มีแค่ในตาราง D1_Members (สมาชิกทั่วไป)
                          // เท่านั้น ตาราง D2_Owners (เจ้าของหอพัก) ไม่มีคอลัมน์พวกนี้เลย
                          // ถ้าเลือกเป็นเจ้าของหอพักจึงต้องซ่อนไว้ ไม่งั้นกรอกไปก็ถูกเซิร์ฟเวอร์
                          // ทิ้งเงียบๆ อยู่ดี
                          if (_selectedRole != 'Owner') ...[
                            const SizedBox(height: 16),
                            AppTextField(
                              controller: _nicknameController,
                              labelText: 'ชื่อเล่น',
                              prefixIcon: Icons.emoji_emotions_outlined,
                            ),
                          ],
                          const SizedBox(height: 16),
                          AppTextField(
                            controller: _phoneController,
                            labelText: 'เบอร์โทรศัพท์ *',
                            prefixIcon: Icons.phone_android,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            validator: (v) => v!.length != 10
                                ? 'กรุณากรอกเบอร์โทร 10 หลัก'
                                : null,
                          ),
                          if (_selectedRole != 'Owner') ...[
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    decoration: InputDecoration(
                                      labelText: 'เพศ',
                                      prefixIcon: Icon(
                                        Icons.wc,
                                        color: colorScheme.primary,
                                      ),
                                      filled: true,
                                      fillColor: colorScheme
                                          .surfaceContainerHighest
                                          .withValues(alpha: 0.4),
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
                                    onTap: () => _pickBirthdate(context),
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: 'วันเกิด',
                                        prefixIcon: Icon(
                                          Icons.cake_outlined,
                                          color: colorScheme.primary,
                                        ),
                                        filled: true,
                                        fillColor: colorScheme
                                            .surfaceContainerHighest
                                            .withValues(alpha: 0.4),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
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

                    // 🚀 4. ส่วนตรวจสอบเฉพาะ Owner (บัตรประชาชน + รูปถ่าย)
                    if (_selectedRole == 'Owner')
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: SoftCard(
                          color: Colors.orange.shade50,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.security, color: Colors.orange),
                                  SizedBox(width: 8),
                                  Text(
                                    'ตรวจสอบตัวตนเจ้าของหอพัก',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              AppTextField(
                                controller: _idCardController,
                                labelText: 'เลขบัตรประชาชน 13 หลัก *',
                                prefixIcon: Icons.credit_card,
                                keyboardType: TextInputType.number,
                                maxLength: 13,
                                validator: (v) =>
                                    _selectedRole == 'Owner' && v!.length != 13
                                    ? 'ต้องมี 13 หลัก'
                                    : null,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'อัปโหลดรูปถ่ายบัตรประชาชน *',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade800,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: _pickIdCardImage,
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  height: 160,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.orange.shade300,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: _selectedIdCardImage != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                          child: Image.file(
                                            _selectedIdCardImage!,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons
                                                  .add_photo_alternate_outlined,
                                              size: 48,
                                              color: Colors.orange.shade300,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'คลิกเพื่อเลือกรูปภาพ',
                                              style: TextStyle(
                                                color: Colors.orange.shade700,
                                                fontWeight: FontWeight.w500,
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

                    const SizedBox(height: 32),

                    PrimaryButton(
                      label: 'สร้างบัญชีผู้ใช้',
                      onPressed: _submitRegister,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
}
