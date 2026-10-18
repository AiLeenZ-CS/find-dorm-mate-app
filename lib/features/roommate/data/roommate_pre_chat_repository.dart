import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'roommate_chat_repository.dart' show ChatMessage;

final roommatePreChatRepositoryProvider = Provider(
  (ref) => RoommatePreChatRepository(),
);

final roommatePreChatMessagesProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, int>((ref, matchId) {
      return ref.read(roommatePreChatRepositoryProvider).messagesStream(matchId);
    });

/// 🚀 ห้องแชท 1:1 "ก่อนตอบรับ" ระหว่างเจ้าของประกาศ + ผู้ขอ 1 คน — แยกจาก roommate_chats
/// (ห้องแชทกลุ่มของคนที่ Matched แล้ว) โดยสิ้นเชิง เก็บที่ Firestore collection
/// "roommate_pre_chats/match_{matchId}/messages" เอกสารหลักเขียนได้จาก backend เท่านั้น
/// (Admin SDK ตอนเจ้าของประกาศกด "ทักแชท" — ดู syncPreChatParticipants ใน
/// roommate.controller.ts) client เขียนได้แค่ subcollection "messages" ตาม Firestore Security Rules
class RoommatePreChatRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _chatDocId(int matchId) => 'match_$matchId';

  Stream<List<ChatMessage>> messagesStream(int matchId) {
    return _db
        .collection('roommate_pre_chats')
        .doc(_chatDocId(matchId))
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(ChatMessage.fromDoc).toList());
  }

  Future<void> sendMessage({
    required int matchId,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    await _db
        .collection('roommate_pre_chats')
        .doc(_chatDocId(matchId))
        .collection('messages')
        .add({
          'senderId': senderId,
          'senderName': senderName,
          'text': trimmed,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }
}
