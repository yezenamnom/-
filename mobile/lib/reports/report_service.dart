import 'dart:convert';

import 'package:http/http.dart' as http;

enum ReportCategory { siteBroken, blockingIssue, videoIssue, adsIssue, other }

const _categoryKeys = {
  ReportCategory.siteBroken: 'site_broken',
  ReportCategory.blockingIssue: 'blocking_issue',
  ReportCategory.videoIssue: 'video_issue',
  ReportCategory.adsIssue: 'ads_issue',
  ReportCategory.other: 'other',
};

class UserReport {
  const UserReport({
    required this.category,
    required this.message,
    required this.appVersion,
    required this.platform,
    required this.locale,
    this.siteHost,
  });

  final ReportCategory category;
  final String message;
  final String appVersion;
  final String platform;
  final String locale;

  /// Bare host name only (never a path, query, cookies or page content),
  /// included only if the user leaves the checkbox on.
  final String? siteHost;

  /// Exactly what is sent; the UI shows this to the user before sending.
  Map<String, Object?> toJson() => {
        'category': _categoryKeys[category],
        'message': redactSensitive(message.trim()),
        'appVersion': appVersion,
        'platform': platform,
        'locale': locale,
        if (siteHost != null && siteHost!.isNotEmpty) 'siteHost': siteHost,
      };
}

/// Removes obvious secrets a user might paste into a report: URLs are
/// reduced to their host, e-mail addresses and long tokens are masked.
String redactSensitive(String text) {
  var t = text.replaceAllMapped(
    RegExp(r'https?://([^/\s?#]+)[^\s]*', caseSensitive: false),
    (m) => m.group(1)!,
  );
  t = t.replaceAll(
      RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'), '[email]');
  t = t.replaceAll(RegExp(r'\b[A-Za-z0-9_\-]{32,}\b'), '[token]');
  t = t.replaceAll(RegExp(r'\b\d{12,19}\b'), '[number]');
  return t.length > 2000 ? t.substring(0, 2000) : t;
}

class ReportService {
  ReportService({required String baseUrl, http.Client? client})
      : _baseUrl = baseUrl,
        _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  bool get available => _baseUrl.isNotEmpty;

  Future<bool> send(UserReport report) async {
    if (!available) return false;
    try {
      final res = await _client
          .post(
            Uri.parse(_baseUrl).replace(path: '/api/v1/reports'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode(report.toJson()),
          )
          .timeout(const Duration(seconds: 15));
      return res.statusCode == 201;
    } on Exception {
      return false;
    }
  }
}
