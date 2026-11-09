import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamiat/src/data/apis/campaign_api.dart';
import 'package:jamiat/src/data/models/campaign_model.dart';
import 'package:jamiat/src/data/models/paginated_response.dart';
import 'package:jamiat/src/data/utils/category_mapper.dart';

final campaignCategoryFilterProvider =
    NotifierProvider<CampaignCategoryFilterNotifier, String>(
      CampaignCategoryFilterNotifier.new,
    );

class CampaignCategoryFilterNotifier extends Notifier<String> {
  @override
  String build() => CategoryMapper.allLabel;

  void setCategory(String category) => state = category;
}

final campaignListProvider = FutureProvider.autoDispose
    .family<PaginatedResponse<CampaignModel>, int>((ref, pageNo) async {
  final category = ref.watch(campaignCategoryFilterProvider);
  final response = await ref
      .watch(campaignApiProvider)
      .listCampaigns(pageNo: pageNo, limit: 10, category: category);
  if (!response.success || response.data == null) {
    throw Exception(response.message ?? 'Failed to load campaigns');
  }
  return response.data!;
});

final campaignMobileStatsProvider =
    FutureProvider.autoDispose<CampaignMobileStats>((ref) async {
  final response = await ref.watch(campaignApiProvider).getMobileStats();
  if (!response.success || response.data == null) {
    throw Exception(response.message ?? 'Failed to load campaign stats');
  }
  return response.data!;
});

final campaignDetailProvider =
    FutureProvider.autoDispose.family<CampaignModel, String>((ref, id) async {
  final response = await ref.watch(campaignApiProvider).getCampaignById(id);
  if (!response.success || response.data == null) {
    throw Exception(response.message ?? 'Failed to load campaign');
  }
  return response.data!;
});

final savedCampaignsProvider =
    FutureProvider.autoDispose<PaginatedResponse<CampaignModel>>((ref) async {
  final response = await ref.watch(campaignApiProvider).getSavedCampaigns();
  if (!response.success || response.data == null) {
    throw Exception(response.message ?? 'Failed to load saved campaigns');
  }
  return response.data!;
});

final featuredCampaignsProvider = FutureProvider.autoDispose<List<CampaignModel>>((
  ref,
) async {
  final response = await ref
      .watch(campaignApiProvider)
      .listCampaigns(pageNo: 1, limit: 5);
  if (!response.success || response.data == null) {
    throw Exception(response.message ?? 'Failed to load campaigns');
  }
  return response.data!.items;
});

/// Active campaigns for a specific UI/API category label.
final campaignsByCategoryProvider = FutureProvider.autoDispose
    .family<List<CampaignModel>, String>((ref, category) async {
  final response = await ref
      .watch(campaignApiProvider)
      .listCampaigns(
        pageNo: 1,
        limit: 50,
        category: category,
      );
  if (!response.success || response.data == null) {
    throw Exception(response.message ?? 'Failed to load campaigns');
  }
  return response.data!.items;
});
