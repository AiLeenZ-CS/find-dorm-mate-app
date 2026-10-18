import 'package:find_dorm_mate/core/router/role_wrapper.dart';
import 'package:find_dorm_mate/features/auth/presentation/change_password_screen.dart';
import 'package:find_dorm_mate/features/auth/presentation/forgot_password_screen.dart';
import 'package:find_dorm_mate/features/auth/presentation/reset_password_screen.dart';
import 'package:find_dorm_mate/features/dormitory/domain/dorm_detail_model.dart';
import 'package:find_dorm_mate/features/dormitory/presentation/dorm_map_screen.dart';
import 'package:find_dorm_mate/features/dormitory/presentation/room_type_detail_screen.dart';
import 'package:find_dorm_mate/features/owner/presentation/add_dormitory_screen.dart';
import 'package:find_dorm_mate/features/owner/presentation/add_room_type_screen.dart';
import 'package:find_dorm_mate/features/notifications/presentation/notifications_screen.dart';
import 'package:find_dorm_mate/features/dormitory/domain/room_type_detail_model.dart';
import 'package:find_dorm_mate/features/owner/presentation/edit_dorm_screen.dart';
import 'package:find_dorm_mate/features/owner/presentation/owner_main_screen.dart';
import 'package:find_dorm_mate/features/booking/presentation/my_bookings_screen.dart';
import 'package:find_dorm_mate/features/booking/presentation/owner_bookings_screen.dart';
import 'package:find_dorm_mate/features/roommate/domain/roommate_post_model.dart';
import 'package:find_dorm_mate/features/roommate/presentation/create_roommate_post_screen.dart';
import 'package:find_dorm_mate/features/roommate/presentation/roommate_detail_screen.dart';
import 'package:find_dorm_mate/features/roommate/presentation/roommate_match_requests_screen.dart';
import 'package:find_dorm_mate/features/roommate/presentation/my_roommate_matches_screen.dart';
import 'package:find_dorm_mate/features/roommate/presentation/roommate_chat_screen.dart';
import 'package:find_dorm_mate/features/roommate/presentation/roommate_pre_chat_screen.dart';
import 'package:find_dorm_mate/features/roommate/presentation/chats_hub_screen.dart';
import 'package:find_dorm_mate/features/profile/presentation/edit_profile_screen.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/complete_profile_screen.dart';
import '../../features/dormitory/presentation/dorm_detail_screen.dart';
import '../../features/roommate/presentation/roommate_feed_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/', // ✅ เริ่มที่ SplashScreen เพื่อเตรียมข้อมูล/เช็ค Token
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),

    GoRoute(
      path: '/complete-profile',
      builder: (context, state) => const CompleteProfileScreen(),
    ),

    // ✅ นายสถานี: คอยเช็คสิทธิ์
    // - ถ้าไม่ได้ล็อกอิน (Guest) หรือเป็นผู้ใช้ทั่วไป -> โชว์หน้า MainScreen (หน้า Home ปกติ)
    // - ถ้าล็อกอินแล้วเป็นเจ้าของหอ (Owner) -> โชว์หน้า OwnerDashboardScreen
    GoRoute(path: '/home', builder: (context, state) => const RoleWrapper()),

    GoRoute(
      path: '/dorm/:id',
      builder: (context, state) {
        final idStr = state.pathParameters['id'];
        final id = int.tryParse(idStr ?? '0') ?? 0;
        return DormDetailScreen(dormId: id);
      },
    ),

    GoRoute(
      path: '/room/:id',
      builder: (context, state) {
        final idStr = state.pathParameters['id'];
        final id = int.tryParse(idStr ?? '0') ?? 0;
        return RoomTypeDetailScreen(roomId: id);
      },
    ),

    GoRoute(
      path: '/map',
      builder: (context, state) {
        // 🚀 รับค่าพิกัดที่แอบส่งมาในกล่อง extra (ถ้ามี)
        final extra = state.extra as Map<String, dynamic>?;

        return DormMapScreen(
          initialLat: extra?['lat'],
          initialLng: extra?['lng'],
        );
      },
    ),

    // 🆕 หน้ารวมแจ้งเตือนในแอป — ใช้ร่วมกันทั้ง Member และ Owner
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),

    GoRoute(
      path: '/owner-dashboard',
      builder: (context, state) => const OwnerMainScreen(),
    ),

    GoRoute(
      path: '/add-dorm',
      builder: (context, state) => const AddDormitoryScreen(),
    ),

    // 🆕 เส้นทางแก้ไขหอพัก (รับ dormId จาก path และรายละเอียดปัจจุบันผ่าน extra)
    GoRoute(
      path: '/edit-dorm/:id',
      builder: (context, state) {
        final idStr = state.pathParameters['id'];
        final id = int.tryParse(idStr ?? '0') ?? 0;
        final dorm = state.extra as DormDetailModel?;
        return EditDormScreen(dormId: id, dorm: dorm);
      },
    ),

    // 🆕 เส้นทางสำหรับไปหน้า เพิ่มประเภทห้องพัก (รับค่า dormId ไปด้วย)
    GoRoute(
      path: '/add-room-type/:dormId',
      builder: (context, state) {
        // ดึงค่า dormId จาก URL (pathParameters) แล้วแปลงเป็น int
        final String dormIdStr = state.pathParameters['dormId']!;
        final int dormId = int.parse(dormIdStr);

        // ส่ง ID หอพักไปให้หน้า AddRoomTypeScreen
        return AddRoomTypeScreen(dormId: dormId);
      },
    ),

    // 🆕 เส้นทางแก้ไขห้องพัก (รับ dormId จาก path และรายละเอียดห้องปัจจุบันผ่าน extra —
    // มาจากปุ่ม "แก้ไขข้อมูลห้องพักนี้" ที่มีข้อมูลห้องอยู่ในมือแล้วเสมอ ไม่ต้อง fetch ซ้ำ)
    GoRoute(
      path: '/edit-room-type/:dormId',
      builder: (context, state) {
        final dormId = int.tryParse(state.pathParameters['dormId'] ?? '') ?? 0;
        final room = state.extra as RoomTypeDetailModel;
        return AddRoomTypeScreen(dormId: dormId, existingRoom: room);
      },
    ),

    GoRoute(
      path: '/dorm/:dormId/roommates',
      builder: (context, state) {
        final dormIdStr = state.pathParameters['dormId'];
        final dormId = dormIdStr != null ? int.tryParse(dormIdStr) : null;
        return RoommateFeedScreen(dormId: dormId); // 👈 ส่ง dormId เข้าไปแล้ว!
      },
    ),

    GoRoute(
      path: '/roommates',
      builder: (context, state) {
        return const RoommateFeedScreen(); // 👈 ไม่ส่ง dormId ก็จะโชว์ทั้งหมด
      },
    ),

    GoRoute(
      path: '/roommate-detail',
      builder: (context, state) {
        // 🚀 รับค่า Object ที่ส่งพ่วงมาด้วย (extra)
        final post = state.extra as RoommatePostModel;
        return RoommateDetailScreen(post: post);
      },
    ),

    // 🆕 แชทกลุ่มของรูมเมทที่จับคู่แล้ว (1 ห้องแชทต่อ 1 ประกาศ) — extra ใส่ชื่อหอ/ห้อง
    // ไว้โชว์เป็น title มา ถ้าไม่ส่งมาก็ใช้ชื่อ default แทน
    GoRoute(
      path: '/roommate-chat/:postId',
      builder: (context, state) {
        final postIdStr = state.pathParameters['postId'];
        final postId = postIdStr != null ? int.tryParse(postIdStr) ?? 0 : 0;
        final title = state.extra as String?;

        return RoommateChatScreen(postId: postId, title: title);
      },
    ),

    // 🆕 แชท 1:1 "ก่อนตอบรับ" — เจ้าของประกาศหรือผู้ขอกดทักแชท (คนละห้องจากแชทกลุ่มด้านบน)
    // extra เป็น Map {title, image} ไว้โชว์ชื่อ/รูปโปรไฟล์ของอีกฝ่าย ถ้าไม่ส่งมาก็ใช้ default แทน
    GoRoute(
      path: '/roommate-pre-chat/:matchId',
      builder: (context, state) {
        final matchIdStr = state.pathParameters['matchId'];
        final matchId = matchIdStr != null ? int.tryParse(matchIdStr) ?? 0 : 0;
        final extra = state.extra as Map<String, dynamic>?;
        final title = extra?['title'] as String?;
        final otherPartyImage = extra?['image'] as String?;

        return RoommatePreChatScreen(
          matchId: matchId,
          title: title,
          otherPartyImage: otherPartyImage,
        );
      },
    ),

    GoRoute(
      path: '/create-roommate-post/:dormId',
      builder: (context, state) {
        final dormIdStr = state.pathParameters['dormId'];
        final dormId = dormIdStr != null ? int.tryParse(dormIdStr) ?? 0 : 0;

        // 🚀 รับค่า Map ที่ส่งมาจาก BottomSheet (หรือจากปุ่ม "ประกาศหารูมเมท" บนใบจอง
        // ที่ยืนยันแล้ว ซึ่งจะแนบ bookingId มาด้วย)
        final extraData = state.extra as Map<String, dynamic>;
        final roomTypeId = extraData['roomTypeId'] as int;
        final roomTypeName = extraData['roomTypeName'] as String;
        final bookingId = extraData['bookingId'] as int?;

        return CreateRoommatePostScreen(
          dormId: dormId,
          roomTypeId: roomTypeId,
          roomTypeName: roomTypeName,
          bookingId: bookingId,
        );
      },
    ),

    // 🆕 หน้าแก้ไขประกาศหารูมเมทเดิม — ใช้หน้าเดียวกับหน้าสร้าง แค่ส่ง existingPost มาด้วย
    // ให้ดึงข้อมูลหอ/ห้อง/bookingId มาจากตัวประกาศเองแทนที่จะต้องรับผ่าน path/extra แยก
    GoRoute(
      path: '/edit-roommate-post',
      builder: (context, state) {
        final post = state.extra as RoommatePostModel;
        return CreateRoommatePostScreen(
          dormId: post.dormId ?? 0,
          roomTypeId: post.roomTypeId ?? 0,
          roomTypeName: post.roomTypeName ?? '',
          bookingId: post.bookingId,
          existingPost: post,
        );
      },
    ),

    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),

    GoRoute(
      path: '/reset-password/:id/:token',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        final token = state.pathParameters['token']!;
        return ResetPasswordScreen(id: id, token: token);
      },
    ),

    // 🚀 เส้นทางใหม่: กดมาจากหน้า Profile
    GoRoute(
      path: '/change-password',
      builder: (context, state) => const ChangePasswordScreen(),
    ),

    GoRoute(
      path: '/my-bookings',
      builder: (context, state) => const MyBookingsScreen(),
    ),

    // 🆕 เส้นทางฝั่งเจ้าของหอ — ดูใบจองทั้งหมดที่เข้ามาที่หอของตัวเอง + อนุมัติ/ปฏิเสธ
    GoRoute(
      path: '/owner-bookings',
      builder: (context, state) => const OwnerBookingsScreen(),
    ),

    // 🆕 เส้นทางฝั่งเจ้าของประกาศหารูมเมท — ดูคำขอจับคู่ที่เข้ามา + อนุมัติ/ปฏิเสธ
    GoRoute(
      path: '/roommate-post/:postId/requests',
      builder: (context, state) {
        final postIdStr = state.pathParameters['postId'];
        final postId = int.tryParse(postIdStr ?? '0') ?? 0;
        return RoommateMatchRequestsScreen(postId: postId);
      },
    ),

    // 🆕 "แชทของฉัน" — กดจากปุ่มแชทที่หน้าหลัก แยกแท็บ "แชทเดี่ยว" (คำขอจับคู่ทุกสถานะที่
    // เกี่ยวข้อง) และ "รูมเมทที่จับคู่แล้ว" (แชทกลุ่มของประกาศที่มีคนจับคู่แล้ว)
    GoRoute(
      path: '/chats',
      builder: (context, state) => const ChatsHubScreen(),
    ),

    // 🆕 "รูมเมทของฉัน" — ประกาศที่ตัวเองสร้าง + ประกาศที่ตัวเองจับคู่สำเร็จ
    // (ให้ตามดูได้แม้ประกาศจะปิดจากหน้ารวมไปแล้วเพราะจับคู่ครบแล้ว)
    GoRoute(
      path: '/my-roommate-matches',
      builder: (context, state) => const MyRoommateMatchesScreen(),
    ),

    // 🆕 เส้นทางแก้ไขข้อมูลส่วนตัว — รับ { user, isOwner } มาจาก ProfileScreen ผ่าน extra
    GoRoute(
      path: '/edit-profile',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return EditProfileScreen(
          user: extra['user'] as Map<String, dynamic>,
          isOwner: extra['isOwner'] as bool,
        );
      },
    ),
  ],
);
