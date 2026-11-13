import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jamiat/src/data/apis/settings_api.dart';
import 'package:jamiat/src/data/models/app_version_model.dart';
import 'package:jamiat/src/data/services/secure_storage_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

enum VersionGateOutcome {
  /// Server build ≤ local build — continue auth / bootstrap.
  upToDate,

  /// Server build > local — show update UI (force or optional).
  updateRequired,

  /// Settings call failed — stay on splash with Retry.
  serverError,
}

class VersionGateResult {
  const VersionGateResult({
    required this.outcome,
    this.settings,
    this.localBuildNumber = 0,
  });

  final VersionGateOutcome outcome;
  final AppVersionResponse? settings;
  final int localBuildNumber;

  bool get isForce => settings?.force == true;
  String get updateMessage =>
      settings?.updateMessage ?? 'Update Available';
  String get applink => settings?.applink ?? '';
}

class VersionCheckService {
  VersionCheckService({
    required SettingsApi settingsApi,
    required SecureStorageService secureStorage,
  }) : _settingsApi = settingsApi,
       _secureStorage = secureStorage;

  final SettingsApi _settingsApi;
  final SecureStorageService _secureStorage;

  /// Fetches settings, persists feature flags, compares integer build numbers.
  Future<VersionGateResult> check() async {
    log('Version check starting', name: 'VersionCheckService');
    final settings = await _settingsApi.getAppVersion();
    if (settings == null) {
      log(
        'Version check blocked — settings unavailable',
        name: 'VersionCheckService',
      );
      return const VersionGateResult(outcome: VersionGateOutcome.serverError);
    }

    if (settings.razorpayEnabled != null) {
      await _secureStorage.saveRazorpayEnabled(settings.razorpayEnabled!);
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final localBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
    final serverVersion = settings.version;

    log(
      'Version compare — local=$localBuild server=$serverVersion '
      'force=${settings.force}',
      name: 'VersionCheckService',
    );

    if (serverVersion > localBuild) {
      log(
        'Update required — navigation blocked',
        name: 'VersionCheckService',
      );
      return VersionGateResult(
        outcome: VersionGateOutcome.updateRequired,
        settings: settings,
        localBuildNumber: localBuild,
      );
    }

    log('Up to date — navigation allowed', name: 'VersionCheckService');
    return VersionGateResult(
      outcome: VersionGateOutcome.upToDate,
      settings: settings,
      localBuildNumber: localBuild,
    );
  }
}

final versionCheckServiceProvider = Provider<VersionCheckService>((ref) {
  return VersionCheckService(
    settingsApi: ref.watch(settingsApiProvider),
    secureStorage: ref.watch(secureStorageServiceProvider),
  );
});
