class CampaignModel {
  const CampaignModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.collectedAmount,
    required this.targetAmount,
    required this.progressPercent,
    required this.isBookmarked,
    this.coverImage,
    this.organizedBy,
    this.remainingDays,
    this.remainingAmount,
    this.totalDonorCount,
    this.isCompleted,
    this.status,
    this.targetDate,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final num collectedAmount;
  final num targetAmount;
  final int progressPercent;
  final bool isBookmarked;
  final String? coverImage;
  final String? organizedBy;
  final int? remainingDays;
  final num? remainingAmount;
  final int? totalDonorCount;
  final bool? isCompleted;
  final String? status;
  final DateTime? targetDate;

  /// Campaigns may be goal-based or open-ended.
  bool get hasTargetAmount => targetAmount > 0;

  /// Only show countdown when the API provided a remaining-days value (> 0).
  bool get hasDaysRemaining => remainingDays != null && remainingDays! > 0;

  /// True when a target date was set and the campaign window has ended.
  bool get isEndedByTargetDate => remainingDays != null && remainingDays! <= 0;

  factory CampaignModel.fromJson(Map<String, dynamic> json) {
    return CampaignModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      category: (json['category'] ?? 'General Campaign').toString(),
      collectedAmount: json['collected_amount'] ?? 0,
      targetAmount: json['target_amount'] ?? 0,
      progressPercent: (json['progress_percent'] as num?)?.toInt() ?? 0,
      isBookmarked: json['is_bookmarked'] == true,
      coverImage: json['cover_image']?.toString(),
      organizedBy: json['organized_by']?.toString(),
      remainingDays: (json['remaining_days'] as num?)?.toInt(),
      remainingAmount: json['remaining_amount'] as num?,
      totalDonorCount: (json['total_donor_count'] as num?)?.toInt(),
      isCompleted: json['is_completed'] == true,
      status: json['status']?.toString(),
      targetDate: json['target_date'] != null
          ? DateTime.tryParse(json['target_date'].toString())?.toLocal()
          : null,
    );
  }
}

class CampaignMobileStats {
  const CampaignMobileStats({
    required this.activeCampaigns,
    required this.raisedTotal,
    required this.totalDonors,
    required this.endingSoonCount,
  });

  final int activeCampaigns;
  final num raisedTotal;
  final int totalDonors;
  final int endingSoonCount;

  factory CampaignMobileStats.fromJson(Map<String, dynamic> json) {
    return CampaignMobileStats(
      activeCampaigns: (json['active_campaigns'] as num?)?.toInt() ?? 0,
      raisedTotal: json['raised_total'] ?? 0,
      totalDonors: (json['total_donors'] as num?)?.toInt() ?? 0,
      endingSoonCount: (json['ending_soon_count'] as num?)?.toInt() ?? 0,
    );
  }
}
