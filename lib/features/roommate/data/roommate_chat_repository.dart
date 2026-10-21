// 📄 ไฟล์นี้ทำหน้าที่: Repository ห้องแชทกลุ่มของรูมเมทที่จับคู่กันแล้ว (Matched) เชื่อมกับ
// Firestore collection "roommate_chats" ส่งและสตรีมข้อความแบบเรียลไทม์ให้หน้า roommate_chat_screen
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final roommateChatRepositoryProvider = Provider(
  (ref) => RoommateChatRepository(),
);

// 🚀 Provider สตรีมข้อความแบบเรียลไทม์ของห้องแชทประกาศนี้ (เรียงใหม่สุดก่อน — เอาไปกลับด้าน
// ใน UI เพื่อโชว์แบบแชทปกติที่ข้อความล่าสุดอยู่ล่างสุด)
final roommateChatMessagesProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, int>((ref, postId) {
      return ref.read(roommateChatRepositoryProvider).messagesStream(postId);
    });

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime? createdAt;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.createdAt,
  });

  factory ChatMessage.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final ts = data['createdAt'];
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'สมาชิก',
      text: data['text'] ?? '',
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}

/// 🚀 ห้องแชทกลุ่มของรูมเมทที่จับคู่แล้ว — 1 ห้องต่อ 1 ประกาศ (Post_ID) ไม่ใช่ 1-ต่อ-1
/// รายบุคคล เก็บที่ Firestore collection "roommate_chats/post_{postId}/messages"
/// เอกสารหลัก (roommate_chats/post_{postId}) เขียนได้จาก backend เท่านั้น (Admin SDK ตอน
/// อนุมัติคำขอจับคู่ — ดู syncChatParticipants ใน roommate.controller.ts) client เขียนได้
/// แค่ subcollection "messages" ตาม Firestore Security Rules
class RoommateChatRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _chatDocId(int postId) => 'post_$postId';

  Stream<List<ChatMessage>> messagesStream(int postId) {
    return _db
        .collection('roommate_chats')
        .doc(_chatDocId(postId))
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(ChatMessage.fromDoc).toList());
  }

  Future<void> sendMessage({
    required int postId,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    await _db
        .collection('roommate_chats')
        .doc(_chatDocId(postId))
        .collection('messages')
        .add({
          'senderId': senderId,
          'senderName': senderName,
          'text': trimmed,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }
}
