import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamiat/src/data/apis/donation_api.dart';
import 'package:jamiat/src/data/models/donation_model.dart';

final donationHistoryProvider = FutureProvider.autoDispose<
  ({DonationHistorySummary summary, List<DonationModel> donations})
>((ref) async {
  final response = await ref.watch(donationApiProvider).getHistory();
  if (!response.success || response.data == null) {
    throw Exception(response.message ?? 'Failed to load donation history');
  }
  return response.data!;
});
