import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamiat/src/data/constants/color_constants.dart';
import 'package:jamiat/src/data/constants/style_constants.dart';
import 'package:jamiat/src/data/models/campaign_model.dart';
import 'package:jamiat/src/data/providers/campaign_provider.dart';
import 'package:jamiat/src/data/services/haptic_helper.dart';
import 'package:jamiat/src/data/services/navigation_services.dart';
import 'package:jamiat/src/data/utils/category_mapper.dart';
import 'package:jamiat/src/data/utils/format_helpers.dart';
import 'package:jamiat/src/interfaces/components/async_content.dart';
import 'package:jamiat/src/interfaces/components/campaign_card.dart';

class SavedDonationsScreen extends ConsumerStatefulWidget {
  const SavedDonationsScreen({super.key});

  @override
  ConsumerState<SavedDonationsScreen> createState() =>
      _SavedDonationsScreenState();
}

class _SavedDonationsScreenState extends ConsumerState<SavedDonationsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CampaignModel> _filter(List<CampaignModel> items) {
    if (_searchQuery.isEmpty) return items;
    final query = _searchQuery.toLowerCase();
    return items.where((c) {
      return c.title.toLowerCase().contains(query) ||
          c.description.toLowerCase().contains(query) ||
          c.category.toLowerCase().contains(query);
    }).toList();
  }

  Widget _buildCampaignCard(CampaignModel campaign) {
    final hasTarget = campaign.hasTargetAmount;
    final progress = hasTarget
        ? (campaign.collectedAmount / campaign.targetAmount).clamp(0.0, 1.0)
        : 0.0;
    final percent = hasTarget
        ? (campaign.progressPercent > 0
              ? campaign.progressPercent
              : (progress * 100).round())
        : 0;
    final daysColor =
        campaign.hasDaysRemaining && campaign.remainingDays! <= 7
            ? kDaysLeftWarning
            : kMutedText;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(kCardRadiusLg),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
            color: kBlack.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                campaignCoverImage(campaign.coverImage),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: kBlack.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(kPillRadius),
                    ),
                    child: Text(
                      CategoryMapper.toUi(campaign.category),
                      style: kCaption10M.copyWith(color: kWhite),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  campaign.title,
                  style: kBodyTitleSB.copyWith(fontSize: 16),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  campaign.description,
                  style: kCaption12R.copyWith(color: kMutedText, height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (hasTarget) ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(kPillRadius),
                    child: LinearProgressIndicator(
                      value: progress.toDouble(),
                      minHeight: 8,
                      backgroundColor: kGreyLight,
                      color: kSecondaryColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formatRupee(campaign.collectedAmount),
                              style: kBodyTitleSB,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'of ${formatRupee(campaign.targetAmount)}',
                              style: kCaption12R.copyWith(
                                color: kSecondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('$percent%', style: kBodyTitleSB),
                          if (campaign.hasDaysRemaining ||
                              campaign.isEndedByTargetDate) ...[
                            const SizedBox(height: 2),
                            Text(
                              campaign.isEndedByTargetDate
                                  ? 'Ended'
                                  : '${campaign.remainingDays} days left',
                              style: kCaption12M.copyWith(color: daysColor),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: () {
                    HapticHelper.impact(HapticImpact.medium);
                    NavigationService().pushNamed(
                      'CampaignDetails',
                      arguments: {'campaignId': campaign.id},
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: kWhite,
                    minimumSize: const Size.fromHeight(48),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Donate Now',
                    style: kButtonLabelSB.copyWith(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final savedAsync = ref.watch(savedCampaignsProvider);

    return Scaffold(
      backgroundColor: kWhite,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: kScreenPaddingH,
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticHelper.impact(HapticImpact.light);
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: kWhite,
                        border: Border.all(color: kStrokeColor, width: 1.25),
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: kTextColor,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Saved Campaigns',
                    style: kSectionTitleSB,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: kWhite,
                  borderRadius: BorderRadius.circular(kPillRadius),
                  border: Border.all(color: kStrokeColor),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: kIconMuted, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: 'Search for campaigns',
                          hintStyle: kBodyTitleR.copyWith(
                            color: kSecondaryTextColor,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: kBodyTitleR,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: AsyncContent(
                  asyncValue: savedAsync,
                  onRetry: () => ref.invalidate(savedCampaignsProvider),
                  builder: (page) {
                    final campaigns = _filter(page.items);
                    if (campaigns.isEmpty) {
                      return Center(
                        child: Text(
                          'No saved campaigns found',
                          style: kEmptyStateM,
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: campaigns.length,
                      itemBuilder: (context, index) {
                        return _buildCampaignCard(campaigns[index]);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
