import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamiat/src/data/apis/welfare_api.dart';
import 'package:jamiat/src/data/models/paginated_response.dart';
import 'package:jamiat/src/data/models/welfare_model.dart';

final welfareListProvider =
    FutureProvider.autoDispose<PaginatedResponse<WelfareServiceModel>>((
      ref,
    ) async {
      final response = await ref.watch(welfareApiProvider).listServices();
      if (!response.success || response.data == null) {
        throw Exception(response.message ?? 'Failed to load welfare services');
      }
      return response.data!;
    });

final welfareDetailProvider =
    FutureProvider.autoDispose.family<WelfareServiceModel, String>((
      ref,
      id,
    ) async {
      final response = await ref.watch(welfareApiProvider).getServiceById(id);
      if (!response.success || response.data == null) {
        throw Exception(response.message ?? 'Failed to load welfare service');
      }
      return response.data!;
    });
