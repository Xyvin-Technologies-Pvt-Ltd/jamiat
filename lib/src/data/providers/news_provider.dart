import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamiat/src/data/apis/news_api.dart';
import 'package:jamiat/src/data/models/news_model.dart';
import 'package:jamiat/src/data/models/paginated_response.dart';

final newsListProvider =
    FutureProvider.autoDispose<PaginatedResponse<NewsModel>>((ref) async {
  final response = await ref.watch(newsApiProvider).getNewsForUser();
  if (!response.success || response.data == null) {
    throw Exception(response.message ?? 'Failed to load news');
  }
  return response.data!;
});

final newsDetailProvider =
    FutureProvider.autoDispose.family<NewsModel, String>((ref, id) async {
  final response = await ref.watch(newsApiProvider).getNewsById(id);
  if (!response.success || response.data == null) {
    throw Exception(response.message ?? 'Failed to load article');
  }
  return response.data!;
});

final newsSearchProvider = FutureProvider.autoDispose
    .family<PaginatedResponse<NewsModel>, ({String search, int page})>((
      ref,
      query,
    ) async {
      final response = await ref
          .watch(newsApiProvider)
          .getNewsForUser(search: query.search, pageNo: query.page);
      if (!response.success || response.data == null) {
        throw Exception(response.message ?? 'Failed to load news');
      }
      return response.data!;
    });
