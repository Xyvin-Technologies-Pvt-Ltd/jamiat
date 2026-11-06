import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamiat/src/data/constants/color_constants.dart';
import 'package:jamiat/src/data/constants/style_constants.dart';
import 'package:jamiat/src/data/models/autopay_model.dart';
import 'package:jamiat/src/data/providers/autopay_provider.dart';
import 'package:jamiat/src/data/services/haptic_helper.dart';
import 'package:jamiat/src/data/services/navigation_services.dart';
import 'package:jamiat/src/data/utils/format_helpers.dart';
import 'package:jamiat/src/interfaces/components/async_content.dart';

class AutopayViewScreen extends ConsumerStatefulWidget {
  const AutopayViewScreen({super.key});

  @override
  ConsumerState<AutopayViewScreen> createState() => _AutopayViewScreenState();
}

class _AutopayViewScreenState extends ConsumerState<AutopayViewScreen> {
  bool _isOngoing = true;

  Widget _buildTabButton(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? kSecondaryColor : kWhite,
          borderRadius: BorderRadius.circular(kCardRadiusSm),
          border: Border.all(color: kSecondaryColor, width: 1.25),
        ),
        child: Text(
          label,
          style: kCaption12M.copyWith(
            fontWeight: isSelected ? kSemiBold : kMedium,
            color: isSelected ? kTextColor : kMutedText,
          ),
        ),
      ),
    );
  }

  bool _isActive(AutopayModel a) {
    final s = a.status.toLowerCase();
    return s == 'active' || s == 'ongoing' || s == 'paused';
  }

  /// Checkout inserts a pending row before Razorpay finishes. Leaving the
  /// checkout does not create a mandate, so those rows are not listed.
  bool _isListed(AutopayModel a) {
    final s = a.status.toLowerCase().trim();
    if (s == 'pending' || s == 'created') return false;
    if (s == 'cancelled' && (a.paymentsDone ?? 0) == 0) return false;
    return true;
  }

  Widget _buildCampaignCard(AutopayModel autopay) {
    return GestureDetector(
      onTap: () {
        HapticHelper.impact(HapticImpact.light);
        NavigationService().pushNamed(
          'AutopayDetails',
          arguments: {
            'title': autopay.campaignName ?? 'Autopay',
            'description': '${formatRupee(autopay.amount)} • ${autopay.period}',
            'status': autopay.status,
            'mandateAmount': formatRupee(autopay.amount),
            'period': autopay.period,
            'autopayId': autopay.id,
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: kScreenBg,
          borderRadius: BorderRadius.circular(kCardRadiusLg),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(
                  Icons.autorenew,
                  color: Color(0xFF2563EB),
                  size: 26,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    autopay.campaignName ?? 'Autopay',
                    style: kBodyTitleB.copyWith(
                      color: kTextColor,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatRupee(autopay.amount)} • ${autopay.period} • ${autopay.status}',
                    style: kCaption12R.copyWith(
                      color: kSecondaryTextColor,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final autopaysAsync = ref.watch(myAutopaysProvider);

    return Scaffold(
      backgroundColor: kWhite,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            kScreenPaddingH,
            8,
            kScreenPaddingH,
            16,
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Autopay',
                      style: kSectionTitleSB,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      HapticHelper.impact(HapticImpact.light);
                      NavigationService().pushNamed('DonationList');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: kPrimaryColor,
                        borderRadius: BorderRadius.circular(kCardRadiusSm),
                      ),
                      child: Text(
                        'Set up',
                        style: kCaption12M.copyWith(color: kWhite),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  _buildTabButton('Ongoing', _isOngoing, () {
                    HapticHelper.impact(HapticImpact.light);
                    setState(() => _isOngoing = true);
                  }),
                  const SizedBox(width: 12),
                  _buildTabButton('Past', !_isOngoing, () {
                    HapticHelper.impact(HapticImpact.light);
                    setState(() => _isOngoing = false);
                  }),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: AsyncContent(
                  asyncValue: autopaysAsync,
                  onRetry: () => ref.invalidate(myAutopaysProvider),
                  builder: (items) {
                    final filtered = items
                        .where(
                          (a) =>
                              _isListed(a) &&
                              (_isOngoing ? _isActive(a) : !_isActive(a)),
                        )
                        .toList();
                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          _isOngoing
                              ? 'No ongoing autopays'
                              : 'No past autopays',
                          style: kEmptyStateM,
                        ),
                      );
                    }
                    return ListView(
                      children: filtered.map(_buildCampaignCard).toList(),
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
