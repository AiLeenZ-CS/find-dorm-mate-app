import 'dart:io';
import 'package:find_dorm_mate/core/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/auth_repository.dart';
import 'package:find_dorm_mate/features/dormitory/data/dorm_repository.dart';
import 'package:find_dorm_mate/core/auth/role_utils.dart';
import 'package:find_dorm_mate/core/widgets/app_text_field.dart';
import 'package:find_dorm_mate/core/widgets/primary_button.dart';
import 'package:find_dorm_mate/core/widgets/soft_card.dart';

// 🚀 หน้ากรอกข้อมูลให้ครบ หลังล็อกอินด้วย Google ครั้งแรก (ผู้ใช้ใหม่ / โปรไฟล์ยังไม่ครบ)
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState
    extends ConsumerState<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _idCardController = TextEditingController();

  String? _selectedGender;
  String _selectedRole = 'Member';
  DateTime? _selectedBirthdate;

  File? _selectedIdCardImage;
  bool _isLoading = false;

  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    _prefillUsername();
  }

  // 🚀 ดึง Username ที่ระบบตั้งให้อัตโนมัติจากอีเมล Gmail มาใส่ในช่องให้เลย
  Future<void> _prefillUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username');
    if (username != null && mounted) {
      setState(() => _usernameController.text = username);
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
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
      final prefs = await SharedPreferences.getInstance();
      final memberId = prefs.getInt('member_id');
      final pendingEmail = prefs.getString('pending_google_email');
      final pendingGoogleId = prefs.getString('pending_google_id');
      final pendingPhoto = prefs.getString('pending_google_photo');

      // 🚀 บัญชีใหม่เอี่ยม: ยังไม่มี memberId เพราะ Backend รอให้กรอกฟอร์มนี้ก่อนถึงจะสร้างบัญชีจริง
      if (memberId == null && (pendingEmail == null || pendingEmail.isEmpty)) {
        throw Exception('ไม่พบข้อมูลผู้ใช้ กรุณาเข้าสู่ระบบใหม่');
      }

      String? birthdateStr;
      if (_selectedBirthdate != null) {
        birthdateStr = DateFormat('yyyy-MM-dd').format(_selectedBirthdate!);
      }

      String? idCardImageUrl;
      if (_selectedRole == 'Owner' && _selectedIdCardImage != null) {
        idCardImageUrl = await _storageService.uploadImage(
          _selectedIdCardImage!,
          folderName: 'id_cards',
        );
      }

      final user = await ref
          .read(authRepositoryProvider)
          .completeProfile(
            memberId: memberId,
            email: pendingEmail,
            googleId: pendingGoogleId,
            photoUrl: pendingPhoto,
            username: _usernameController.text.trim().isEmpty
                ? null
                : _usernameController.text.trim(),
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
            idCardImage: idCardImageUrl,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _selectedRole == 'Owner'
                ? 'บันทึกข้อมูลสำเร็จ! กรุณารอแอดมินตรวจสอบ'
                : 'บันทึกข้อมูลสำเร็จ! ยินดีต้อนรับ',
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );

      final String role = user['role'] ?? 'Member';
      final String? status = user['status'];

      // 🚀 กันปัญหาเดียวกับหน้า Login: ProfileScreen ถูก eager-build อยู่ใน
      // IndexedStack ตลอดเวลา ทำให้ userProfileProvider ค้างค่าเก่าถ้าไม่สั่ง invalidate เอง
      ref.invalidate(userProfileProvider);
      ref.invalidate(ownerDormsProvider);

      if (isOwnerRole(role)) {
        // 🚀 เจ้าของหอพักใหม่ยังเข้าสู่ระบบไม่ได้ ต้องรอแอดมินอนุมัติก่อน
        if (status != 'Approved') {
          context.go('/login');
        } else {
          context.go('/owner-dashboard');
        }
      } else {
        context.go('/');
      }
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
          'กรอกข้อมูลให้ครบถ้วน',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.grey.shade50,
        foregroundColor: colorScheme.onSurface,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'กำลังบันทึกข้อมูล...',
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'อีกนิดเดียว! ช่วยกรอกข้อมูลเพิ่มเติมก่อนเริ่มใช้งาน',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    SoftCard(
                      child: Column(
                        children: [
                          AppTextField(
                            controller: _usernameController,
                            labelText: 'ชื่อผู้ใช้ (Username)',
                            prefixIcon: Icons.person_outline,
                          ),
                          const SizedBox(height: 16),
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
                          const SizedBox(height: 16),
                          AppTextField(
                            controller: _nicknameController,
                            labelText: 'ชื่อเล่น',
                            prefixIcon: Icons.tag_faces_outlined,
                          ),
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
                                    fillColor: colorScheme.surfaceContainerHighest
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
                      ),
                    ),
                    const SizedBox(height: 20),
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
                                          borderRadius: BorderRadius.circular(15),
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
                                              Icons.add_photo_alternate_outlined,
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
                      label: 'บันทึกและเริ่มใช้งาน',
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
}
