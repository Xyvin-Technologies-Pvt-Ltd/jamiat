import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamiat/src/data/apis/autopay_api.dart';
import 'package:jamiat/src/data/models/autopay_model.dart';

final myAutopaysProvider = FutureProvider.autoDispose<List<AutopayModel>>((
  ref,
) async {
  final response = await ref.watch(autopayApiProvider).getMyAutopays();
  if (!response.success || response.data == null) {
    throw Exception(response.message ?? 'Failed to load autopays');
  }
  return response.data!;
});

final autopayDetailProvider =
    FutureProvider.autoDispose.family<AutopayModel, String>((ref, id) async {
  final response = await ref.watch(autopayApiProvider).getAutopayById(id);
  if (!response.success || response.data == null) {
    throw Exception(response.message ?? 'Failed to load autopay');
  }
  return response.data!;
});

final autopayHistoryProvider = FutureProvider.autoDispose
    .family<AutopayHistoryResult, String>((ref, id) async {
  final response = await ref.watch(autopayApiProvider).getAutopayHistory(id);
  if (!response.success || response.data == null) {
    throw Exception(response.message ?? 'Failed to load autopay history');
  }
  return response.data!;
});
