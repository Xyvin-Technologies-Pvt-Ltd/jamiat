import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamiat/src/data/apis/donation_api.dart';
import 'package:jamiat/src/data/constants/color_constants.dart';
import 'package:jamiat/src/data/constants/style_constants.dart';
import 'package:jamiat/src/data/models/donation_model.dart';
import 'package:jamiat/src/data/providers/donation_provider.dart';
import 'package:jamiat/src/data/services/api_logger.dart';
import 'package:jamiat/src/data/services/donation_history_download_service.dart';
import 'package:jamiat/src/data/services/haptic_helper.dart';
import 'package:jamiat/src/data/utils/format_helpers.dart';
import 'package:jamiat/src/interfaces/components/async_content.dart';
import 'package:jamiat/src/interfaces/components/campaign_card.dart';

class DonationHistoryScreen extends ConsumerStatefulWidget {
  const DonationHistoryScreen({super.key});

  @override
  ConsumerState<DonationHistoryScreen> createState() =>
      _DonationHistoryScreenState();
}

class _DonationHistoryScreenState extends ConsumerState<DonationHistoryScreen> {
  final DonationHistoryDownloadService _downloadService =
      const DonationHistoryDownloadService();
  bool _isDownloading = false;

  Widget _circleButton({required Widget child, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: kWhite,
          border: Border.all(color: kStrokeColor, width: 1.25),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
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
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: kSectionTitle19SB.copyWith(color: kPrimaryColor),
          ),
        ],
      ),
    );
  }

  Widget _campaignImage(String? url) {
    final imageUrl = url?.trim();
    if (imageUrl != null &&
        imageUrl.isNotEmpty &&
        (imageUrl.startsWith('http://') ||
            imageUrl.startsWith('https://') ||
            imageUrl.startsWith('//'))) {
      final resolvedUrl = imageUrl.startsWith('//')
          ? 'https:$imageUrl'
          : imageUrl;
      return Image.network(
        resolvedUrl,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: 64,
            height: 64,
            color: kScreenBg,
            alignment: Alignment.center,
            child: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (_, _, _) => _campaignImagePlaceholder(),
      );
    }
    return _campaignImagePlaceholder();
  }

  Widget _campaignImagePlaceholder() {
    return campaignImagePlaceholder(iconSize: 24, showLabel: false);
  }

  String _transactionLabel(DonationModel donation) {
    final transactionId = donation.transactionId;
    if (transactionId != null && transactionId.isNotEmpty) {
      return transactionId.length > 12
          ? transactionId.substring(0, 12).toUpperCase()
          : transactionId.toUpperCase();
    }
    return donation.id.length > 12
        ? donation.id.substring(0, 12).toUpperCase()
        : donation.id.toUpperCase();
  }

  Widget _buildHistoryCard(DonationModel donation) {
    final displayDate = donation.displayDate;
    final dateTimeLabel = displayDate != null
        ? formatDonationDateTime(displayDate)
        : donation.status;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(kCardRadiusMd),
        border: Border.all(color: kCardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _campaignImage(donation.coverImage),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: kChipGreyBg,
                    borderRadius: BorderRadius.circular(kCardRadiusXs),
                  ),
                  child: Text(
                    _transactionLabel(donation),
                    style: kCaption10M.copyWith(color: kSecondaryTextColor),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  donation.campaignName ?? 'Donation',
                  style: kBodyTitleSB,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  dateTimeLabel,
                  style: kCaption12R.copyWith(color: kSecondaryTextColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatRupee(donation.amount),
                style: kBodyTitleSB,
              ),
              if (donation.hasAutopay) ...[
                const SizedBox(height: 4),
                Text(
                  'Autopay',
                  style: kCaption12M.copyWith(color: kPrimaryColor),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  List<({String label, List<DonationModel> donations})> _groupByDate(
    List<DonationModel> donations,
  ) {
    final dated = <DateTime, List<DonationModel>>{};
    final undated = <DonationModel>[];

    for (final donation in donations) {
      final date = donation.displayDate;
      if (date == null) {
        undated.add(donation);
        continue;
      }
      final local = date.toLocal();
      final dayKey = DateTime(local.year, local.month, local.day);
      dated.putIfAbsent(dayKey, () => []).add(donation);
    }

    final groups = dated.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    final result = groups
        .map(
          (entry) => (
            label: formatDonationGroupLabel(entry.key),
            donations: entry.value,
          ),
        )
        .toList();

    if (undated.isNotEmpty) {
      result.add((label: 'Recent', donations: undated));
    }

    return result;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _downloadHistory({required bool hasDonations}) async {
    if (_isDownloading) return;
    HapticHelper.impact(HapticImpact.light);

    if (!hasDonations) {
      _showMessage('No donations to download yet.');
      return;
    }

    ApiLogger.info('Downloading donation history PDF');
    setState(() => _isDownloading = true);
    try {
      final response = await ref.read(donationApiProvider).downloadHistory();
      if (!mounted) return;

      if (!response.success || response.data == null) {
        _showMessage(
          response.message ?? 'Unable to download donation history.',
        );
        return;
      }

      final data = response.data!;
      final rawUrl =
          (data['pdf_url'] ?? data['url'] ?? data['download_url'] ?? '')
              .toString()
              .trim();

      if (rawUrl.isEmpty) {
        _showMessage('Donation history PDF is not available yet.');
        return;
      }

      final result = await _downloadService.savePdfFromUrl(rawUrl);
      if (!mounted) return;

      _showMessage(
        result.message ??
            (result.isSuccess
                ? 'PDF saved to Downloads.'
                : 'Unable to save donation history PDF.'),
      );
    } catch (e) {
      if (mounted) {
        _showMessage(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(donationHistoryProvider);

    return Scaffold(
      backgroundColor: kWhite,
      body: SafeArea(
        child: AsyncContent(
          asyncValue: historyAsync,
          onRetry: () => ref.invalidate(donationHistoryProvider),
          builder: (data) {
            final grouped = _groupByDate(data.donations);
            return RefreshIndicator(
              color: kPrimaryColor,
              onRefresh: () async {
                ref.invalidate(donationHistoryProvider);
                await ref.read(donationHistoryProvider.future);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: kScreenPaddingH,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _circleButton(
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
                        Expanded(
                          child: Text(
                            'My Donations',
                            textAlign: TextAlign.center,
                            style: kSectionTitleSB,
                          ),
                        ),
                        _circleButton(
                          onTap: _isDownloading
                              ? null
                              : () => _downloadHistory(
                                  hasDonations: data.donations.isNotEmpty,
                                ),
                          child: _isDownloading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: kPrimaryColor,
                                  ),
                                )
                              : const Icon(
                                  Icons.download_outlined,
                                  color: kTextColor,
                                  size: 20,
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Total Donated',
                            formatRupee(data.summary.totalDonated),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildStatCard(
                            'Campaigns',
                            '${data.summary.participatedCampaigns}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    if (data.donations.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: Text('No donations yet', style: kEmptyStateM),
                        ),
                      )
                    else
                      ...grouped.map((group) {
                        final groupTotal = group.donations.fold<num>(
                          0,
                          (sum, d) => sum + d.amount,
                        );
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(group.label, style: kBodyTitleSB),
                                Text(
                                  formatRupee(groupTotal),
                                  style: kCaption12R.copyWith(
                                    color: kSecondaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...group.donations.map(_buildHistoryCard),
                            const SizedBox(height: 24),
                          ],
                        );
                      }),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
