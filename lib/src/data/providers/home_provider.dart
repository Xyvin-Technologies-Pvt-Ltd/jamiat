import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamiat/src/data/apis/user_api.dart';
import 'package:jamiat/src/data/models/user_model.dart';
import 'package:jamiat/src/data/providers/campaign_provider.dart';
import 'package:jamiat/src/data/providers/donation_provider.dart';
import 'package:jamiat/src/data/providers/news_provider.dart';
import 'package:jamiat/src/data/providers/welfare_provider.dart';

final homeStatsProvider = FutureProvider.autoDispose<
  ({UserModel user, num totalDonated, int participatedCampaigns})
>((ref) async {
  final profile = await ref.watch(userProfileProvider.future);
  final history = await ref.watch(donationHistoryProvider.future);

  return (
    user: profile,
    totalDonated: history.summary.totalDonated,
    participatedCampaigns: history.summary.participatedCampaigns,
  );
});

Future<void> refreshHomeData(WidgetRef ref) async {
  ref.invalidate(userProfileProvider);
  ref.invalidate(donationHistoryProvider);
  ref.invalidate(featuredCampaignsProvider);
  ref.invalidate(newsListProvider);
  ref.invalidate(homeStatsProvider);
  ref.invalidate(welfareListProvider);

  await Future.wait([
    _ignoreErrors(ref.read(userProfileProvider.future)),
    _ignoreErrors(ref.read(donationHistoryProvider.future)),
    _ignoreErrors(ref.read(featuredCampaignsProvider.future)),
    _ignoreErrors(ref.read(newsListProvider.future)),
    _ignoreErrors(ref.read(homeStatsProvider.future)),
    _ignoreErrors(ref.read(welfareListProvider.future)),
  ]);
}

Future<void> _ignoreErrors(Future<dynamic> future) async {
  try {
    await future;
  } catch (_) {}
}
