import 'dart:io';

/// Platform-specific store-update + feature flags from GET /settings.
///
/// Server `version` is the integer build number (Android versionCode /
/// iOS CFBundleVersion), matching the `+BUILD` suffix in pubspec.yaml —
/// not the marketing version string "1.2.3".
class AppVersionResponse {
  const AppVersionResponse({
    required this.version,
    required this.force,
    required this.applink,
    required this.updateMessage,
    this.razorpayEnabled,
  });

  final int version;
  final bool force;
  final String applink;
  final String updateMessage;
  final bool? razorpayEnabled;

  /// Parses the full API envelope: `{ data: { application: { customer: … } } }`.
  factory AppVersionResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final application = data is Map ? data['application'] : null;
    final customer = application is Map ? application['customer'] : null;
    if (customer is! Map) {
      throw const FormatException('Settings missing application.customer');
    }

    final platformKey = Platform.isIOS ? 'ios' : 'android';
    final platform = customer[platformKey];
    if (platform is! Map) {
      throw FormatException('Settings missing application.customer.$platformKey');
    }

    final versionRaw = platform['version'];
    final version = versionRaw is int
        ? versionRaw
        : int.tryParse(versionRaw?.toString() ?? '') ?? 0;

    final message = platform['updateMessage']?.toString().trim() ?? '';

    return AppVersionResponse(
      version: version,
      force: platform['force'] == true,
      applink: platform['applink']?.toString().trim() ?? '',
      updateMessage: message.isNotEmpty ? message : 'Update Available',
      razorpayEnabled: platform['razorpay_enabled'] is bool
          ? platform['razorpay_enabled'] as bool
          : null,
    );
  }
}
