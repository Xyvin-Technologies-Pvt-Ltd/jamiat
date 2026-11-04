import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamiat/src/data/apis/donation_api.dart';
import 'package:jamiat/src/data/constants/color_constants.dart';
import 'package:jamiat/src/data/constants/style_constants.dart';
import 'package:jamiat/src/data/services/api_logger.dart';
import 'package:jamiat/src/data/services/haptic_helper.dart';
import 'package:jamiat/src/data/services/navigation_services.dart';
import 'package:jamiat/src/interfaces/components/primarybutton.dart';
import 'package:url_launcher/url_launcher.dart';

class DonationSuccessScreen extends ConsumerStatefulWidget {
  final bool isAutopay;
  final String amount;
  final String period;
  final String transactionId;
  final String date;
  final String campaignName;
  final String? message;
  final String? donationId;

  const DonationSuccessScreen({
    super.key,
    required this.isAutopay,
    required this.amount,
    this.period = 'monthly',
    this.transactionId = 'TR12451BHGF',
    this.date = '20/06/2026',
    this.campaignName = 'Medical aid for patient',
    this.message,
    this.donationId,
  });

  @override
  ConsumerState<DonationSuccessScreen> createState() =>
      _DonationSuccessScreenState();
}

class _DonationSuccessScreenState extends ConsumerState<DonationSuccessScreen> {
  bool _isDownloading = false;
  Map<String, dynamic>? _receipt;

