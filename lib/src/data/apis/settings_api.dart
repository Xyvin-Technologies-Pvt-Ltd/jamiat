import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamiat/src/data/models/app_version_model.dart';
import 'package:jamiat/src/data/providers/api_provider.dart';

/// Public settings (API key only) — store version gate + feature flags.
class SettingsApi {
  SettingsApi(this._api);

  final ApiProvider _api;

  /// Returns parsed platform settings, or `null` on network / parse failure
  /// so splash can stay put and show Retry.
  Future<AppVersionResponse?> getAppVersion() async {
    try {
      log('GET /settings (requireAuth: false)', name: 'SettingsApi');
      final response = await _api.get('/settings');
      if (!response.success || response.data == null) {
        log(
          'Settings fetch failed: ${response.message} (${response.statusCode})',
          name: 'SettingsApi',
        );
        return null;
      }

      final parsed = AppVersionResponse.fromJson(response.data!);
      log(
        'Settings OK — version=${parsed.version} force=${parsed.force} '
        'applink=${parsed.applink.isNotEmpty}',
        name: 'SettingsApi',
      );
      return parsed;
    } catch (e, st) {
      log('Settings fetch error: $e', name: 'SettingsApi', stackTrace: st);
      return null;
    }
  }
}

final settingsApiProvider = Provider<SettingsApi>(
  (ref) => SettingsApi(ref.watch(apiProviderProvider)),
);
