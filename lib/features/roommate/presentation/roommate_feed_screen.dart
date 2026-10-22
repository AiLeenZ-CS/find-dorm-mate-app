// 📄 ไฟล์นี้ทำหน้าที่: หน้า Feed หลักของฟีเจอร์หารูมเมท — แสดงรายการประกาศที่กำลังเปิดหา
// รองรับกรอง/เรียงลำดับ (ใกล้ฉัน/ราคา/ใหม่สุด) และเป็นจุดเริ่มสร้างประกาศใหม่จากหอพักที่เลือก
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/roommate_repository.dart';
import '../domain/roommate_post_model.dart';
import '../../dormitory/data/dorm_repository.dart';
import 'package:find_dorm_mate/core/widgets/loading_view.dart';
import 'package:find_dorm_mate/core/widgets/primary_button.dart';
import 'widgets/roommate_filters.dart';
import 'widgets/roommate_filter_sheet.dart';
import 'widgets/roommate_sort_bar.dart';
import 'widgets/roommate_sort_option.dart';

class RoommateFeedScreen extends ConsumerStatefulWidget {
  final int? dormId;
  const RoommateFeedScreen({super.key, this.dormId});

  @override
  ConsumerState<RoommateFeedScreen> createState() => _RoommateFeedScreenState();
}

class _RoommateFeedScreenState extends ConsumerState<RoommateFeedScreen> {
  bool _isCheckingSession = true;
  bool _isLoggedIn = false;

  RoommateFilters _filters = const RoommateFilters();
  RoommateSortOption _sortOption = RoommateSortOption.newest;
  Position? _currentPosition;
  bool _isLocating = false;

  int? get dormId => widget.dormId;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  // 🚀 กรองจากเงื่อนไขที่ผู้ประกาศระบุไว้ในประกาศเอง (เพศที่ต้องการ/ช่วงอายุ/เวลานอน/บุหรี่/
  // สัตว์เลี้ยง/ความสะอาด) — เทียบตรงตัวกับค่าที่ประกาศเลือกไว้ (เหมือนตัวกรองหน้า Home ที่เทียบ
  // ประเภทหอ/แอร์-พัดลมตรงตัว) ไม่ได้ทำ fuzzy match กับ 'Any' ของประกาศ
  bool _passesFilters(RoommatePostModel post) {
    if (_filters.reqGender != 'All' && post.reqGender != _filters.reqGender) {
      return false;
    }
    if (_filters.sleepTime != 'All' && post.sleepTime != _filters.sleepTime) {
      return false;
    }
    if (_filters.smokingAllowed != 'All' &&
        post.smokingAllowed != _filters.smokingAllowed) {
      return false;
    }
    if (_filters.petAllowed != 'All' &&
        post.petAllowed != _filters.petAllowed) {
      return false;
    }
    if (_filters.cleanliness != 'All' &&
        post.cleanliness != _filters.cleanliness) {
      return false;
    }

    // ช่วงอายุ — ประกาศที่ระบุ 'Any' (ไม่จำกัดอายุ) ให้ผ่านเสมอ ถ้าระบุช่วงไว้ ต้องมีช่วงที่
    // ทับซ้อนกับตัวกรองที่เลือกอย่างน้อยบางส่วน
    final isFullAgeRange =
        _filters.ageRange.start <= 18 && _filters.ageRange.end >= 50;
    if (!isFullAgeRange && post.reqAgeRange != 'Any') {
      final parts = post.reqAgeRange.split('-');
      final postStart = parts.isNotEmpty ? double.tryParse(parts[0]) : null;
      final postEnd = parts.length > 1 ? double.tryParse(parts[1]) : null;
      if (postStart != null && postEnd != null) {
        final overlaps =
            postStart <= _filters.ageRange.end &&
            postEnd >= _filters.ageRange.start;
        if (!overlaps) return false;
      }
    }

    if (_filters.onlyWithRoom && !post.hasRoomAlready) return false;

    return true;
  }