  @override
  void initState() {
    super.initState();
    // Avoid reading providers during initState; wait for first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadReceipt();
    });
  }

  Future<void> _loadReceipt() async {
    final donationId = widget.donationId?.trim();
    if (donationId == null || donationId.isEmpty) {
      ApiLogger.info(
        'Receipt GET skipped: donationId missing on DonationSuccessScreen',
      );
      return;
    }

    ApiLogger.info('Loading donation receipt for id=$donationId');
    final response = await ref.read(donationApiProvider).getReceipt(donationId);
    if (!mounted) return;
    if (!response.success || response.data == null) {
      ApiLogger.info(
        'Receipt GET failed: ${response.message ?? 'unknown error'}',
      );
      return;
    }
    setState(() => _receipt = response.data);
  }

  String _receiptValue(String key) => (_receipt?[key] ?? '').toString().trim();

  String get _amount {
    final value = _receipt?['amount'];
    return value == null ? widget.amount.trim() : value.toString().trim();
  }

  String get _displayAmount {
    final amount = _amount;
    if (amount.isEmpty) return '₹0';
    return amount.startsWith('₹') ? amount : '₹$amount';
  }

  String get _campaignName {
    return _receiptValue('campaign_title').isNotEmpty
        ? _receiptValue('campaign_title')
        : widget.campaignName;
  }

  String get _transactionId {
    return _receiptValue('transaction_id').isNotEmpty
        ? _receiptValue('transaction_id')
        : widget.transactionId;
  }

  String get _message {
    return _receiptValue('message').isNotEmpty
        ? _receiptValue('message')
        : widget.message?.trim() ?? '';
  }

  String get _date {
    final rawDate = _receiptValue('paid_at');
    final parsedDate = DateTime.tryParse(rawDate)?.toLocal();
    if (parsedDate == null) return widget.date;
    return '${parsedDate.day.toString().padLeft(2, '0')}/'
        '${parsedDate.month.toString().padLeft(2, '0')}/${parsedDate.year}';
  }

  String get _subtitle {
    return 'Your donation of $_displayAmount to $_campaignName '
        'has been received. May it be a sadaqah for you.';
  }

  Widget _circleButton({required Widget child, required VoidCallback onTap}) {
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

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: kCaption14R.copyWith(color: kTextColor)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: kCaption14B.copyWith(color: kTextColor),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(kCardRadiusMd),
        border: Border.all(color: kCardBorder),
      ),
      child: child,
    );
  }

  void _goBackToCampaign() {
    HapticHelper.impact(HapticImpact.medium);
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }
    NavigationService().pushNamedAndRemoveUntil('navBar');
  }

  Future<void> _downloadReceipt() async {
    if (_isDownloading) return;
    HapticHelper.impact(HapticImpact.light);

    final donationId = widget.donationId?.trim();
    if (donationId == null || donationId.isEmpty) {
      ApiLogger.info(
        'Receipt download skipped: donationId missing on DonationSuccessScreen',
      );
      _showMessage('Receipt is not available yet.');
      return;
    }

    ApiLogger.info('Downloading donation receipt for id=$donationId');
    setState(() => _isDownloading = true);
    try {
      final response = await ref
          .read(donationApiProvider)
          .getReceipt(donationId);
      if (!mounted) return;

      if (!response.success || response.data == null) {
        _showMessage(response.message ?? 'Unable to download receipt.');
        return;
      }

      final data = response.data!;
      if (mounted) setState(() => _receipt = data);
      final rawUrl =
          (data['receipt_url'] ?? data['url'] ?? data['receipt'] ?? '')
              .toString()
              .trim();

      if (rawUrl.isEmpty) {
        _showMessage('Receipt is not available yet.');
        return;
      }

      final uri = Uri.tryParse(rawUrl);
      if (uri == null) {
        _showMessage('Invalid receipt link.');
        return;
      }

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        _showMessage('Unable to open receipt.');
      }
    } catch (e) {
      if (mounted) {
        _showMessage(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasMessage = _message.isNotEmpty;

    return Scaffold(
      backgroundColor: kWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            kScreenPaddingH,
            16,
            kScreenPaddingH,
            24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _circleButton(
                onTap: () {
                  HapticHelper.impact(HapticImpact.light);
                  _goBackToCampaign();
                },
                child: const Icon(
                  Icons.arrow_back,
                  color: kTextColor,
                  size: 20,
                ),
              ),
              const SizedBox(height: 28),
              Center(
                child: Column(
                  children: [
                    Image.asset(
                      'assets/pngs/success tick.png',
                      width: 88,
                      height: 88,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 20),
                    Text('JazakAllah Khair!', style: kSectionTitle19SB),
                    const SizedBox(height: 10),
                    Text(
                      _subtitle,
                      textAlign: TextAlign.center,
                      style: kCaption13R.copyWith(
                        color: kSecondaryTextColor,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const Divider(color: kLineGrey, height: 1, thickness: 1),
              const SizedBox(height: 24),
              Text('Donation Receipt', style: kBodyTitleSB),
              const SizedBox(height: 12),
              _sectionCard(
                child: Column(
                  children: [
                    _buildRow('Date', _date),
                    _buildRow('Campaign', _campaignName),
                    _buildRow('Transaction ID', _transactionId),
                    if (widget.isAutopay) _buildRow('Period', widget.period),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Divider(color: kLineGrey, height: 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Amount Paid', style: kBodyTitleSB),
                          Text(
                            _displayAmount,
                            style: kBodyTitleSB.copyWith(color: kPrimaryColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (hasMessage) ...[
                const SizedBox(height: 24),
                Text('Your Message', style: kBodyTitleSB),
                const SizedBox(height: 12),
                _sectionCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      _message,
                      style: kCaption14R.copyWith(
                        color: kTextColor,
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              primaryButton(
                label: 'Back to campaign',
                onPressed: _goBackToCampaign,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 66,
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isDownloading ? null : _downloadReceipt,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kTextColor,
                    side: const BorderSide(color: kStrokeColor, width: 1.25),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(kCardRadiusSm),
                    ),
                  ),
                  child: _isDownloading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: kPrimaryColor,
                          ),
                        )
                      : Text(
                          'Download Receipt',
                          style: kButtonLabelSB.copyWith(color: kTextColor),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
