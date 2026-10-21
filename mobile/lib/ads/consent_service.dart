import 'dart:async';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Consent gate for ads, backed by Google's User Messaging Platform (UMP).
/// The app never invents consent: [canRequestAds] is whatever UMP reports.
abstract class ConsentGate extends ChangeNotifier {
  bool get canRequestAds;
  bool get privacyOptionsRequired;
  Future<void> gather();
  Future<void> showPrivacyOptions();
}

class UmpConsentGate extends ConsentGate {
  bool _canRequestAds = false;
  bool _privacyOptionsRequired = false;

  @override
  bool get canRequestAds => _canRequestAds;
  @override
  bool get privacyOptionsRequired => _privacyOptionsRequired;

  /// Refreshes consent info on every launch, shows the form if UMP says so,
  /// then (iOS) asks for App Tracking Transparency separately. Browsing is
  /// never blocked by any of this.
  @override
  Future<void> gather() async {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
        if (!done.isCompleted) done.complete();
      },
      (_) {
        // Network/config failure: keep the previous session's state.
        if (!done.isCompleted) done.complete();
      },
    );
    await done.future.timeout(const Duration(seconds: 30), onTimeout: () {});
    await _refresh();
    if (Platform.isIOS && _canRequestAds) {
      // ATT is separate from UMP; declining only means non-personalised
      // ads. The browser works the same either way.
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    }
  }

  Future<void> _refresh() async {
    _canRequestAds = await ConsentInformation.instance.canRequestAds();
    _privacyOptionsRequired =
        await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
            PrivacyOptionsRequirementStatus.required;
    notifyListeners();
  }

  @override
  Future<void> showPrivacyOptions() async {
    final done = Completer<void>();
    await ConsentForm.showPrivacyOptionsForm((_) {
      if (!done.isCompleted) done.complete();
    });
    await done.future.timeout(const Duration(minutes: 5), onTimeout: () {});
    await _refresh();
  }
}

/// Used when ads are compiled out or in tests: never allows requests.
class NoConsentGate extends ConsentGate {
  @override
  bool get canRequestAds => false;
  @override
  bool get privacyOptionsRequired => false;
  @override
  Future<void> gather() async {}
  @override
  Future<void> showPrivacyOptions() async {}
}
