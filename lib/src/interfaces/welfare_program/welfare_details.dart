import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamiat/src/data/apis/campaign_api.dart';
import 'package:jamiat/src/data/constants/color_constants.dart';
import 'package:jamiat/src/data/constants/style_constants.dart';
import 'package:jamiat/src/data/models/campaign_model.dart';
import 'package:jamiat/src/data/models/welfare_model.dart';
import 'package:jamiat/src/data/providers/campaign_provider.dart';
import 'package:jamiat/src/data/providers/welfare_provider.dart';
import 'package:jamiat/src/data/services/haptic_helper.dart';
import 'package:jamiat/src/data/services/navigation_services.dart';
import 'package:jamiat/src/data/services/campaign_share_service.dart';
import 'package:jamiat/src/interfaces/components/async_content.dart';
import 'package:jamiat/src/interfaces/components/campaign_card.dart';

class WelfareDetailsScreen extends ConsumerStatefulWidget {
  final String welfareId;

  const WelfareDetailsScreen({super.key, required this.welfareId});

  @override
  ConsumerState<WelfareDetailsScreen> createState() =>
      _WelfareDetailsScreenState();
}

class _WelfareDetailsScreenState extends ConsumerState<WelfareDetailsScreen> {
  final Map<String, bool> _bookmarkOverrides = {};
  String? _bookmarkLoadingId;
  String? _shareLoadingId;

  bool _isBookmarked(CampaignModel campaign) {
    return _bookmarkOverrides[campaign.id] ?? campaign.isBookmarked;
  }

