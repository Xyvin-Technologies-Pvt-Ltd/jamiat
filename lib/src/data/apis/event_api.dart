import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamiat/src/data/models/api_response.dart';
import 'package:jamiat/src/data/models/event_model.dart';
import 'package:jamiat/src/data/models/paginated_response.dart';
import 'package:jamiat/src/data/providers/api_provider.dart';

class EventApi {
  EventApi(this._api);

  final ApiProvider _api;

  Future<ApiResponse<PaginatedResponse<EventModel>>> listEvents({
    int pageNo = 1,
    int limit = 20,
    String? search,
  }) async {
    final response = await _api.get(
      '/event/list',
      requireAuth: true,
      queryParams: {
        'page_no': '$pageNo',
        'limit': '$limit',
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );

    if (!response.success) {
      return ApiResponse.error(
        response.message ?? 'Failed to load events',
        response.statusCode,
      );
    }

    final items = nestedListData(
      response.data,
    ).map(EventModel.fromJson).toList();

    return ApiResponse.success(
      PaginatedResponse(
        items: items,
        totalCount: nestedTotalCount(response.data),
        pageNo: pageNo,
        limit: limit,
      ),
      response.statusCode ?? 200,
    );
  }

  Future<ApiResponse<EventModel>> getEventById(String id) async {
    final response = await _api.get('/event/$id', requireAuth: true);
    if (!response.success) {
      return ApiResponse.error(
        response.message ?? 'Failed to load event',
        response.statusCode,
      );
    }
    final data = nestedData(response.data);
    if (data == null) {
      return ApiResponse.error('Invalid event response', response.statusCode);
    }
    return ApiResponse.success(
      EventModel.fromJson(data),
      response.statusCode ?? 200,
    );
  }

  Future<ApiResponse<List<EventModel>>> getSavedEvents() async {
    final response = await _api.get('/event/saved', requireAuth: true);
    if (!response.success) {
      return ApiResponse.error(
        response.message ?? 'Failed to load saved events',
        response.statusCode,
      );
    }
    final items = nestedListData(
      response.data,
    ).map(EventModel.fromJson).toList();
    return ApiResponse.success(items, response.statusCode ?? 200);
  }

  Future<ApiResponse<void>> bookmarkEvent(String eventId) async {
    final response = await _api.post('/event/bookmark', {
      'event_id': eventId,
    }, requireAuth: true);
    if (!response.success) {
      return ApiResponse.error(
        response.message ?? 'Failed to save event',
        response.statusCode,
      );
    }
    return ApiResponse.success(null, response.statusCode ?? 200);
  }

  Future<ApiResponse<void>> removeBookmark(String eventId) async {
    final response = await _api.delete(
      '/event/bookmark/$eventId',
      requireAuth: true,
    );
    if (!response.success) {
      return ApiResponse.error(
        response.message ?? 'Failed to remove bookmark',
        response.statusCode,
      );
    }
    return ApiResponse.success(null, response.statusCode ?? 200);
  }

  Future<ApiResponse<EventTicketModel>> registerForEvent(String eventId) async {
    final response = await _api.post(
      '/event/$eventId/register',
      const {},
      requireAuth: true,
    );
    final data = nestedData(response.data);
    // Offline tickets (and "already registered" 400) include ticket_code.
    if (data != null && data['ticket_code'] != null) {
      return ApiResponse.success(
        EventTicketModel.fromJson(data),
        response.statusCode ?? 200,
        message: response.message,
      );
    }
    if (!response.success) {
      return ApiResponse.error(
        response.message ?? 'Registration failed',
        response.statusCode,
      );
    }
    // Online events register without a ticket — accept id-only / empty payloads.
    if (data != null) {
      return ApiResponse.success(
        EventTicketModel.fromJson(data),
        response.statusCode ?? 200,
        message: response.message ?? 'Registered successfully',
      );
    }
    return ApiResponse.success(
      null,
      response.statusCode ?? 200,
      message: response.message ?? 'Registered successfully',
    );
  }

  Future<ApiResponse<List<EventTicketModel>>> getMyTickets({
    String tab = 'upcoming',
    int pageNo = 1,
    int limit = 100,
  }) async {
    final response = await _api.get(
      '/event/my-tickets',
      requireAuth: true,
      queryParams: {
        'tab': tab,
        'page_no': '$pageNo',
        'limit': '$limit',
      },
    );
    if (!response.success) {
      return ApiResponse.error(
        response.message ?? 'Failed to load tickets',
        response.statusCode,
      );
    }
    final items = nestedListData(
      response.data,
    ).map(EventTicketModel.fromJson).toList();
    return ApiResponse.success(items, response.statusCode ?? 200);
  }

  Future<ApiResponse<EventTicketModel>> getTicketById(String ticketId) async {
    final response = await _api.get(
      '/event/ticket/$ticketId',
      requireAuth: true,
    );
    if (!response.success) {
      return ApiResponse.error(
        response.message ?? 'Failed to load ticket',
        response.statusCode,
      );
    }
    final data = nestedData(response.data);
    if (data == null) {
      return ApiResponse.error('Invalid ticket response', response.statusCode);
    }
    return ApiResponse.success(
      EventTicketModel.fromJson(data),
      response.statusCode ?? 200,
    );
  }

  /// Coordinator check-in via ticket QR token.
  /// `POST /event/scan` body: `{ qr_token }`.
  Future<ApiResponse<EventScanResult>> scanTicket(String qrToken) async {
    final response = await _api.post(
      '/event/scan',
      {'qr_token': qrToken},
      requireAuth: true,
    );

    final data = nestedData(response.data);
    if (data != null && data['ticket_code'] != null) {
      return ApiResponse.success(
        EventScanResult.fromJson(data, message: response.message),
        response.statusCode ?? 200,
        message: response.message,
      );
    }

    if (!response.success) {
      return ApiResponse.error(
        response.message ?? 'Failed to scan ticket',
        response.statusCode,
      );
    }

    return ApiResponse.error(
      'Invalid scan response',
      response.statusCode,
    );
  }

  Future<ApiResponse<Map<String, dynamic>>> shareEvent(String eventId) async {
    final response = await _api.post(
      '/event/share/$eventId',
      const {},
      requireAuth: true,
    );
    if (!response.success) {
      return ApiResponse.error(
        response.message ?? 'Failed to share',
        response.statusCode,
      );
    }
    final data = nestedData(response.data) ?? response.data;
    return ApiResponse.success(
      data,
      response.statusCode ?? 200,
      message: response.message,
    );
  }
}

final eventApiProvider = Provider<EventApi>(
  (ref) => EventApi(ref.watch(apiProviderProvider)),
);
