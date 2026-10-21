// 📄 ไฟล์นี้ทำหน้าที่: หน้าหลักของแอปฝั่งผู้ใช้ สำหรับค้นหา/กรอง/เรียงลำดับรายการหอพักทั้งหมด
// ประกอบจาก widgets ย่อยใน widgets/home/ (ช่องค้นหา, ตัวกรอง, การ์ดหอพัก, แถบเรียงลำดับ)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:find_dorm_mate/core/utils/json_list_parser.dart';
import 'package:find_dorm_mate/features/auth/data/auth_repository.dart';
import 'package:find_dorm_mate/features/dormitory/domain/dorm_model.dart';
import '../data/dorm_repository.dart';
import 'widgets/home/home_filters.dart';
import 'widgets/home/home_search_header.dart';
import 'widgets/home/home_filter_sheet.dart';
import 'widgets/home/home_sort_bar.dart';
import 'widgets/home/home_sort_option.dart';
import 'widgets/home/dorm_card.dart';

/// หน้า Home — ค้นหา/กรองหอพัก ธีม Material 3 เดียวกับหน้ารายละเอียด
/// (การ์ดเงานุ่มนวล, ช่องค้นหา/ตัวกรองแยก widget ไว้ที่ widgets/home/)
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _searchQuery = '';
  HomeFilters _filters = const HomeFilters(
    dormType: 'All',
    airFan: 'All',
    priceRange: RangeValues(0, 15000),
  );

  HomeSortOption _sortOption = HomeSortOption.recommended;
  Position? _currentPosition;
  bool _isLocating = false;
  String? _username;

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _username = prefs.getString('username'));
  }

  // 🚀 คำนวณราคาต่ำสุดของหอ (ใช้ร่วมกันทั้งตอนกรองราคาและตอนเรียงราคา กันลอจิกซ้ำ
  // ที่เคยเขียนแยกกัน 2 ที่ใน _passesFilters และ _getPriceRangeDisplay)
  double _minPrice(DormModel dorm) {
    double minPrice = dorm.startingPrice ?? 0;
    if (dorm.roomTypes != null && dorm.roomTypes!.isNotEmpty) {
      final prices = <double>[];
      for (var room in dorm.roomTypes!) {
        if (room is Map<String, dynamic> && room['Price_Per_Month'] != null) {
          final p = double.tryParse(room['Price_Per_Month'].toString());
          if (p != null && p > 0) prices.add(p);
        }
      }
      if (prices.isNotEmpty) {
        prices.sort();
        minPrice = prices.first;
      }
    }
    return minPrice;
  }

  // 🚀 เช็คว่าคำค้นหาตรงกับชื่อหอ หรือสิ่งอำนวยความสะดวกไหม (ทั้ง Master และ Custom
  // และเช็คทั้งระดับหอพักเองกับระดับห้องพักแต่ละประเภทในหอนั้น)
  // ทำให้พิมพ์เช่น "ที่จอดรถ" หรือ "มีระเบียง" แล้วเจอหอที่มีสิ่งอำนวยความสะดวกนั้นได้เลย
  // ถึงแม้ชื่อหอจะไม่มีคำนั้นอยู่
  bool _matchesSearchQuery(DormModel dorm, String query) {
    final q = query.toLowerCase();

    if (dorm.name.toLowerCase().contains(q)) return true;

    for (final f in dorm.facilities) {
      if (f.toLowerCase().contains(q)) return true;
    }
    for (final f in dorm.customFacilities) {
      if (f.toLowerCase().contains(q)) return true;
    }

    if (dorm.roomTypes != null) {
      for (final room in dorm.roomTypes!) {
        if (room is Map<String, dynamic>) {
          for (final f in parseStringListJson(room['Custom_Facilities'])) {
            if (f.toLowerCase().contains(q)) return true;
          }
        }
      }
    }

    return false;
  }

  // 🚀 คำนวณช่วงราคาจาก Room_Types โดยไม่ต้องพึ่ง Database
  String _getPriceRangeDisplay(DormModel dorm) {
    if (dorm.roomTypes != null && dorm.roomTypes!.isNotEmpty) {
      final prices = <double>[];

      for (var room in dorm.roomTypes!) {
        if (room is Map<String, dynamic> && room['Price_Per_Month'] != null) {
          final price = double.tryParse(room['Price_Per_Month'].toString());
          if (price != null && price > 0) prices.add(price);
        }
      }

      if (prices.isNotEmpty) {
        prices.sort();
        final minPrice = prices.first;
        final maxPrice = prices.last;
        return minPrice == maxPrice
            ? '฿${minPrice.toStringAsFixed(0)}/เดือน'
            : '฿${minPrice.toStringAsFixed(0)} - ฿${maxPrice.toStringAsFixed(0)}/เดือน';
      }
    }

    if (dorm.startingPrice != null && dorm.startingPrice! > 0) {
      return 'เริ่มต้น ฿${dorm.startingPrice?.toStringAsFixed(0)}/เดือน';
    }

    return 'ยังไม่ระบุราคา';
  }

  bool _passesFilters(DormModel dorm) {
    if (dorm.status?.toLowerCase() != 'approved') return false;

    if (_searchQuery.isNotEmpty && !_matchesSearchQuery(dorm, _searchQuery)) {
      return false;
    }

    // กรองประเภทหอพัก (ชาย/หญิง/รวม)
    if (_filters.dormType != 'All') {
      final type = dorm.dormType ?? 'Mixed';
      if (type != _filters.dormType) return false;
    }

    // กรองประเภทห้อง (แอร์/พัดลม) - เช็คจาก Room_Types
    if (_filters.airFan != 'All') {
      final hasMatchingRoom =
          dorm.roomTypes?.any(
            (room) =>
                room is Map<String, dynamic> &&
                room['Room_Type'] == _filters.airFan,
          ) ??
          false;
      if (!hasMatchingRoom) return false;
    }

    // กรองราคา (ดึงราคาต่ำสุดของห้องทั้งหมดมาเช็ค)
    final minPriceForFilter = _minPrice(dorm);
    final isUnlimitedMax = _filters.priceRange.end >= 15000;
    if (minPriceForFilter < _filters.priceRange.start) return false;
    if (!isUnlimitedMax && minPriceForFilter > _filters.priceRange.end) {
      return false;
    }

    // กรองคะแนนรีวิว (X ดาวขึ้นไป) — หอที่ยังไม่มีรีวิวเลย (averageRating == null) ถือว่า
    // ไม่ผ่านตัวกรองนี้ เพราะไม่มีคะแนนให้เทียบ
    if (_filters.minRating > 0) {
      final rating = dorm.averageRating;
      if (rating == null || rating < _filters.minRating) return false;
    }

    // กรองสิ่งอำนวยความสะดวกระดับหอพัก — หอต้องมีครบทุกรายการที่เลือก (AND)
    if (_filters.dormFacilities.isNotEmpty) {
      final dormFacilitySet = dorm.facilities.toSet();
      if (!_filters.dormFacilities.every(dormFacilitySet.contains)) {
        return false;
      }
    }

    // กรองสิ่งอำนวยความสะดวกระดับห้องพัก — ต้องมีอย่างน้อย 1 ห้องในหอที่มีครบทุกรายการ
    // ที่เลือก (เช็คทั้ง Master Facilities และ Custom_Facilities ของห้องนั้น)
    if (_filters.roomFacilities.isNotEmpty) {
      final hasMatchingRoom =
          dorm.roomTypes?.any((room) {
            if (room is! Map<String, dynamic>) return false;
            final roomFacilitySet = <String>{
              ...((room['Facilities'] as List?) ?? const []).map(
                (f) => f['Facility_Name']?.toString() ?? '',
              ),
              ...parseStringListJson(room['Custom_Facilities']),
            };
            return _filters.roomFacilities.every(roomFacilitySet.contains);
          }) ??
          false;
      if (!hasMatchingRoom) return false;
    }

    return true;
  }

  // 🚀 ต้อง login ก่อนถึงจะดูแชทได้ (เนื้อหาผูกกับ Member_ID จริง ไม่ใช่ฟีเจอร์ที่ Guest
  // เรียกดูได้) กันไว้ตั้งแต่ก่อนนำทาง ไม่ต้องรอไปเจอหน้าเปล่า/error ที่หน้าแชทเอง
  Future<void> _handleChatTap() async {
    final isLoggedIn = await AuthRepository().isLoggedIn();
    if (!mounted) return;

    if (!isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อนใช้งานแชท')),
      );
      context.push('/login');
      return;
    }

    context.push('/chats');
  }

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<HomeFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => HomeFilterSheet(initial: _filters),
    );

    if (result != null && mounted) {
      setState(() => _filters = result);
    }
  }

  // 🚀 เลือก "ระยะทาง: ใกล้-ไกล" ครั้งแรกต้องขอตำแหน่งปัจจุบันก่อน (ขอ permission +
  // เปิด GPS ให้ถ้ายังไม่ได้เปิด) ครั้งต่อไปถ้ามีตำแหน่งอยู่แล้วใช้ค่าเดิมได้เลยไม่ต้องขอซ้ำ
  Future<void> _handleSortSelected(HomeSortOption option) async {
    if (option != HomeSortOption.nearest || _currentPosition != null) {
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

  List<DormModel> _sortDorms(List<DormModel> dorms) {
    final sorted = [...dorms];
    switch (_sortOption) {
      case HomeSortOption.recommended:
        // 🚀 เรียงตามคะแนนรีวิวเฉลี่ยสูงสุดก่อน หอที่ยังไม่มีรีวิวดันไปท้ายลิสต์เสมอ
        sorted.sort(
          (a, b) => (b.averageRating ?? -1).compareTo(a.averageRating ?? -1),
        );
        break;
      case HomeSortOption.priceLowToHigh:
        sorted.sort((a, b) => _minPrice(a).compareTo(_minPrice(b)));
        break;
      case HomeSortOption.priceHighToLow:
        sorted.sort((a, b) => _minPrice(b).compareTo(_minPrice(a)));
        break;
      case HomeSortOption.nearest:
        final position = _currentPosition;
        if (position == null) break;
        double distanceOf(DormModel dorm) {
          if (dorm.latitude == null || dorm.longitude == null) {
            return double.infinity; // หอที่ไม่มีพิกัด ดันไปท้ายลิสต์เสมอ
          }
          return Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            dorm.latitude!,
            dorm.longitude!,
          );
        }

        sorted.sort((a, b) => distanceOf(a).compareTo(distanceOf(b)));
        break;
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final dormListAsyncValue = ref.watch(dormListProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: dormListAsyncValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 60,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16),
              Text(
                'เกิดข้อผิดพลาด: $error',
                style: const TextStyle(color: Colors.redAccent),
              ),
              TextButton(
                onPressed: () => ref.invalidate(dormListProvider),
                child: const Text('ลองใหม่'),
              ),
            ],
          ),
        ),
        data: (dorms) {
          final filteredDorms = _sortDorms(
            dorms.where(_passesFilters).toList(),
          );

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(dormListProvider);
              await ref.read(dormListProvider.future);
            },
            child: CustomScrollView(
              // 🚀 บังคับให้ลากดึงจอลงได้เสมอแม้รายการสั้นจนเนื้อหาไม่เต็มจอ (ปกติ
              // RefreshIndicator จะไม่ทำงานถ้าเนื้อหาไม่ล้นจอพอให้ scroll ได้)
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: HomeSearchHeader(
                    username: _username,
                    onSearchChanged: (value) =>
                        setState(() => _searchQuery = value),
                    onMapTap: () => context.push('/map'),
                    onFilterTap: _openFilterSheet,
                    onChatTap: _handleChatTap,
                    activeFilterCount: _filters.activeFilterCount,
                  ),
                ),
                SliverToBoxAdapter(
                  child: HomeSortBar(
                    resultCount: filteredDorms.length,
                    selected: _sortOption,
                    isLocating: _isLocating,
                    onSelected: _handleSortSelected,
                  ),
                ),
                if (filteredDorms.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 80,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'ไม่พบหอพักที่ตรงกับเงื่อนไข',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final dorm = filteredDorms[index];
                        return DormCard(
                          dorm: dorm,
                          priceDisplay: _getPriceRangeDisplay(dorm),
                          onTap: () => context.push('/dorm/${dorm.id}'),
                        );
                      }, childCount: filteredDorms.length),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          );
        },
      ),
    );
  }
}
