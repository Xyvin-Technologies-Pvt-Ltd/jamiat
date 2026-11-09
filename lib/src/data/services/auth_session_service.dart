import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamiat/src/data/apis/user_api.dart';
import 'package:jamiat/src/data/models/api_response.dart';
import 'package:jamiat/src/data/models/user_model.dart';
import 'package:jamiat/src/data/providers/autopay_provider.dart';
import 'package:jamiat/src/data/providers/campaign_provider.dart';
import 'package:jamiat/src/data/providers/donation_provider.dart';
import 'package:jamiat/src/data/providers/empowerment_provider.dart';
import 'package:jamiat/src/data/providers/enquiry_provider.dart';
import 'package:jamiat/src/data/providers/event_provider.dart';
import 'package:jamiat/src/data/providers/home_provider.dart';
import 'package:jamiat/src/data/providers/news_provider.dart';
import 'package:jamiat/src/data/providers/notification_provider.dart';
import 'package:jamiat/src/data/providers/product_provider.dart';
import 'package:jamiat/src/data/providers/welfare_provider.dart';
import 'package:jamiat/src/data/services/secure_storage_service.dart';
import 'package:jamiat/src/data/utils/auth_navigation.dart';

class AuthSessionService {
  AuthSessionService({
    required SecureStorageService storage,
    required UserApi userApi,
  }) : _storage = storage,
       _userApi = userApi;

  final SecureStorageService _storage;
  final UserApi _userApi;

  Future<String> resolveInitialRoute() async {
    final token = await _storage.getAuthToken();
    final userId = await _storage.getUserId();

    if (token == null || token.isEmpty || userId == null || userId.isEmpty) {
      await _storage.clearSession();
      return 'Login';
    }

    final response = await _userApi.getCurrentStatus();
    if (!response.success) {
      if (response.statusCode == 401 || response.statusCode == 403) {
        await _storage.clearSession();
      }
      return 'Login';
    }

    final data = nestedData(response.data);
    if (data == null) {
      return 'Login';
    }

    final user = UserModel.fromJson(data);
    if (user.status == 'deleted' ||
        user.status == 'suspended' ||
        user.status == 'rejected') {
      await _storage.clearSession();
      return 'Login';
    }

    return routeForUser(user);
  }
}

/// Drops cached user-scoped providers so the next login cannot see old data.
void invalidateSessionCaches(WidgetRef ref) {
  ref.invalidate(userProfileProvider);
  refreshContentCaches(ref);
}

/// Invalidates API-backed content so admin-side edits show without app restart.
///
/// Safe to call on app resume: watched providers refetch while keeping the
/// previous value on screen ([skipLoadingOnRefresh]).
void refreshContentCaches(WidgetRef ref) {
  ref.invalidate(donationHistoryProvider);
  ref.invalidate(homeStatsProvider);
  ref.invalidate(featuredCampaignsProvider);
  ref.invalidate(campaignListProvider);
  ref.invalidate(campaignMobileStatsProvider);
  ref.invalidate(campaignDetailProvider);
  ref.invalidate(savedCampaignsProvider);
  ref.invalidate(campaignsByCategoryProvider);
  ref.invalidate(newsListProvider);
  ref.invalidate(newsDetailProvider);
  ref.invalidate(welfareListProvider);
  ref.invalidate(welfareDetailProvider);
  ref.invalidate(productsListProvider);
  ref.invalidate(productDetailProvider);
  ref.invalidate(savedProductsProvider);
  ref.invalidate(myProductEnquiriesProvider);
  ref.invalidate(eventsListProvider);
  ref.invalidate(eventDetailProvider);
  ref.invalidate(savedEventsProvider);
  ref.invalidate(myTicketsProvider);
  ref.invalidate(eventTicketProvider);
  ref.invalidate(myAutopaysProvider);
  ref.invalidate(autopayDetailProvider);
  ref.invalidate(autopayHistoryProvider);
  ref.invalidate(notificationsProvider);
  ref.invalidate(receivedEnquiriesProvider);
  ref.invalidate(empowermentProgramsProvider);
  ref.invalidate(empowermentProgramDetailProvider);
  ref.invalidate(empowermentSearchProvider);
}

final authSessionServiceProvider = Provider<AuthSessionService>((ref) {
  return AuthSessionService(
    storage: ref.watch(secureStorageServiceProvider),
    userApi: ref.watch(userApiProvider),
  );
});