  Future<void> _toggleBookmark(CampaignModel campaign) async {
    if (_bookmarkLoadingId != null) return;
    final currently = _isBookmarked(campaign);
    setState(() => _bookmarkLoadingId = campaign.id);
    try {
      final api = ref.read(campaignApiProvider);
      final res = currently
          ? await api.removeBookmark(campaign.id)
          : await api.bookmarkCampaign(campaign.id);
      if (!mounted) return;
      if (!res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message ?? 'Bookmark failed')),
        );
        return;
      }
      setState(() => _bookmarkOverrides[campaign.id] = !currently);
      ref.invalidate(savedCampaignsProvider);
      ref.invalidate(welfareDetailProvider(widget.welfareId));
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

  void _openDonate(CampaignModel campaign) {
    HapticHelper.impact(HapticImpact.medium);
    NavigationService().pushNamed(
      'CampaignDetails',
      arguments: {'campaignId': campaign.id},
    );
  }

  Widget _headerCircleButton({
    required Widget child,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: kWhite,
          border: Border.all(color: kGrey, width: 1.25),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  Widget _heroImage(String? url) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: url != null && url.startsWith('http')
          ? Image.network(
              url,
              fit: BoxFit.contain,
              width: double.infinity,
              errorBuilder: (_, _, _) => Image.asset(
                'assets/jpgs/campaign_welfare.jpg',
                fit: BoxFit.contain,
                width: double.infinity,
              ),
            )
          : Image.asset(
              'assets/jpgs/campaign_welfare.jpg',
              fit: BoxFit.contain,
              width: double.infinity,
            ),
    );
  }

  Widget _buildBody(WelfareServiceModel service) {
    final hasTarget =
        (service.targetLabel != null && service.targetLabel!.isNotEmpty) ||
        service.targetYear != null;
    final targetTitle = service.targetYear != null
        ? 'Target for ${service.targetYear} Year'
        : 'Target';
    final targetSub =
        service.targetLabel?.isNotEmpty == true ? service.targetLabel! : '';
    final screenW = MediaQuery.sizeOf(context).width;
    final impactCount = service.impactStatus.length;
    final statColumns = impactCount.clamp(1, 3);
    final statGapTotal = 10.0 * (statColumns - 1);
    final statWidth =
        (screenW - (kScreenPaddingH * 2) - statGapTotal) / statColumns;

    return RefreshIndicator(
      color: kPrimaryColor,
      onRefresh: () async {
        ref.invalidate(welfareDetailProvider(widget.welfareId));
        await ref.read(welfareDetailProvider(widget.welfareId).future);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(horizontal: kScreenPaddingH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(kCardRadiusMd),
              child: _heroImage(service.icon),
            ),
            const SizedBox(height: 16),
            Text(
              service.shortDescription,
              style: kCaption12SB.copyWith(color: kTextColor, height: 1.2),
            ),
            if (service.fullDescription != null &&
                service.fullDescription!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                service.fullDescription!,
                style: kCaption12R.copyWith(color: kTextColor, height: 1.4),
              ),
            ],
            for (final block in service.statements) ...[
              const SizedBox(height: 24),
              Text(block.heading, style: kSectionTitleSB),
              const SizedBox(height: 8),
              Text(
                block.description,
                style: kCaption12R.copyWith(color: kTextColor, height: 1.4),
              ),
            ],
            if (service.impactStatus.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Journey so far', style: kSectionTitleSB),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: service.impactStatus.map((stat) {
                  return Container(
                    width: statWidth,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kSecondarySoftBg,
                      borderRadius: BorderRadius.circular(kCardRadiusSm),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stat.title,
                          style: kCaption12R.copyWith(
                            color: kMutedText,
                            height: 1.3,
                            fontWeight: kBold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            stat.status,
                            maxLines: 1,
                            style: kSectionTitle19SB.copyWith(
                              color: kSecondaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
            if (hasTarget) ...[
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F8FF),
                  borderRadius: BorderRadius.circular(kCardRadiusMd),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.track_changes,
                      color: Color(0xFF3B82F6),
                      size: 32,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(targetTitle, style: kSectionTitleSB),
                          if (targetSub.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              targetSub,
                              style: kCaption12R.copyWith(
                                color: kTextColor,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (service.linkedCampaigns.isNotEmpty) ...[
              const SizedBox(height: 24),
              SizedBox(
                height: 56,
                width: double.infinity,
                child: Material(
                  color: kPrimaryColor,
                  borderRadius: BorderRadius.circular(kCardRadiusSm),
                  child: InkWell(
                    onTap: () => _openDonate(service.linkedCampaigns.first),
                    borderRadius: BorderRadius.circular(kCardRadiusSm),
                    child: Center(
                      child: Text('Donate', style: kButtonLabelSB),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Donate for ${service.name}',
                style: kSectionTitleSB,
              ),
              const SizedBox(height: 14),
              ...service.linkedCampaigns.map(
                (campaign) => CampaignListCard(
                  campaign: campaign,
                  isBookmarked: _isBookmarked(campaign),
                  isBookmarkLoading: _bookmarkLoadingId == campaign.id,
                  isShareLoading: _shareLoadingId == campaign.id,
                  onDonate: () => _openDonate(campaign),
                  onBookmark: () {
                    HapticHelper.impact(HapticImpact.light);
                    _toggleBookmark(campaign);
                  },
                  onShare: () {
                    HapticHelper.impact(HapticImpact.light);
                    _shareCampaign(campaign);
                  },
                ),
              ),
            ] else ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'No active campaigns for this program yet.',
                  style: kEmptyStateM,
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(welfareDetailProvider(widget.welfareId));
    final title = detailAsync.value?.name ?? 'Welfare';

    return Scaffold(
      backgroundColor: kWhite,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                kScreenPaddingH,
                8,
                kScreenPaddingH,
                16,
              ),
              child: Row(
                children: [
                  _headerCircleButton(
                    onTap: () {
                      HapticHelper.impact(HapticImpact.light);
                      Navigator.pop(context);
                    },
                    child: const Icon(
                      Icons.arrow_back,
                      color: kTextColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: kSectionTitleSB,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AsyncContent(
                asyncValue: detailAsync,
                onRetry: () =>
                    ref.invalidate(welfareDetailProvider(widget.welfareId)),
                builder: _buildBody,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
