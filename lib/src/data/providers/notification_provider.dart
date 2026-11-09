import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamiat/src/data/apis/notification_api.dart';
import 'package:jamiat/src/data/models/notification_model.dart';
import 'package:jamiat/src/data/models/paginated_response.dart';

final notificationsProvider =
    FutureProvider.autoDispose<PaginatedResponse<NotificationModel>>((
      ref,
    ) async {
      final response = await ref.watch(notificationApiProvider).getForUser();
      if (!response.success || response.data == null) {
        throw Exception(response.message ?? 'Failed to load notifications');
      }
      return response.data!;
    });
