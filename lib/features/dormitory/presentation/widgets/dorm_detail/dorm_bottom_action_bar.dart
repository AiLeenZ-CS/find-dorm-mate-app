import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:find_dorm_mate/core/auth/role_utils.dart';
import 'package:find_dorm_mate/features/dormitory/data/dorm_repository.dart';
import 'package:find_dorm_mate/features/dormitory/domain/dorm_detail_model.dart';

/// แถบปุ่ม Call-to-Action ที่ยึดติดด้านล่างจอเสมอ (ไม่เลื่อนไปกับเนื้อหา)
/// สลับชุดปุ่มตามบทบาทผู้ใช้: เจ้าของหอ (แก้ไข/เพิ่มห้อง) vs สมาชิกทั่วไป (หารูมเมท/ติดต่อเจ้าของหอ)
class DormBottomActionBar extends ConsumerWidget {
  final DormDetailModel dorm;

  const DormBottomActionBar({super.key, required this.dorm});

  Future<String> _getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_role') ?? 'Guest';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: FutureBuilder<String>(
          future: _getUserRole(),
          builder: (context, snapshot) {
            // ระหว่างรอเช็ค role ให้เว้นพื้นที่ไว้เฉยๆ กันจอกระตุกตอนโหลดเสร็จ
            if (!snapshot.hasData) {
              return const SizedBox(height: 52);
            }

            final isOwner = isOwnerRole(snapshot.data);
            return isOwner
                ? _OwnerActions(dorm: dorm, ref: ref)
                : _MemberActions(dorm: dorm);
          },
        ),
      ),
    );
  }
}

class _OwnerActions extends StatelessWidget {
  final DormDetailModel dorm;
  final WidgetRef ref;

  const _OwnerActions({required this.dorm, required this.ref});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              context.push('/edit-dorm/${dorm.id}', extra: dorm);
            },
            icon: const Icon(Icons.edit_document),
            label: const Text('แก้ไขหอพัก'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              foregroundColor: colorScheme.primary,
              side: BorderSide(color: colorScheme.primary, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: () {
              context.push('/add-room-type/${dorm.id}');
              ref.invalidate(dormDetailProvider(dorm.id));
            },
            icon: const Icon(Icons.add_home_work),
            label: const Text('เพิ่มห้องพัก'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MemberActions extends StatelessWidget {
  final DormDetailModel dorm;

  const _MemberActions({required this.dorm});

  void _showContactSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _ContactSheet(contactInfo: dorm.contactInfo),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: OutlinedButton.icon(
            onPressed: () => context.push('/dorm/${dorm.id}/roommates'),
            icon: const Icon(Icons.people_outline),
            label: const Text('หารูมเมท'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              foregroundColor: colorScheme.primary,
              side: BorderSide(color: colorScheme.outlineVariant, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: FilledButton.icon(
            onPressed: () => _showContactSheet(context),
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('ติดต่อเจ้าของหอ'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ContactSheet extends StatelessWidget {
  final String? contactInfo;

  const _ContactSheet({this.contactInfo});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Text(
              'ช่องทางการติดต่อเจ้าของหอ',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                contactInfo ?? 'ไม่มีข้อมูลติดต่อ',
                style: TextStyle(fontSize: 15, color: colorScheme.onSurface),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: contactInfo == null
                    ? null
                    : () {
                        Clipboard.setData(ClipboardData(text: contactInfo!));
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('คัดลอกข้อมูลติดต่อแล้ว')),
                        );
                      },
                icon: const Icon(Icons.copy_all_outlined),
                label: const Text('คัดลอกข้อมูลติดต่อ'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
