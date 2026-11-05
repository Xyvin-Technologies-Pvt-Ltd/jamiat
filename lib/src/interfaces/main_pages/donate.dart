import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:jamiat/src/data/apis/campaign_api.dart';
import 'package:jamiat/src/data/constants/color_constants.dart';
import 'package:jamiat/src/data/constants/style_constants.dart';
import 'package:jamiat/src/data/models/campaign_model.dart';
import 'package:jamiat/src/data/providers/campaign_provider.dart';
import 'package:jamiat/src/data/services/haptic_helper.dart';
import 'package:jamiat/src/data/services/navigation_services.dart';
import 'package:jamiat/src/data/services/campaign_share_service.dart';
import 'package:jamiat/src/data/utils/category_mapper.dart';
import 'package:jamiat/src/data/utils/format_helpers.dart';
import 'package:jamiat/src/interfaces/components/async_content.dart';
import 'package:jamiat/src/interfaces/components/campaign_card.dart';
import 'package:jamiat/src/interfaces/components/primarybutton.dart';

String _formatCount(int value) {
  final raw = value.toString();
  final buf = StringBuffer();
  final len = raw.length;
  for (var i = 0; i < len; i++) {
    if (i > 0 && (len - i) % 3 == 0) buf.write(',');
    buf.write(raw[i]);
  }
  return buf.toString();
}

class DonatePage extends ConsumerStatefulWidget {
  const DonatePage({super.key});

  @override
  ConsumerState<DonatePage> createState() => _DonatePageState();
}

class _DonatePageState extends ConsumerState<DonatePage> {
  final _searchController = TextEditingController();
  final Map<String, bool> _bookmarkOverrides = {};
  String? _bookmarkLoadingId;
  String? _shareLoadingId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isBookmarked(CampaignModel campaign) {
    return _bookmarkOverrides[campaign.id] ?? campaign.isBookmarked;
  }

