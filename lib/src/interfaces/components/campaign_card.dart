import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:jamiat/src/data/constants/color_constants.dart';
import 'package:jamiat/src/data/constants/style_constants.dart';
import 'package:jamiat/src/data/models/campaign_model.dart';
import 'package:jamiat/src/data/utils/category_mapper.dart';
import 'package:jamiat/src/data/utils/format_helpers.dart';
import 'package:jamiat/src/data/utils/network_image_utils.dart';
import 'package:jamiat/src/interfaces/components/primarybutton.dart';

/// Neutral broken-image state when a campaign has no usable cover.
Widget campaignImagePlaceholder({
  double iconSize = 40,
  bool showLabel = true,
}) {
  return ColoredBox(
    color: const Color(0xFFF0F0F0),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: iconSize,
            color: kIconMuted,
          ),
          if (showLabel) ...[
            SizedBox(height: iconSize >= 36 ? 8 : 4),
            Text(
              'No image',
              style: kCaption12R.copyWith(
                color: kSecondaryTextColor,
                height: 1.2,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Campaign cover: disk-cached network image sized to the layout, otherwise a
/// professional placeholder. Never falls back to a dummy stock photo.
Widget campaignCoverImage(
  String? url, {
  BoxFit fit = BoxFit.cover,
  double placeholderIconSize = 40,
  bool showPlaceholderLabel = true,
}) {
  final resolved = resolveNetworkImageUrl(url);
  if (resolved == null) {
    return campaignImagePlaceholder(
      iconSize: placeholderIconSize,
      showLabel: showPlaceholderLabel,
    );
  }

  final placeholder = campaignImagePlaceholder(
    iconSize: placeholderIconSize,
    showLabel: showPlaceholderLabel,
  );

  return LayoutBuilder(
    builder: (context, constraints) {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      // Decode at display size so large uploads aren't fully rasterized.
      // Prefer width so aspect ratio is preserved for BoxFit.cover cards.
      final memWidth = networkImageCachePx(
        constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width,
        dpr,
      );
      final diskWidth = memWidth == null ? 900 : memWidth.clamp(1, 900);

      return CachedNetworkImage(
        imageUrl: resolved,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        memCacheWidth: memWidth,
        maxWidthDiskCache: diskWidth,
        fadeInDuration: const Duration(milliseconds: 180),
        fadeOutDuration: const Duration(milliseconds: 120),
        placeholder: (_, _) => const ColoredBox(color: Color(0xFFF0F0F0)),
        errorWidget: (_, _, _) => placeholder,
      );
    },
  );
}

/// Campaign list card — Figma Campaigns (636:1338) card layout.
class CampaignListCard extends StatelessWidget {
  const CampaignListCard({
    super.key,
    required this.campaign,
    required this.onDonate,
    required this.onBookmark,
    required this.onShare,
    this.isBookmarked,
    this.isBookmarkLoading = false,
    this.isShareLoading = false,
    this.donateLabel = 'Donate Now',
    this.showOverlayActions = true,
  });

  final CampaignModel campaign;
  final VoidCallback onDonate;
  final VoidCallback onBookmark;
  final VoidCallback onShare;
  final bool? isBookmarked;
  final bool isBookmarkLoading;
  final bool isShareLoading;
  final String donateLabel;
  final bool showOverlayActions;

  @override
  Widget build(BuildContext context) {
    final bookmarked = isBookmarked ?? campaign.isBookmarked;
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
      margin: const EdgeInsets.only(bottom: 16),
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
                    if (showOverlayActions)
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
                              filled: bookmarked,
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
                          backgroundColor: kGreyLight.withValues(alpha: 0.45),
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
                      label: donateLabel,
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
  const _OverlayIconButton({
    required this.asset,
    required this.onTap,
    this.filled = false,
    this.loading = false,
  });

  final String asset;
  final VoidCallback? onTap;
  final bool filled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kWhite.withValues(alpha: 0.22),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: kWhite.withValues(alpha: 0.85), width: 1.25),
          ),
          alignment: Alignment.center,
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
    );
  }
}