  List<RoommatePostModel> _sortPosts(List<RoommatePostModel> posts) {
    final sorted = [...posts];
    switch (_sortOption) {
      case RoommateSortOption.newest:
        sorted.sort(
          (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
            a.createdAt ?? DateTime(0),
          ),
        );
        break;
      case RoommateSortOption.priceLowToHigh:
        sorted.sort((a, b) => (a.roomPrice ?? 0).compareTo(b.roomPrice ?? 0));
        break;
      case RoommateSortOption.priceHighToLow:
        sorted.sort((a, b) => (b.roomPrice ?? 0).compareTo(a.roomPrice ?? 0));
        break;
      case RoommateSortOption.nearest:
        final position = _currentPosition;
        if (position == null) break;
        double distanceOf(RoommatePostModel post) {
          if (post.dormLatitude == null || post.dormLongitude == null) {
            return double.infinity; // ประกาศที่ไม่มีพิกัดหอ ดันไปท้ายลิสต์เสมอ
          }
          return Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            post.dormLatitude!,
            post.dormLongitude!,
          );
        }

        sorted.sort((a, b) => distanceOf(a).compareTo(distanceOf(b)));
        break;
    }
    return sorted;
  }

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<RoommateFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => RoommateFilterSheet(initial: _filters),
    );

    if (result != null && mounted) {
      setState(() => _filters = result);
    }
  }

  // 🚀 เลือก "ระยะทาง: ใกล้-ไกล" ครั้งแรกต้องขอตำแหน่งปัจจุบันก่อน (ขอ permission + เปิด GPS
  // ให้ถ้ายังไม่ได้เปิด) ครั้งต่อไปถ้ามีตำแหน่งอยู่แล้วใช้ค่าเดิมได้เลยไม่ต้องขอซ้ำ (เหมือน
  // _handleSortSelected ของหน้า Home)
  Future<void> _handleSortSelected(RoommateSortOption option) async {
    if (option != RoommateSortOption.nearest || _currentPosition != null) {
      setState(() => _sortOption = option);
      return;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเปิด GPS เพื่อเรียงตามระยะทาง')),
      );
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่ได้รับอนุญาตให้เข้าถึงตำแหน่ง')),
      );
      return;
    }

    setState(() => _isLocating = true);
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _sortOption = option;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถระบุตำแหน่งปัจจุบันได้')),
      );
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  // 🚀 Empty state ที่ยังดึงลงเพื่อรีเฟรชได้ (ไม่มีไอคอนรีเฟรชแยกต่างหากแล้ว — ระบบใช้ pull-to-
  // refresh ทุกจุดแทน) ต้องใส่ physics: AlwaysScrollableScrollPhysics เพราะเนื้อหาตรงกลางไม่ยาว
  // พอให้สกอลล์เองตามปกติ ไม่งั้นลากลงเพื่อรีเฟรชจะไม่ทำงาน
  Widget _refreshableEmptyState({
    required Future<void> Function() onRefresh,
    required IconData icon,
    required String message,
  }) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 420,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 72, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isLoggedIn = prefs.getInt('member_id') != null;
      _isCheckingSession = false;
    });
  }

  // ฟังก์ชันแสดง BottomSheet ให้เลือกห้องพัก
  void _showRoomTypeSelector(
    BuildContext context,
    dynamic roomTypes,
    int dormId,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'เลือกห้องพักที่คุณต้องการแชร์',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                if (roomTypes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text(
                      'หอพักนี้ยังไม่มีข้อมูลประเภทห้องพัก',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ...roomTypes.map(
                  (room) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(
                        alpha: 0.35,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      leading: Icon(
                        Icons.meeting_room,
                        color: colorScheme.primary,
                      ),
                      title: Text(
                        room.name ?? 'ไม่ระบุชื่อ',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        room.price != null
                            ? '฿${room.price}/เดือน'
                            : 'ไม่ระบุราคา',
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        context.push(
                          '/create-roommate-post/$dormId',
                          extra: {
                            'roomTypeId': room.id,
                            'roomTypeName': room.name ?? 'ไม่ระบุชื่อ',
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isCheckingSession) {
      return const Scaffold(body: LoadingView());
    }

    if (!_isLoggedIn) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text(
            'ประกาศหาเพื่อนร่วมห้อง',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.grey.shade50,
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 90, color: Colors.grey.shade400),
                const SizedBox(height: 24),
                const Text(
                  'ต้องเข้าสู่ระบบก่อน',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'เข้าสู่ระบบเพื่อดูประกาศหาเพื่อนร่วมห้อง\nและส่งคำขอจับคู่กับคนอื่นได้',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                ),
                const SizedBox(height: 32),
                PrimaryButton(
                  label: 'เข้าสู่ระบบ / สมัครสมาชิก',
                  onPressed: () async {
                    await context.push('/login');
                    _checkSession();
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    final feedAsyncValue = dormId != null
        ? ref.watch(roommateListByDormProvider(dormId!))
        : ref.watch(roommateListProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          dormId != null ? 'รูมเมทหอพักนี้' : 'ประกาศหาเพื่อนร่วมห้อง',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.grey.shade50,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                tooltip: 'ตัวกรอง',
                onPressed: _openFilterSheet,
              ),
              if (_filters.activeFilterCount > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${_filters.activeFilterCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.person_search_outlined),
            tooltip: 'รูมเมทของฉัน',
            onPressed: () => context.push('/my-roommate-matches'),
          ),
        ],
      ),

      // 🚀 ปุ่มลอย (FAB) สำหรับสร้างประกาศ
      floatingActionButton: dormId != null
          ? Consumer(
              builder: (context, ref, child) {
                final dormDetailAsync = ref.watch(dormDetailProvider(dormId!));

                return FloatingActionButton.extended(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    final memberId = prefs.getInt('member_id');

                    if (!context.mounted) return;

                    if (memberId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'กรุณาเข้าสู่ระบบก่อนสร้างประกาศ 🔒',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    dormDetailAsync.when(
                      data: (dorm) {
                        if (dorm.roomTypes.isNotEmpty) {
                          _showRoomTypeSelector(
                            context,
                            dorm.roomTypes,
                            dormId!,
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'หอพักนี้ยังไม่มีข้อมูลประเภทห้องพัก',
                              ),
                            ),
                          );
                        }
                      },
                      loading: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'กำลังโหลดข้อมูลหอพัก กรุณารอสักครู่...',
                          ),
                        ),
                      ),
                      error: (err, stack) =>
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'เกิดข้อผิดพลาดในการโหลดข้อมูล: $err',
                              ),
                            ),
                          ),
                    );
                  },
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.campaign),
                  label: const Text(
                    'สร้างประกาศ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                );
              },
            )
          : null,

      body: feedAsyncValue.when(
        loading: () => const LoadingView(),
        error: (error, stack) => Center(child: Text('เกิดข้อผิดพลาด: $error')),
        data: (allPosts) {
          final searchingPosts = allPosts
              .where((p) => p.postStatus.trim().toLowerCase() == 'searching')
              .toList();

          Future<void> handleRefresh() async {
            if (dormId != null) {
              ref.invalidate(roommateListByDormProvider(dormId!));
            } else {
              ref.invalidate(roommateListProvider);
            }
          }

          if (searchingPosts.isEmpty) {
            // 🚀 ไม่มีประกาศเลยสักรายการ — ยังต้องดึงลงเพื่อเช็คของใหม่ได้เสมอ ไม่ใช่ทางตัน
            return _refreshableEmptyState(
              onRefresh: handleRefresh,
              icon: Icons.campaign_outlined,
              message: 'ยังไม่มีประกาศหารูมเมทในขณะนี้',
            );
          }

          final posts = _sortPosts(
            searchingPosts.where(_passesFilters).toList(),
          );

          return Column(
            children: [
              RoommateSortBar(
                resultCount: posts.length,
                selected: _sortOption,
                isLocating: _isLocating,
                onSelected: _handleSortSelected,
              ),
              Expanded(
                child: posts.isEmpty
                    ? _refreshableEmptyState(
                        onRefresh: handleRefresh,
                        icon: Icons.search_off,
                        message: 'ไม่พบประกาศที่ตรงกับตัวกรอง',
                      )
                    : RefreshIndicator(
                        onRefresh: handleRefresh,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: posts.length,
                          itemBuilder: (context, index) {
                            final post = posts[index];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () {
                                    context.push(
                                      '/roommate-detail',
                                      extra: post,
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 30,
                                          backgroundColor:
                                              colorScheme.primaryContainer,
                                          // 🚀 จำกัดขนาด decode รูปโปรไฟล์ (การ์ดหลายใบพร้อมกันในลิสต์)
                                          backgroundImage:
                                              post.memberImage != null
                                              ? ResizeImage(
                                                  NetworkImage(
                                                    post.memberImage!,
                                                  ),
                                                  width: 120,
                                                )
                                              : null,
                                          child: post.memberImage == null
                                              ? Icon(
                                                  Icons.person,
                                                  color: colorScheme
                                                      .onPrimaryContainer,
                                                  size: 30,
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                post.memberName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(
                                                    post.memberGender == 'Male'
                                                        ? Icons.male
                                                        : post.memberGender ==
                                                              'Female'
                                                        ? Icons.female
                                                        : Icons.person_outline,
                                                    size: 16,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    post.memberGender == 'Male'
                                                        ? 'เพศชาย'
                                                        : post.memberGender ==
                                                              'Female'
                                                        ? 'เพศหญิง'
                                                        : 'ไม่ระบุเพศ',
                                                    style: TextStyle(
                                                      color:
                                                          Colors.grey.shade600,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'ต้องการหาเพิ่ม ${post.reqPersons} คน',
                                                style: TextStyle(
                                                  color: Colors.orange.shade900,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            if (post.hasRoomAlready) ...[
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.teal.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.verified_rounded,
                                                      color:
                                                          Colors.teal.shade700,
                                                      size: 13,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'มีห้องแล้ว',
                                                      style: TextStyle(
                                                        color: Colors
                                                            .teal
                                                            .shade700,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                            ],
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: const Text(
                                                'กำลังหา',
                                                style: TextStyle(
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
