// 📄 ไฟล์นี้ทำหน้าที่: หน้าแชท 1:1 "ก่อนตอบรับคำขอจับคู่" ระหว่างเจ้าของประกาศกับผู้ขอ —
// แยกจากแชทกลุ่มของคนที่ Matched แล้ว ใช้คุยสำรวจนิสัยกันก่อนเจ้าของประกาศตัดสินใจ
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/roommate_chat_repository.dart' show ChatMessage;
import '../data/roommate_pre_chat_repository.dart';

/// หน้าแชท 1:1 "ก่อนตอบรับ" — เจ้าของประกาศคุยกับผู้ขอรายนี้เพื่อศึกษานิสัยใจคอก่อนตัดสินใจ
/// อนุมัติ/ปฏิเสธ แยกห้องจากแชทกลุ่มของคนที่ Matched แล้ว (ดู RoommateChatScreen)
class RoommatePreChatScreen extends ConsumerStatefulWidget {
  final int matchId;
  final String? title;
  final String? otherPartyImage;

  const RoommatePreChatScreen({
    super.key,
    required this.matchId,
    this.title,
    this.otherPartyImage,
  });

  @override
  ConsumerState<RoommatePreChatScreen> createState() =>
      _RoommatePreChatScreenState();
}

class _RoommatePreChatScreenState
    extends ConsumerState<RoommatePreChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  String? _myUid;
  String _myName = 'สมาชิก';

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final memberId = prefs.getInt('member_id');
    setState(() {
      _myUid = memberId != null ? 'member_$memberId' : null;
      _myName = prefs.getString('username') ?? 'สมาชิก';
    });
  }

  Future<void> _handleSend() async {
    final text = _textController.text.trim();
    final myUid = _myUid;
    if (text.isEmpty || myUid == null || _isSending) return;

    setState(() => _isSending = true);
    _textController.clear();
    try {
      await ref
          .read(roommatePreChatRepositoryProvider)
          .sendMessage(
            matchId: widget.matchId,
            senderId: myUid,
            senderName: _myName,
            text: text,
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ส่งข้อความไม่สำเร็จ: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(
      roommatePreChatMessagesProvider(widget.matchId),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF3F0FA),
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white24,
              backgroundImage: widget.otherPartyImage != null
                  ? ResizeImage(NetworkImage(widget.otherPartyImage!), width: 80)
                  : null,
              child: widget.otherPartyImage == null
                  ? const Icon(Icons.person, color: Colors.white70, size: 18)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.title ?? 'แชทก่อนตอบรับ',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.deepPurple.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.deepPurple.shade400,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'แชทนี้ใช้คุยก่อนตัดสินใจอนุมัติ/ปฏิเสธคำขอ',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.deepPurple.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Colors.deepPurple),
              ),
              error: (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'โหลดข้อความไม่สำเร็จ: $error',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 72,
                          color: Colors.deepPurple.shade100,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'ยังไม่มีข้อความ ทักทายกันก่อนได้เลย 👋',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == _myUid;
                    return _PreChatBubble(
                      message: message,
                      isMe: isMe,
                      avatarUrl: widget.otherPartyImage,
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _handleSend(),
                      decoration: InputDecoration(
                        hintText: 'พิมพ์ข้อความ...',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isSending ? null : _handleSend,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                    ),
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final String? avatarUrl;

  const _PreChatBubble({
    required this.message,
    required this.isMe,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final time = message.createdAt != null
        ? DateFormat('HH:mm').format(message.createdAt!)
        : '';

    // 🚀 โชว์รูปโปรไฟล์เฉพาะข้อความของอีกฝ่าย (ไม่โชว์รูปตัวเองข้างข้อความตัวเอง —
    // ตามแพทเทิร์นเดียวกับแชทกลุ่มใน RoommateChatScreen)
    final avatar = CircleAvatar(
      radius: 14,
      backgroundColor: Colors.deepPurple.shade50,
      backgroundImage: avatarUrl != null
          ? ResizeImage(NetworkImage(avatarUrl!), width: 60)
          : null,
      child: avatarUrl == null
          ? Icon(Icons.person, color: Colors.deepPurple.shade300, size: 16)
          : null,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 38, bottom: 2),
              child: Text(
                message.senderName,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[avatar, const SizedBox(width: 8)],
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.66,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.deepPurple : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 14.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                time,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
