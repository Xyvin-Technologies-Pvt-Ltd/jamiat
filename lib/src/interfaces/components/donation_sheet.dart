import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamiat/src/data/apis/autopay_api.dart';
import 'package:jamiat/src/data/apis/donation_api.dart';
import 'package:jamiat/src/data/apis/user_api.dart';
import 'package:jamiat/src/data/constants/color_constants.dart';
import 'package:jamiat/src/data/constants/style_constants.dart';
import 'package:jamiat/src/data/providers/autopay_provider.dart';
import 'package:jamiat/src/data/providers/campaign_provider.dart';
import 'package:jamiat/src/data/providers/donation_provider.dart';
import 'package:jamiat/src/data/providers/razorpay_provider.dart';
import 'package:jamiat/src/data/services/haptic_helper.dart';
import 'package:jamiat/src/data/services/navigation_services.dart';
import 'package:jamiat/src/data/services/razorpay_service.dart';
import 'package:jamiat/src/data/services/external_donation_service.dart';
import 'package:jamiat/src/data/utils/category_mapper.dart';
import 'package:jamiat/src/data/utils/format_helpers.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class DonationSheet extends ConsumerStatefulWidget {
  final String categoryTitle;
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final bool isAutopay;
  final String? campaignId;
  final String? categoryLabel;
  final num? raised;
  final num? goal;

  const DonationSheet({
    super.key,
    required this.categoryTitle,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    this.isAutopay = false,
    this.campaignId,
    this.categoryLabel,
    this.raised,
    this.goal,
  });

  static Future<void> show({
    required BuildContext context,
    required String categoryTitle,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    bool isAutopay = false,
    String? campaignId,
    String? categoryLabel,
    num? raised,
    num? goal,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // Prevent accidental dismiss while Razorpay native UI may be opening.
      isDismissible: true,
      enableDrag: true,
      builder: (_) => DonationSheet(
        categoryTitle: categoryTitle,
        icon: icon,
        iconBgColor: iconBgColor,
        iconColor: iconColor,
        isAutopay: isAutopay,
        campaignId: campaignId,
        categoryLabel: categoryLabel,
        raised: raised,
        goal: goal,
      ),
    );
  }

  @override
  ConsumerState<DonationSheet> createState() => _DonationSheetState();
}

class _DonationSheetState extends ConsumerState<DonationSheet> {
  final List<int> _presetAmounts = [100, 250, 500, 1000, 2500, 5000];
  final List<String> _periods = ['weekly', 'monthly', 'yearly'];
  final _amountController = TextEditingController();
  final _messageController = TextEditingController();
  int? _selectedPresetIndex;
  String _selectedPeriod = 'monthly';
  bool _isProcessing = false;
  String? _pendingDonationId;
  String? _pendingRazorpayOrderId;
  String? _pendingAutopayId;
  String? _pendingSubscriptionId;

  RazorpayService get _razorpay => ref.read(razorpayServiceProvider);

  @override
  void dispose() {
    _amountController.dispose();
    _messageController.dispose();
    // Do not dispose the shared Razorpay singleton — native checkout may
    // still deliver success/error after this sheet is closed.
    super.dispose();
  }

  /// Create-autopay stores a pending row before checkout. Leaving Razorpay
  /// without paying must cancel it, or the next setup is rejected as active.
  Future<void> _releaseAbandonedAutopay(String autopayId) async {
    final api = ref.read(autopayApiProvider);
    try {
      await api.cancelAutopay(autopayId);
    } catch (e) {
      log('Abandoned autopay cancel failed: $e', name: 'DonationSheet');
    }
    if (mounted) ref.invalidate(myAutopaysProvider);
  }

  void _onPresetSelected(int index, int amount) {
    HapticHelper.impact(HapticImpact.light);
    setState(() {
      _selectedPresetIndex = index;
      _amountController.text = amount.toString();
    });
  }

  void _onCustomAmountChanged(String val) {
    final parsed = int.tryParse(val.trim());
    setState(() {
      if (parsed != null && _presetAmounts.contains(parsed)) {
        _selectedPresetIndex = _presetAmounts.indexOf(parsed);
      } else {
        _selectedPresetIndex = null;
      }
    });
  }

