// 📄 ไฟล์นี้ทำหน้าที่: บริการเลือกรูปจากเครื่องและอัปโหลดขึ้น Firebase Storage
// ใช้ร่วมกันในฟีเจอร์ที่ต้องอัปโหลดรูป เช่น หอพัก/ห้องพัก/โปรไฟล์ผู้ใช้
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  Future<File?> pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        return File(pickedFile.path);
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
    return null;
  }

  // 🚀 อัปโหลดรูปภาพขึ้น Firebase Storage
  // ⚠️ ถ้าอัปโหลดไม่สำเร็จ (เช่น เน็ตหลุด/ไม่มีสิทธิ์เขียนตาม Storage Rules) จะ throw Exception
  // ออกไปทันที แทนที่จะคืนค่า null เงียบๆ เพราะเคยทำให้ผู้ใช้เห็นข้อความ "ยังไม่ได้ใส่รูป"
  // ที่หน้าปลายทางทั้งที่จริงๆ คือ "อัปโหลดไม่สำเร็จ" ทำให้สับสนว่าต้องแก้ตรงไหน
  Future<String> uploadImage(File file, {required String folderName}) async {
    try {
      // ตั้งชื่อไฟล์ให้ไม่ซ้ำ
      String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      String filePath = '$folderName/$fileName';

      // อัปโหลดขึ้น Firebase
      Reference ref = _storage.ref().child(filePath);
      UploadTask uploadTask = ref.putFile(file);

      // รอจนเสร็จและขอ URL
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } on FirebaseException catch (e) {
      debugPrint("Error uploading image: ${e.code} - ${e.message}");
      throw Exception('อัปโหลดรูปภาพไม่สำเร็จ (${e.code}): ${e.message}');
    } catch (e) {
      debugPrint("Error uploading image: $e");
      throw Exception('อัปโหลดรูปภาพไม่สำเร็จ กรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ตแล้วลองใหม่');
    }
  }
}
