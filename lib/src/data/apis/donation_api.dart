import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamiat/src/data/models/api_response.dart';
import 'package:jamiat/src/data/models/donation_model.dart';
import 'package:jamiat/src/data/providers/api_provider.dart';

class DonationApi {
  DonationApi(this._api);

  final ApiProvider _api;

  Future<ApiResponse<DonationCreateResult>> createDonation({
    required String campaignId,
    required num amount,
    String? message,
  }) async {
    final response = await _api.post('/donation', {
      'campaign': campaignId,
      'amount': amount,
      if (message != null && message.isNotEmpty) 'message': message,
    }, requireAuth: true);

    if (!response.success) {
      return ApiResponse.error(
        response.message ?? 'Failed to create donation',
        response.statusCode,
      );
    }

    final data = nestedData(response.data);
    if (data == null) {
      return ApiResponse.error(
        'Invalid donation response',
        response.statusCode,
      );
    }
    return ApiResponse.success(
      DonationCreateResult.fromJson(data),
      response.statusCode ?? 200,
    );
  }

  Future<ApiResponse<DonationModel>> verifyPayment({
    required String donationId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
    String status = 'success',
  }) async {
    final response = await _api.post('/donation/verify-payment', {
      'donation_id': donationId,
      'razorpay_order_id': razorpayOrderId,
      'razorpay_payment_id': razorpayPaymentId,
      'razorpay_signature': razorpaySignature,
      'status': status,
    }, requireAuth: true);

    if (!response.success) {
      return ApiResponse.error(
        response.message ?? 'Payment verification failed',
        response.statusCode,
      );
    }

    final data = nestedData(response.data);
    if (data == null) {
      return ApiResponse.error('Invalid verify response', response.statusCode);
    }
    return ApiResponse.success(
      DonationModel.fromJson(data),
      response.statusCode ?? 200,
    );
  }

  Future<
    ApiResponse<
      ({DonationHistorySummary summary, List<DonationModel> donations})
    >
  >
  getHistory({
    int pageNo = 1,
    int limit = 100,
    String status = 'success',
  }) async {
    final response = await _api.get(
      '/donation/history',
      requireAuth: true,
      queryParams: {
        'page_no': '$pageNo',
        'limit': '$limit',
        if (status.isNotEmpty) 'status': status,
      },
    );

    if (!response.success) {
      return ApiResponse.error(
        response.message ?? 'Failed to load donation history',
        response.statusCode,
      );
    }

    final data = nestedData(response.data);
    if (data == null) {
      return ApiResponse.error('Invalid history response', response.statusCode);
    }

    final summaryJson = data['summary'];
    final summary = summaryJson is Map
        ? DonationHistorySummary.fromJson(
            Map<String, dynamic>.from(summaryJson),
            totalPayments: nestedTotalCount(response.data),
          )
        : DonationHistorySummary.fromJson(
            data,
            totalPayments: nestedTotalCount(response.data),
          );
    final donations = (data['donations'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => DonationModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return ApiResponse.success((
      summary: summary,
      donations: donations,
    ), response.statusCode ?? 200);
  }

  Future<ApiResponse<Map<String, dynamic>>> getReceipt(
    String donationId,
  ) async {
    final response = await _api.get(
      '/donation/receipt/$donationId',
      requireAuth: true,
    );
    if (!response.success) {
      return ApiResponse.error(
        response.message ?? 'Failed to load receipt',
        response.statusCode,
      );
    }
    final data = nestedData(response.data);
    if (data == null) {
      return ApiResponse.error('Invalid receipt response', response.statusCode);
    }
    return ApiResponse.success(data, response.statusCode ?? 200);
  }

  Future<ApiResponse<Map<String, dynamic>>> downloadHistory({
    String status = 'success',
  }) async {
    final response = await _api.get(
      '/donation/history/download',
      requireAuth: true,
      queryParams: {
        if (status.isNotEmpty) 'status': status,
      },
    );
    if (!response.success) {
      return ApiResponse.error(
        response.message ?? 'Failed to download donation history',
        response.statusCode,
      );
    }
    final data = nestedData(response.data);
    if (data == null) {
      return ApiResponse.error(
        'Invalid download response',
        response.statusCode,
      );
    }
    return ApiResponse.success(data, response.statusCode ?? 200);
  }
}

final donationApiProvider = Provider<DonationApi>(
  (ref) => DonationApi(ref.watch(apiProviderProvider)),
);
