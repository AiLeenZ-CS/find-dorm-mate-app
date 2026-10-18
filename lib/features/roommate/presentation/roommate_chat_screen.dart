import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/roommate_chat_repository.dart';
import '../data/roommate_repository.dart';

/// หน้าแชทกลุ่มของรูมเมทที่จับคู่แล้ว (เจ้าของประกาศ + สมาชิกที่ Matched ทุกคน)
/// เก็บ/รับข้อความแบบเรียลไทม์ผ่าน Firestore (roommate_chat_repository.dart)
class RoommateChatScreen extends ConsumerStatefulWidget {
  final int postId;
  final String? title;

  const RoommateChatScreen({super.key, required this.postId, this.title});

  @override
  ConsumerState<RoommateChatScreen> createState() =>
      _RoommateChatScreenState();
}

class _RoommateChatScreenState extends ConsumerState<RoommateChatScreen> {
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
          .read(roommateChatRepositoryProvider)
          .sendMessage(
            postId: widget.postId,
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

  // 🚀 ดึงรายชื่อสมาชิกในกลุ่ม (เจ้าของ + คนที่จับคู่แล้ว) จาก postMembersProvider ที่มีอยู่แล้ว
  // (endpoint เดียวกับที่ใช้โชว์แถวรูปสมาชิกในหน้า "รูมเมทของฉัน") เอามาสร้าง map
  // uid ("member_<Member_ID>") -> รูปโปรไฟล์ เพื่อโชว์รูปข้างข้อความแต่ละคน
  Map<String, String?> _buildAvatarMap(Map<String, dynamic> data) {
    final map = <String, String?>{};

    final owner = data['owner'] as Map<String, dynamic>?;
    if (owner != null && owner['Member_ID'] != null) {
      map['member_${owner['Member_ID']}'] = owner['Profile_Image'] as String?;
    }

    final members = List<Map<String, dynamic>>.from(data['members'] ?? []);
    for (final m in members) {
      if (m['Member_ID'] != null) {
        map['member_${m['Member_ID']}'] = m['Profile_Image'] as String?;
      }
    }

    return map;
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(roommateChatMessagesProvider(widget.postId));
    final membersAsync = ref.watch(postMembersProvider(widget.postId));
    final avatarByUid = membersAsync.value != null
        ? _buildAvatarMap(membersAsync.value!)
        : const <String, String?>{};

    return Scaffold(
      backgroundColor: const Color(0xFFF3F0FA),
      appBar: AppBar(
        title: Text(
          widget.title ?? 'แชทกลุ่มรูมเมท',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
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
                          'ยังไม่มีข้อความ ทักทายรูมเมทของคุณได้เลย 👋',
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
                    return _ChatBubble(
                      message: message,
                      isMe: isMe,
                      avatarUrl: avatarByUid[message.senderId],
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

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final String? avatarUrl;

  const _ChatBubble({
    required this.message,
    required this.isMe,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final time = message.createdAt != null
        ? DateFormat('HH:mm').format(message.createdAt!)
        : '';

    // 🚀 โชว์รูปโปรไฟล์เฉพาะข้อความของคนอื่น (ไม่โชว์รูปตัวเองข้างข้อความตัวเอง —
    // ตามแพทเทิร์นแชทกลุ่มทั่วไป)
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
