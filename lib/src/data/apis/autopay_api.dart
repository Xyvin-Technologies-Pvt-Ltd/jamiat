import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamiat/src/data/models/api_response.dart';
import 'package:jamiat/src/data/models/autopay_model.dart';
import 'package:jamiat/src/data/providers/api_provider.dart';

class AutopayApi {
  AutopayApi(this._api);

  final ApiProvider _api;

  Future<ApiResponse<AutopayCreateResult>> createAutopay({
    required String campaignId,
    required num amount,
    required String period,
    String? message,
  }) async {
    final response = await _api.post('/autopay', {
      'campaign': campaignId,
      'amount': amount,
      'period': period,
      if (message != null && message.isNotEmpty) 'message': message,
    }, requireAuth: true);

    if (!response.success) {
      return ApiResponse.error(
        response.message ?? 'Failed to create autopay',
        response.statusCode,
      );
    }

    final data = nestedData(response.data);
    if (data == null) {
      return ApiResponse.error('Invalid autopay response', response.statusCode);
    }
    return ApiResponse.success(
      AutopayCreateResult.fromJson(data),
      response.statusCode ?? 200,
    );
  }

  Future<ApiResponse<AutopayModel>> verifyAutopay({
    required String autopayId,
    required String razorpaySubscriptionId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final response = await _api.post('/autopay/verify', {
      'autopay_id': autopayId,
      'razorpay_subscription_id': razorpaySubscriptionId,
      'razorpay_payment_id': razorpayPaymentId,
      'razorpay_signature': razorpaySignature,
    }, requireAuth: true);

    if (!response.success) {
      return ApiResponse.error(
        response.message ?? 'Autopay verification failed',
        response.statusCode,
      );
    }

    final data = nestedData(response.data);
    if (data == null) {
      return ApiResponse.error('Invalid verify response', response.statusCode);
    }
    return ApiResponse.success(
      AutopayModel.fromJson(data),
      response.statusCode ?? 200,
    );
  }

  Future<ApiResponse<List<AutopayModel>>> getMyAutopays() async {
    final response = await _api.get(
      '/autopay/my',
      requireAuth: true,
      queryParams: const {'page_no': '1', 'limit': '100'},
    );
    if (!response.success) {
      return ApiResponse.error(
        response.message ?? 'Failed to load autopays',
        response.statusCode,
      );
    }
    final items = nestedListData(
      response.data,
    ).map(AutopayModel.fromJson).toList();
    return ApiResponse.success(items, response.statusCode ?? 200);
  }

  Future<ApiResponse<AutopayModel>> getAutopayById(String id) async {
    final response = await _api.get('/autopay/$id', requireAuth: true);
    if (!response.success) {
      return ApiResponse.error(
        response.message ?? 'Failed to load autopay',
        response.statusCode,
      );
    }
    final data = nestedData(response.data);
    if (data == null) {
      return ApiResponse.error('Invalid autopay response', response.statusCode);
    }
    return ApiResponse.success(
      AutopayModel.fromJson(data),
      response.statusCode ?? 200,
    );
  }

  Future<ApiResponse<AutopayHistoryResult>> getAutopayHistory(
    String id, {
    int pageNo = 1,
    int limit = 20,
  }) async {
    final response = await _api.get(
      '/autopay/$id/history',
      requireAuth: true,
      queryParams: {'page_no': '$pageNo', 'limit': '$limit'},
    );
    if (!response.success) {
      return ApiResponse.error(
        response.message ?? 'Failed to load autopay history',
        response.statusCode,
      );
    }
    final data = nestedData(response.data);
    if (data == null) {
      return ApiResponse.error('Invalid history response', response.statusCode);
    }
    return ApiResponse.success(
      AutopayHistoryResult.fromJson(data),
      response.statusCode ?? 200,
    );
  }

  Future<ApiResponse<void>> cancelAutopay(String id) async {
    final response = await _api.patch(
      '/autopay/cancel/$id',
      const {},
      requireAuth: true,
    );
    if (!response.success) {
      return ApiResponse.error(
        response.message ?? 'Failed to cancel autopay',
        response.statusCode,
      );
    }
    return ApiResponse.success(null, response.statusCode ?? 200);
  }

  Future<ApiResponse<void>> pauseAutopay(String id) async {
    final response = await _api.patch(
      '/autopay/pause/$id',
      const {},
      requireAuth: true,
    );
    if (!response.success) {
      return ApiResponse.error(
        response.message ?? 'Failed to pause autopay',
        response.statusCode,
      );
    }
    return ApiResponse.success(null, response.statusCode ?? 200);
  }

  Future<ApiResponse<void>> resumeAutopay(String id) async {
    final response = await _api.patch(
      '/autopay/resume/$id',
      const {},
      requireAuth: true,
    );
    if (!response.success) {
      return ApiResponse.error(
        response.message ?? 'Failed to resume autopay',
        response.statusCode,
      );
    }
    return ApiResponse.success(null, response.statusCode ?? 200);
  }
}

final autopayApiProvider = Provider<AutopayApi>(
  (ref) => AutopayApi(ref.watch(apiProviderProvider)),
);
