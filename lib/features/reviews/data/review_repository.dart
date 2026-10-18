import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:find_dorm_mate/core/config/api_config.dart';
import 'package:find_dorm_mate/core/network/api_client.dart';
import '../domain/review_model.dart';

final reviewRepositoryProvider = Provider((ref) => ReviewRepository());

class DormReviewsResult {
  final List<ReviewModel> reviews;
  final double? averageRating;
  final int reviewCount;

  DormReviewsResult({
    required this.reviews,
    this.averageRating,
    this.reviewCount = 0,
  });
}

// 🚀 รีวิวของหอพักหนึ่งๆ (public) — key ด้วย dormId
final dormReviewsProvider = FutureProvider.autoDispose
    .family<DormReviewsResult, int>((ref, dormId) async {
      return ref.read(reviewRepositoryProvider).getDormReviews(dormId);
    });

class ReviewRepository {
  final Dio _dio = ApiClient.instance;
  final String baseUrl = '${ApiConfig.apiUrl}/reviews';

  Future<Map<String, dynamic>> createReview({
    required int bookingId,
    required int rating,
    String? comment,
  }) async {
    try {
      final response = await _dio.post(
        baseUrl,
        data: {
          'bookingId': bookingId,
          'rating': rating,
          if (comment != null && comment.isNotEmpty) 'comment': comment,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'ส่งรีวิวไม่สำเร็จ');
    }
  }

  Future<DormReviewsResult> getDormReviews(int dormId) async {
    try {
      final response = await _dio.get('$baseUrl/dorm/$dormId');
      final data = response.data;
      final List reviewsJson = data['data'] ?? [];
      return DormReviewsResult(
        reviews: reviewsJson.map((r) => ReviewModel.fromJson(r)).toList(),
        averageRating: data['averageRating'] != null
            ? double.tryParse(data['averageRating'].toString())
            : null,
        reviewCount: data['reviewCount'] ?? 0,
      );
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'ดึงข้อมูลรีวิวไม่สำเร็จ',
      );
    }
  }

  Future<void> updateReview(int reviewId, {int? rating, String? comment}) async {
    try {
      await _dio.patch(
        '$baseUrl/$reviewId',
        data: {
          if (rating != null) 'rating': rating,
          if (comment != null) 'comment': comment,
        },
      );
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'แก้ไขรีวิวไม่สำเร็จ');
    }
  }

  Future<void> deleteReview(int reviewId) async {
    try {
      await _dio.delete('$baseUrl/$reviewId');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'ลบรีวิวไม่สำเร็จ');
    }
  }
}