  Future<void> _toggleBookmark(CampaignModel campaign) async {
    if (_bookmarkLoadingId != null) return;
    final currentlyBookmarked = _isBookmarked(campaign);
    setState(() => _bookmarkLoadingId = campaign.id);
    try {
      final api = ref.read(campaignApiProvider);
      final res = currentlyBookmarked
          ? await api.removeBookmark(campaign.id)
          : await api.bookmarkCampaign(campaign.id);
      if (!mounted) return;
      if (!res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message ?? 'Bookmark failed')),
        );
        return;
      }
      setState(() {
        _bookmarkOverrides[campaign.id] = !currentlyBookmarked;
      });
      ref.invalidate(savedCampaignsProvider);
      ref.invalidate(featuredCampaignsProvider);
    } finally {
      if (mounted) setState(() => _bookmarkLoadingId = null);
    }
  }

  Future<void> _shareCampaign(CampaignModel campaign) async {
    if (_shareLoadingId != null) return;
    setState(() => _shareLoadingId = campaign.id);
    try {
      HapticHelper.impact(HapticImpact.light);
      await ref.read(campaignShareServiceProvider).shareCampaign(
            context: context,
            campaignId: campaign.id,
            title: campaign.title,
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _shareLoadingId = null);
    }
  }

  List<CampaignModel> _filterLocal(List<CampaignModel> items) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return items;
    return items.where((c) {
      return c.title.toLowerCase().contains(query) ||
          c.description.toLowerCase().contains(query) ||
          c.category.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final selectedCategory = ref.watch(campaignCategoryFilterProvider);
    final statsAsync = ref.watch(campaignMobileStatsProvider);
    final listAsync = ref.watch(campaignListProvider(1));

    return Scaffold(
      backgroundColor: kWhite,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                kScreenPaddingH,
                8,
                kScreenPaddingH,
                0,
              ),
              child: _CampaignsHeader(),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kScreenPaddingH),
              child: _SearchField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 16),
            _CategoryChips(
              categories: CategoryMapper.donateTabCategories,
              selected: selectedCategory,
              onSelected: (value) {
                HapticHelper.impact(HapticImpact.light);
                ref
                    .read(campaignCategoryFilterProvider.notifier)
                    .setCategory(value);
              },
            ),
            const SizedBox(height: 24),
            Expanded(
              child: AsyncContent(
                asyncValue: listAsync,
                onRetry: () {
                  ref.invalidate(campaignListProvider(1));
                  ref.invalidate(campaignMobileStatsProvider);
                },
                builder: (page) {
                  final campaigns = _filterLocal(page.items);
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      kScreenPaddingH,
                      0,
                      kScreenPaddingH,
                      24,
                    ),
                    children: [
                      _StatsRow(statsAsync: statsAsync),
                      const SizedBox(height: 16),
                      if ((statsAsync.value?.endingSoonCount ?? 0) > 0) ...[
                        _EndingSoonBanner(statsAsync: statsAsync),
                        const SizedBox(height: 16),
                      ],
                      if (campaigns.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: Center(
                            child: Text(
                              'No campaigns found',
                              style: kEmptyStateM,
                            ),
                          ),
                        )
                      else
                        ...campaigns.map(
                          (campaign) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _CampaignCard(
                              campaign: campaign,
                              isBookmarked: _isBookmarked(campaign),
                              isBookmarkLoading:
                                  _bookmarkLoadingId == campaign.id,
                              isShareLoading: _shareLoadingId == campaign.id,
                              onBookmark: () {
                                HapticHelper.impact(HapticImpact.light);
                                _toggleBookmark(campaign);
                              },
                              onShare: () {
                                HapticHelper.impact(HapticImpact.light);
                                _shareCampaign(campaign);
                              },
                              onDonate: () {
                                HapticHelper.impact(HapticImpact.medium);
                                NavigationService().pushNamed(
                                  'CampaignDetails',
                                  arguments: {'campaignId': campaign.id},
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CampaignsHeader extends StatelessWidget {
  const _CampaignsHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text('Campaigns', style: kSectionTitleSB)),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: kWhite,
            border: Border.all(color: kStrokeColor, width: 1.25),
          ),
          child: PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.more_vert, color: kIconMuted, size: 22),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(kCardRadiusMd),
              side: const BorderSide(color: kStrokeColor, width: 1),
            ),
            color: kWhite,
            elevation: 4,
            offset: const Offset(0, 44),
            onSelected: (value) {
              HapticHelper.impact(HapticImpact.light);
              if (value == 'history') {
                NavigationService().pushNamed('DonationHistory');
              } else {
                NavigationService().pushNamed('SavedDonations');
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'saved_campaigns',
                height: 44,
                child: Text(
                  'Saved Campaigns',
                  style: kStyle(kMedium, 15, color: const Color(0xFF888888)),
                ),
              ),
              const PopupMenuDivider(height: 1),
              PopupMenuItem<String>(
                value: 'history',
                height: 44,
                child: Text(
                  'Donation History',
                  style: kStyle(kMedium, 15, color: const Color(0xFF888888)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    // Figma Input Field 1: 56h · r16 · border #E3E3E3
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(kCardRadiusLg),
        border: Border.all(color: kCardBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.search, color: kSecondaryTextColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: kBodyTitleR,
              cursorColor: kPrimaryColor,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Search for campaigns',
                hintStyle: kBodyTitleR.copyWith(color: kSecondaryTextColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Figma chips: 30h · r6 · selected #FBBD05 · unselected soft yellow + border
    return SizedBox(
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: kScreenPaddingH),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final label = categories[index];
          final isSelected = label == selected;
          return GestureDetector(
            onTap: () => onSelected(label),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected
                    ? kSecondaryColor
                    : kSecondaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(kCardRadiusXs),
                border: Border.all(color: kSecondaryColor),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: kCaption12M.copyWith(
                  color: isSelected ? kTextColor : kMutedText,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.statsAsync});

  final AsyncValue<CampaignMobileStats> statsAsync;

  @override
  Widget build(BuildContext context) {
    final stats = statsAsync.value;
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Active',
            value: stats != null ? '${stats.activeCampaigns}' : '—',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Raised Total',
            value: stats != null ? formatRupeeCompact(stats.raisedTotal) : '—',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Donors',
            value: stats != null ? _formatCount(stats.totalDonors) : '—',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    // Figma stats: ~87h · p16 · r14 · #EDF9F3 · label 12 · value 19 SB primary
    return Container(
      constraints: const BoxConstraints(minHeight: 87),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kContributionsBg,
        borderRadius: BorderRadius.circular(kCardRadiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: kCaption12R.copyWith(color: kMutedText),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: kLabel19SB.copyWith(color: kPrimaryColor, height: 1.2),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _EndingSoonBanner extends StatelessWidget {
  const _EndingSoonBanner({required this.statsAsync});

  final AsyncValue<CampaignMobileStats> statsAsync;

  @override
  Widget build(BuildContext context) {
    final count = statsAsync.value?.endingSoonCount ?? 0;
    // Figma ending-soon: #FFF5F4 · r14 · danger-circle 24 · body + green link
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kEndingSoonBg,
        borderRadius: BorderRadius.circular(kCardRadiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: kRed, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count Campaigns ending in less than 3 days',
                  style: kBodyTitleR.copyWith(color: kTextColor, height: 1.2),
                ),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: () {
                    HapticHelper.impact(HapticImpact.light);
                    NavigationService().pushNamed('EndingSoonCampaignsList');
                  },
                  child: Text('Donate Now', style: kLinkSB),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final CampaignModel campaign;
  final bool isBookmarked;
  final bool isBookmarkLoading;
  final bool isShareLoading;
  final VoidCallback onBookmark;
  final VoidCallback onShare;
  final VoidCallback onDonate;

  const _CampaignCard({
    required this.campaign,
    required this.isBookmarked,
    required this.onBookmark,
    required this.onShare,
    required this.onDonate,
    this.isBookmarkLoading = false,
    this.isShareLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasTarget = campaign.hasTargetAmount;
    final progress = hasTarget
        ? (campaign.collectedAmount / campaign.targetAmount).clamp(0.0, 1.0)
        : 0.0;
    final percent = hasTarget
        ? (campaign.progressPercent > 0
              ? campaign.progressPercent
              : (progress * 100).round())
        : 0;
    final categoryLabel = CategoryMapper.toUi(campaign.category);
    final daysColor = campaign.hasDaysRemaining && campaign.remainingDays! <= 7
        ? kDaysLeftWarning
        : kMutedText;

    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(kCardRadiusMd),
        border: Border.all(color: kCardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onDonate,
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
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xCCD5D5D5),
                          borderRadius: BorderRadius.circular(kCardRadiusXs),
                        ),
                        child: Text(
                          categoryLabel,
                          style: kCaption10M.copyWith(color: kTextColor),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Row(
                        children: [
                          _OverlayIconButton(
                            asset: 'assets/svg/share.svg',
                            onTap: isShareLoading ? null : onShare,
                            loading: isShareLoading,
                          ),
                          const SizedBox(width: 8),
                          _OverlayIconButton(
                            asset: 'assets/svg/bookmark.svg',
                            onTap: isBookmarkLoading ? null : onBookmark,
                            filled: isBookmarked,
                            loading: isBookmarkLoading,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      campaign.title,
                      style: kBodyTitleSB,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      campaign.description,
                      style: kCaption12R.copyWith(
                        color: kMutedText,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hasTarget) ...[
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(1),
                        child: LinearProgressIndicator(
                          value: progress.toDouble(),
                          minHeight: 4,
                          backgroundColor: kGreyLight.withValues(alpha: 0.4),
                          color: kSecondaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  formatRupee(campaign.collectedAmount),
                                  style: kCaption12SB.copyWith(
                                    color: kTextColor,
                                  ),
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
                              Text(
                                '$percent%',
                                style: kCaption12SB.copyWith(color: kTextColor),
                              ),
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
                    primaryButton(
                      label: 'Donate Now',
                      onPressed: onDonate,
                      buttonHeight: 48,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverlayIconButton extends StatelessWidget {
  final String asset;
  final VoidCallback? onTap;
  final bool filled;
  final bool loading;

  const _OverlayIconButton({
    required this.asset,
    required this.onTap,
    this.filled = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kBlack.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: kWhite,
                    ),
                  )
                : SvgPicture.asset(
                    asset,
                    width: 16,
                    height: 16,
                    colorFilter: ColorFilter.mode(
                      filled ? kSecondaryColor : kWhite,
                      BlendMode.srcIn,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
