class AutopayModel {
  const AutopayModel({
    required this.id,
    required this.amount,
    required this.period,
    required this.status,
    this.campaignId,
    this.campaignName,
    this.nextPayment,
    this.lastPayment,
    this.totalDonated,
    this.paymentsDone,
    this.createdAt,
  });

  final String id;
  final num amount;
  final String period;
  final String status;
  final String? campaignId;
  final String? campaignName;
  final DateTime? nextPayment;
  final DateTime? lastPayment;
  final num? totalDonated;
  final int? paymentsDone;
  final DateTime? createdAt;

  factory AutopayModel.fromJson(Map<String, dynamic> json) {
    final campaign = json['campaign'];
    String? campaignId;
    String? campaignName;
    if (campaign is Map) {
      campaignId = (campaign['_id'] ?? campaign['id'])?.toString();
      campaignName = campaign['title']?.toString();
    } else if (campaign != null) {
      campaignId = campaign.toString();
    }

    campaignId ??= json['campaign_id']?.toString();
    campaignName ??=
        json['campaign_name']?.toString() ?? json['campaign_title']?.toString();

    return AutopayModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      amount: json['amount'] ?? 0,
      period: (json['period'] ?? 'monthly').toString(),
      status: (json['status'] ?? '').toString(),
      campaignId: campaignId,
      campaignName: campaignName,
      nextPayment: json['next_payment'] != null
          ? DateTime.tryParse(json['next_payment'].toString())?.toLocal()
          : null,
      lastPayment: json['last_payment'] != null
          ? DateTime.tryParse(json['last_payment'].toString())?.toLocal()
          : null,
      totalDonated: json['total_donated'] as num?,
      paymentsDone: (json['payments_done'] as num?)?.toInt(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())?.toLocal()
          : (json['created_at'] != null
                ? DateTime.tryParse(json['created_at'].toString())?.toLocal()
                : null),
    );
  }
}

class AutopayCreateResult {
  const AutopayCreateResult({
    required this.autopayId,
    required this.razorpaySubscriptionId,
    required this.razorpayKeyId,
  });

  final String autopayId;
  final String razorpaySubscriptionId;
  final String razorpayKeyId;

  factory AutopayCreateResult.fromJson(Map<String, dynamic> json) {
    final autopay = json['autopay'];
    final autopayId = autopay is Map
        ? (autopay['_id'] ?? autopay['id'] ?? '').toString()
        : '';
    return AutopayCreateResult(
      autopayId: autopayId,
      razorpaySubscriptionId:
          (json['razorpay_subscription_id'] ?? json['subscription_id'] ?? '')
              .toString(),
      razorpayKeyId: (json['razorpay_key_id'] ?? '').toString(),
    );
  }
}

class AutopayTransactionModel {
  const AutopayTransactionModel({
    required this.id,
    required this.amount,
    required this.status,
    this.createdAt,
  });

  final String id;
  final num amount;
  final String status;
  final DateTime? createdAt;

  factory AutopayTransactionModel.fromJson(Map<String, dynamic> json) {
    return AutopayTransactionModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      amount: json['amount'] ?? 0,
      status: (json['status'] ?? '').toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())?.toLocal()
          : (json['created_at'] != null
                ? DateTime.tryParse(json['created_at'].toString())?.toLocal()
                : null),
    );
  }
}

class AutopayHistoryResult {
  const AutopayHistoryResult({
    required this.transactions,
    this.nextPayment,
    this.lastPayment,
    this.period,
    this.amount,
    this.status,
  });

  final List<AutopayTransactionModel> transactions;
  final DateTime? nextPayment;
  final DateTime? lastPayment;
  final String? period;
  final num? amount;
  final String? status;

  factory AutopayHistoryResult.fromJson(Map<String, dynamic> json) {
    final mandate = json['mandate'];
    Map<String, dynamic>? mandateMap;
    if (mandate is Map) {
      mandateMap = Map<String, dynamic>.from(mandate);
    }

    final txs = (json['transactions'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (e) => AutopayTransactionModel.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();

    return AutopayHistoryResult(
      transactions: txs,
      nextPayment: mandateMap?['next_payment'] != null
          ? DateTime.tryParse(mandateMap!['next_payment'].toString())?.toLocal()
          : null,
      lastPayment: mandateMap?['last_payment'] != null
          ? DateTime.tryParse(mandateMap!['last_payment'].toString())?.toLocal()
          : null,
      period: mandateMap?['period']?.toString(),
      amount: mandateMap?['amount'] as num?,
      status: mandateMap?['status']?.toString(),
    );
  }
}