  bool get _hasValidAmount {
    final amount = int.tryParse(_amountController.text.trim());
    return amount != null && amount > 0;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: kCaption14M.copyWith(color: kWhite)),
        backgroundColor: kRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _bindRazorpayCallbacks() {
    _razorpay.setCallbacks(
      onSuccess: _onPaymentSuccess,
      onError: _onPaymentError,
    );
  }

  ({String? contact, String? email}) _userPrefill() {
    final user = ref.read(userProfileProvider).asData?.value;
    return (contact: user?.phone, email: user?.email);
  }

  Future<void> _handlePayment() async {
    if (!_hasValidAmount) return;

    final handled = await ExternalDonationService.handleDonationClick(ref: ref);
    if (handled) {
      if (mounted) {
        setState(() => _isProcessing = false);
        Navigator.of(context).pop();
      }
      return;
    }

    final campaignId = widget.campaignId;
    if (campaignId == null || campaignId.isEmpty) {
      _showError('Campaign is required to donate.');
      return;
    }

    HapticHelper.impact(HapticImpact.medium);
    setState(() => _isProcessing = true);

    final amount = num.parse(_amountController.text.trim());
    final message = _messageController.text.trim();

    try {
      if (widget.isAutopay) {
        await _startAutopay(
          campaignId: campaignId,
          amount: amount,
          message: message,
        );
      } else {
        await _startDonation(
          campaignId: campaignId,
          amount: amount,
          message: message,
        );
      }
    } catch (e) {
      log('Payment start failed: $e', name: 'DonationSheet');
      final abandonedAutopayId = _pendingAutopayId;
      _pendingAutopayId = null;
      _pendingSubscriptionId = null;
      if (abandonedAutopayId != null) {
        unawaited(_releaseAbandonedAutopay(abandonedAutopayId));
      }
      if (mounted) setState(() => _isProcessing = false);
      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _startDonation({
    required String campaignId,
    required num amount,
    required String message,
  }) async {
    log(
      'Creating donation: campaign=$campaignId amount=$amount',
      name: 'DonationSheet',
    );
    final createResponse = await ref
        .read(donationApiProvider)
        .createDonation(
          campaignId: campaignId,
          amount: amount,
          message: message.isEmpty ? null : message,
        );

    if (!createResponse.success || createResponse.data == null) {
      if (mounted) setState(() => _isProcessing = false);
      _showError(createResponse.message ?? 'Failed to create donation');
      return;
    }

    final result = createResponse.data!;
    if (result.donationId.isEmpty || result.razorpayOrderId.isEmpty) {
      if (mounted) setState(() => _isProcessing = false);
      _showError('Invalid payment order from server. Please try again.');
      return;
    }

    _pendingDonationId = result.donationId;
    _pendingRazorpayOrderId = result.razorpayOrderId;
    _pendingAutopayId = null;
    _pendingSubscriptionId = null;

    final prefill = _userPrefill();
    _bindRazorpayCallbacks();
    _razorpay.openCheckout(
      keyId: result.razorpayKeyId,
      orderId: result.razorpayOrderId,
      amount: result.amount > 0 ? result.amount : amount,
      name: 'Jamiat Connect',
      description: widget.categoryTitle,
      contact: prefill.contact,
      email: prefill.email,
    );
  }

  Future<void> _startAutopay({
    required String campaignId,
    required num amount,
    required String message,
  }) async {
    log(
      'Creating autopay: campaign=$campaignId amount=$amount '
      'period=$_selectedPeriod',
      name: 'DonationSheet',
    );
    final createResponse = await ref
        .read(autopayApiProvider)
        .createAutopay(
          campaignId: campaignId,
          amount: amount,
          period: _selectedPeriod,
          message: message.isEmpty ? null : message,
        );

    if (!createResponse.success || createResponse.data == null) {
      if (mounted) setState(() => _isProcessing = false);
      _showError(createResponse.message ?? 'Failed to create autopay');
      return;
    }

    final result = createResponse.data!;
    if (result.autopayId.isEmpty || result.razorpaySubscriptionId.isEmpty) {
      if (mounted) setState(() => _isProcessing = false);
      _showError('Invalid subscription from server. Please try again.');
      return;
    }

    _pendingAutopayId = result.autopayId;
    _pendingSubscriptionId = result.razorpaySubscriptionId;
    _pendingDonationId = null;
    _pendingRazorpayOrderId = null;

    final prefill = _userPrefill();
    _bindRazorpayCallbacks();
    _razorpay.openSubscriptionCheckout(
      keyId: result.razorpayKeyId,
      subscriptionId: result.razorpaySubscriptionId,
      name: 'Jamiat Connect',
      description: widget.categoryTitle,
      contact: prefill.contact,
      email: prefill.email,
    );
  }

  Future<void> _onPaymentSuccess(PaymentSuccessResponse response) async {
    try {
      if (_pendingAutopayId != null) {
        await _verifyAutopay(response);
      } else if (_pendingDonationId != null) {
        await _verifyDonation(response);
      } else if (mounted) {
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      log('Payment success handling failed: $e', name: 'DonationSheet');
      if (mounted) {
        setState(() => _isProcessing = false);
        _showError(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _verifyDonation(PaymentSuccessResponse response) async {
    final donationId = _pendingDonationId!;
    final orderId = _pendingRazorpayOrderId ?? response.orderId ?? '';
    final paymentId = response.paymentId ?? '';
    final signature = response.signature ?? '';
    if (orderId.isEmpty || paymentId.isEmpty || signature.isEmpty) {
      if (mounted) setState(() => _isProcessing = false);
      _showError('Payment confirmation details are missing. Please try again.');
      return;
    }

    final verify = await ref
        .read(donationApiProvider)
        .verifyPayment(
          donationId: donationId,
          razorpayOrderId: orderId,
          razorpayPaymentId: paymentId,
          razorpaySignature: signature,
        );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (!verify.success || verify.data == null) {
      _showError(verify.message ?? 'Payment verification failed');
      return;
    }

    ref.invalidate(donationHistoryProvider);
    if (widget.campaignId != null) {
      ref.invalidate(campaignDetailProvider(widget.campaignId!));
      ref.invalidate(campaignListProvider(1));
      ref.invalidate(featuredCampaignsProvider);
      ref.invalidate(campaignMobileStatsProvider);
    }
    Navigator.of(context).pop();

    final donation = verify.data!;
    final resolvedDonationId =
        donation.id.isNotEmpty ? donation.id : donationId;
    NavigationService().pushNamed(
      'DonationSuccess',
      arguments: {
        'isAutopay': false,
        'donationId': resolvedDonationId,
        'amount': donation.amount.toString(),
        'message': donation.message,
        'campaignName': donation.campaignName ?? widget.categoryTitle,
        'transactionId': donation.transactionId ?? response.paymentId ?? '',
        'date': _formatDonationDate(donation.displayDate),
      },
    );
  }

  String _formatDonationDate(DateTime? date) {
    final value = (date ?? DateTime.now()).toLocal();
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/${value.year}';
  }

  Future<void> _verifyAutopay(PaymentSuccessResponse response) async {
    final autopayId = _pendingAutopayId!;
    // Prefer the subscription id from create-autopay; Razorpay's orderId
    // field is for one-time orders and can break HMAC verification.
    final subscriptionId = _pendingSubscriptionId ?? response.orderId ?? '';
    final paymentId = response.paymentId ?? '';
    final signature = response.signature ?? '';
    if (subscriptionId.isEmpty || paymentId.isEmpty || signature.isEmpty) {
      _pendingAutopayId = null;
      _pendingSubscriptionId = null;
      if (mounted) setState(() => _isProcessing = false);
      unawaited(_releaseAbandonedAutopay(autopayId));
      _showError('Autopay setup was not completed.');
      return;
    }

    final verify = await ref
        .read(autopayApiProvider)
        .verifyAutopay(
          autopayId: autopayId,
          razorpaySubscriptionId: subscriptionId,
          razorpayPaymentId: paymentId,
          razorpaySignature: signature,
        );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (!verify.success) {
      _showError(verify.message ?? 'Autopay verification failed');
      return;
    }

    ref.invalidate(myAutopaysProvider);
    // Autopay charges create Donation docs — refresh history so they appear.
    ref.invalidate(donationHistoryProvider);
    Navigator.of(context).pop();

    final now = DateTime.now();
    NavigationService().pushNamed(
      'DonationSuccess',
      arguments: {
        'isAutopay': true,
        'amount': _amountController.text.trim(),
        'period': _selectedPeriod,
        'message': _messageController.text.trim().isEmpty
            ? null
            : _messageController.text.trim(),
        'campaignName': widget.categoryTitle,
        'transactionId': response.paymentId ?? autopayId,
        'date':
            '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}',
      },
    );
  }

  void _onPaymentError(PaymentFailureResponse response) {
    log(
      'Payment failed/cancelled: code=${response.code} msg=${response.message}',
      name: 'DonationSheet',
    );
    // Pending donation stays `pending` server-side — jamiat verify-payment
    // requires a valid Razorpay HMAC, so we cannot mark failed from the client.
    final abandonedAutopayId = _pendingAutopayId;
    _pendingDonationId = null;
    _pendingRazorpayOrderId = null;
    _pendingAutopayId = null;
    _pendingSubscriptionId = null;
    if (abandonedAutopayId != null) {
      unawaited(_releaseAbandonedAutopay(abandonedAutopayId));
    }

    if (!mounted) return;
    setState(() => _isProcessing = false);
    _showError(response.message ?? 'Payment cancelled or failed');
  }

  String _formatPreset(int amount) {
    final raw = amount.toString();
    final buf = StringBuffer();
    final len = raw.length;
    for (var i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) buf.write(',');
      buf.write(raw[i]);
    }
    return '₹$buf';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final campaignId = widget.campaignId;
    final campaign = (campaignId != null && campaignId.isNotEmpty)
        ? ref.watch(campaignDetailProvider(campaignId)).value
        : null;

    final title = campaign?.title ?? widget.categoryTitle;
    final categoryLabel =
        widget.categoryLabel ??
        (campaign != null ? CategoryMapper.toUi(campaign.category) : null);
    final raised = campaign?.collectedAmount ?? widget.raised;
    final goal = campaign?.targetAmount ?? widget.goal;
    final hasTarget = goal != null && goal > 0;
    final progress = hasTarget
        ? (raised ?? 0) / goal
        : 0.0;
    final clampedProgress = progress.clamp(0.0, 1.0);

    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(kCardRadiusMd),
      borderSide: const BorderSide(color: kCardBorder, width: 1),
    );
    final fieldFocused = OutlineInputBorder(
      borderRadius: BorderRadius.circular(kCardRadiusMd),
      borderSide: const BorderSide(color: kPrimaryColor, width: 1.5),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: PopScope(
        canPop: !_isProcessing,
        child: Container(
        decoration: const BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(
          kScreenPaddingH,
          12,
          kScreenPaddingH,
          24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: kStrokeColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (categoryLabel != null && categoryLabel.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: kChipGreyBg,
                      borderRadius: BorderRadius.circular(kCardRadiusXs),
                    ),
                    child: Text(
                      categoryLabel,
                      style: kCaption10M.copyWith(color: kTextColor),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (hasTarget) ...[
                Text(
                  widget.isAutopay ? 'Set up Autopay' : title,
                  style: kSectionTitle19SB,
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(1),
                  child: LinearProgressIndicator(
                    value: clampedProgress.toDouble(),
                    minHeight: 4,
                    backgroundColor: kGreyLight.withValues(alpha: 0.45),
                    color: kPrimaryColor,
                  ),
                ),
                const SizedBox(height: 10),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: formatRupee(raised ?? 0),
                        style: kBodyTitleSB,
                      ),
                      TextSpan(
                        text: ' / of ${formatRupee(goal)}',
                        style: kCaption12R.copyWith(
                          color: kSecondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (campaignId != null && campaignId.isNotEmpty) ...[
                Text(
                  widget.isAutopay ? 'Set up Autopay' : title,
                  style: kSectionTitle19SB,
                ),
              ] else ...[
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: widget.iconBgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(
                          widget.icon,
                          color: widget.iconColor,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        widget.isAutopay ? 'Set up Autopay' : title,
                        style: kSectionTitle19SB,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              const Divider(color: kLineGrey, height: 1),
              const SizedBox(height: 20),
              Text('Select amount', style: kBodyTitleSB),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _presetAmounts.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 16,
                  childAspectRatio: 2.1,
                ),
                itemBuilder: (context, index) {
                  final amount = _presetAmounts[index];
                  final isSelected = _selectedPresetIndex == index;
                  final isPopular = amount == 500;

                  final chipWidget = Container(
                    decoration: BoxDecoration(
                      color: isSelected ? kLightGreen : kChipGreyBg,
                      border: Border.all(
                        color: isSelected ? kPrimaryColor : Colors.transparent,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(kCardRadiusMd),
                    ),
                    child: InkWell(
                      onTap: () => _onPresetSelected(index, amount),
                      borderRadius: BorderRadius.circular(kCardRadiusMd),
                      child: Center(
                        child: Text(
                          _formatPreset(amount),
                          style: kStyle(
                            isSelected ? kSemiBold : kMedium,
                            15,
                            color: isSelected ? kPrimaryColor : kTextColor,
                          ),
                        ),
                      ),
                    ),
                  );

                  if (isPopular) {
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(child: chipWidget),
                        Positioned(
                          top: -8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: kSecondaryColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Popular',
                              style: kCaption8SB.copyWith(color: kWhite),
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  return chipWidget;
                },
              ),
              const SizedBox(height: 20),
              Text(
                'or enter custom amount',
                style: kCaption12R.copyWith(color: kMutedText),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: _onCustomAmountChanged,
                style: kBodyTitleM,
                decoration: InputDecoration(
                  hintText: '₹ Enter amount',
                  hintStyle: kBodyTitleR.copyWith(color: kSecondaryTextColor),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 16,
                  ),
                  border: fieldBorder,
                  enabledBorder: fieldBorder,
                  focusedBorder: fieldFocused,
                ),
              ),
              if (widget.isAutopay) ...[
                const SizedBox(height: 20),
                Text('Billing period', style: kBodyTitleSB),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _periods.map((period) {
                    final selected = _selectedPeriod == period;
                    final label = switch (period) {
                      'weekly' => 'Weekly',
                      'monthly' => 'Monthly',
                      'yearly' => 'Yearly',
                      _ => period[0].toUpperCase() + period.substring(1),
                    };
                    return ChoiceChip(
                      label: Text(label),
                      selected: selected,
                      onSelected: (_) {
                        HapticHelper.impact(HapticImpact.light);
                        setState(() => _selectedPeriod = period);
                      },
                      selectedColor: kLightGreen,
                      backgroundColor: kChipGreyBg,
                      labelStyle: kCaption12M.copyWith(
                        color: selected ? kPrimaryColor : kTextColor,
                      ),
                      side: BorderSide(
                        color: selected ? kPrimaryColor : kCardBorder,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(kCardRadiusSm),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 20),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'Add a message ', style: kBodyTitleSB),
                    TextSpan(
                      text: '(optional)',
                      style: kCaption12R.copyWith(color: kSecondaryTextColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _messageController,
                maxLines: 3,
                minLines: 3,
                style: kBodyTitleM,
                decoration: InputDecoration(
                  hintText: 'Enter message',
                  hintStyle: kBodyTitleR.copyWith(color: kSecondaryTextColor),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  border: fieldBorder,
                  enabledBorder: fieldBorder,
                  focusedBorder: fieldFocused,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: (_hasValidAmount && !_isProcessing)
                      ? _handlePayment
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    disabledBackgroundColor: kChipGreyBg,
                    foregroundColor: kWhite,
                    disabledForegroundColor: kMutedText,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(kCardRadiusSm),
                    ),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(kWhite),
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          widget.isAutopay
                              ? 'Continue to Autopay'
                              : 'Continue to payment',
                          style: kButtonLabelSB.copyWith(
                            color: _hasValidAmount ? kWhite : kMutedText,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
