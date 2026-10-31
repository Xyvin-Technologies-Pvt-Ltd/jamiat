class DonationModel {
  DonationModel({
    required this.id,
    required this.amount,
    required this.status,
    this.campaignId,
    this.campaignName,
    this.coverImage,
    this.message,
    this.paidAt,
    this.createdAt,
    this.transactionId,
    this.hasAutopay = false,
    this.receiptUrl,
  });

  final String id;
  final num amount;
  final String status;
  final String? campaignId;
  final String? campaignName;
  final String? coverImage;
  final String? message;
  final DateTime? paidAt;
  final DateTime? createdAt;
  final String? transactionId;
  final bool hasAutopay;
  final String? receiptUrl;

  DateTime? get displayDate => paidAt ?? createdAt;

  static bool _parseHasAutopay(dynamic value) {
    if (value == null || value == false) return false;
    if (value is bool) return value;
    // ObjectId string / nested autopay object from history API.
    if (value is Map) return value.isNotEmpty;
    final text = value.toString().trim();
    if (text.isEmpty || text == 'null' || text == 'undefined' || text == 'false') {
      return false;
    }
    return true;
  }

  static String? _nonEmptyString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty || text == 'null' || text == 'undefined') return null;
    return text;
  }

  factory DonationModel.fromJson(Map<String, dynamic> json) {
    final campaign = json['campaign'];
    String? campaignId;
    String? campaignName;
    String? coverImage;
    if (campaign is Map) {
      campaignId = (campaign['_id'] ?? campaign['id'])?.toString();
      campaignName = campaign['title']?.toString();
      coverImage = _nonEmptyString(
        campaign['cover_image'] ?? campaign['campaign_image'],
      );
    } else if (campaign != null) {
      campaignId = campaign.toString();
    }

    return DonationModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      amount: json['amount'] ?? 0,
      status: (json['status'] ?? '').toString(),
      campaignId: campaignId ?? json['campaign_id']?.toString(),
      campaignName:
          campaignName ??
          json['campaign_name']?.toString() ??
          json['campaign_title']?.toString(),
      coverImage:
          _nonEmptyString(json['cover_image']) ??
          _nonEmptyString(json['campaign_image']) ??
          coverImage,
      message: json['message']?.toString(),
      paidAt: json['paid_at'] != null
          ? DateTime.tryParse(json['paid_at'].toString())
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      transactionId:
          (json['gateway_payment_id'] ??
                  json['payment_id'] ??
                  json['transaction_id'])
              ?.toString(),
      hasAutopay: _parseHasAutopay(json['autopay']),
      receiptUrl: _nonEmptyString(json['receipt_url'] ?? json['receipt']),
    );
  }
}

class DonationHistorySummary {
  const DonationHistorySummary({
    required this.totalDonated,
    required this.participatedCampaigns,
    required this.totalPayments,
  });

  final num totalDonated;
  final int participatedCampaigns;
  final int totalPayments;

  factory DonationHistorySummary.fromJson(
    Map<String, dynamic> json, {
    int totalPayments = 0,
  }) {
    return DonationHistorySummary(
      totalDonated: json['total_donated'] ?? 0,
      participatedCampaigns:
          (json['participated_campaigns'] as num?)?.toInt() ?? 0,
      totalPayments: (json['total_payments'] as num?)?.toInt() ?? totalPayments,
    );
  }
}

class DonationCreateResult {
  const DonationCreateResult({
    required this.donationId,
    required this.razorpayOrderId,
    required this.razorpayKeyId,
    required this.amount,
    required this.currency,
  });

  final String donationId;
  final String razorpayOrderId;
  final String razorpayKeyId;
  final num amount;
  final String currency;

  factory DonationCreateResult.fromJson(Map<String, dynamic> json) {
    final donation = json['donation'];
    final donationId = donation is Map
        ? (donation['_id'] ?? donation['id'] ?? '').toString()
        : '';
    return DonationCreateResult(
      donationId: donationId,
      razorpayOrderId: (json['razorpay_order_id'] ?? '').toString(),
      razorpayKeyId: (json['razorpay_key_id'] ?? '').toString(),
      amount: json['amount'] ?? 0,
      currency: (json['currency'] ?? 'INR').toString(),
    );
  }
}
