// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get about => 'About';

  @override
  String get adFreeActive => 'Ad-free active';

  @override
  String get adLabel => 'Ad';

  @override
  String get adPrivacyOptions => 'Ad privacy choices';

  @override
  String get add => 'Add';

  @override
  String get addShortcut => 'Add shortcut';

  @override
  String get address => 'Address';

  @override
  String get addressBar => 'Address bar';

  @override
  String get adsAndSubscription => 'Ads & subscription';

  @override
  String get allowAlways => 'Always allow';

  @override
  String get allowOnce => 'Allow this time';

  @override
  String get allowed => 'Allowed';

  @override
  String get appAdsExplained => 'About ads in this app';

  @override
  String get appAdsExplainedBody =>
      'The app shows its own ads in its screens (never on websites or over videos). Content blocking on websites is separate and does not affect these ads.';

  @override
  String get appName => 'Vela';

  @override
  String get autoPip => 'Picture-in-picture on leave';

  @override
  String get autoPipHint => 'When a video is fullscreen and you leave the app';

  @override
  String get back => 'Back';

  @override
  String get backgroundAudio => 'Keep audio playing in background';

  @override
  String get backgroundAudioHint =>
      'Only where the system and the website allow it. Some sites pause playback themselves.';

  @override
  String get blockAdsTrackers => 'Block ads & trackers on websites';

  @override
  String get blockAdsTrackersHint =>
      'Works only inside this browser. Coverage differs between Android and iOS and some sites may break.';

  @override
  String get blockOnThisSite => 'Blocking on this site';

  @override
  String get blockOnThisSiteHint =>
      'Turn off if the site does not work correctly';

  @override
  String get blockPopups => 'Block pop-ups';

  @override
  String get blockingExceptions => 'Sites without blocking';

  @override
  String get blockingExceptionsEmpty =>
      'No exceptions yet. Use the shield in a site\'s info panel to add one.';

  @override
  String get blockingGloballyOff => 'Blocking is turned off in settings';

  @override
  String blocklistVersion(int version) {
    return 'Block list version $version';
  }

  @override
  String get bookmarkAdded => 'Bookmark added';

  @override
  String get bookmarkRemoved => 'Bookmark removed';

  @override
  String get bookmarkThisPage => 'Bookmark';

  @override
  String get bookmarks => 'Bookmarks';

  @override
  String get bookmarksRoot => 'Bookmarks (top level)';

  @override
  String get browsingDataCleared => 'Browsing data cleared';

  @override
  String get cache => 'Cached images and files';

  @override
  String get camera => 'Camera';

  @override
  String get cancel => 'Cancel';

  @override
  String get catAds => 'Ads in the app';

  @override
  String get catBlocking => 'Content blocking';

  @override
  String get catOther => 'Other';

  @override
  String get catSiteBroken => 'Website doesn\'t work';

  @override
  String get catVideo => 'Video or audio';

  @override
  String get category => 'Category';

  @override
  String get certificateError =>
      'The site\'s security certificate is not valid. The connection was stopped to protect you.';

  @override
  String get certificateErrorTitle => 'Connection not secure';

  @override
  String get clear => 'Clear';

  @override
  String get clearBrowsingData => 'Clear browsing data';

  @override
  String get clearHistory => 'Clear history';

  @override
  String get clearSiteData => 'Clear data for this site';

  @override
  String get clearSiteDataBody =>
      'Cookies and stored data for this site will be deleted. You may be signed out.';

  @override
  String clearSiteDataTitle(String host) {
    return 'Clear data for $host?';
  }

  @override
  String get close => 'Close';

  @override
  String get closeAll => 'Close all';

  @override
  String get closeAllBody => 'All open tabs will be closed.';

  @override
  String get closeAllPrivateBody =>
      'All private tabs will be closed and their cookies and site data deleted.';

  @override
  String get closeAllPrivateTitle => 'Close all private tabs?';

  @override
  String get closeAllTitle => 'Close all tabs?';

  @override
  String get closeTab => 'Close tab';

  @override
  String get connectionInsecure => 'Not secure';

  @override
  String get connectionInsecureHint =>
      'Information you send or receive on this site could be read by others on the network.';

  @override
  String get connectionSecure => 'Connection is secure';

  @override
  String get connectionSecureHint =>
      'Encrypted (HTTPS). This does not mean the site itself is trustworthy.';

  @override
  String get contentBlocking => 'Content blocking';

  @override
  String get cookiesAndSiteData => 'Cookies and site data';

  @override
  String get cookiesSignOutHint => 'Signs you out of most sites';

  @override
  String get copyLink => 'Copy link';

  @override
  String get delete => 'Delete';

  @override
  String get deleteFolderBody =>
      'The folder, its subfolders and bookmarks will be deleted.';

  @override
  String get deleteFolderTitle => 'Delete folder?';

  @override
  String get denied => 'Blocked';

  @override
  String get deny => 'Block';

  @override
  String get describeProblem => 'What went wrong?';

  @override
  String get desktopSite => 'Desktop site';

  @override
  String get desktopSiteDefault => 'Request desktop sites by default';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get downloadCanceled => 'Canceled';

  @override
  String downloadFailed(String error) {
    return 'Failed $error';
  }

  @override
  String downloadStarted(String name) {
    return 'Downloading $name';
  }

  @override
  String downloadingBytes(String size) {
    return '$size downloaded';
  }

  @override
  String get downloads => 'Downloads';

  @override
  String get edit => 'Edit';

  @override
  String get editShortcut => 'Edit shortcut';

  @override
  String get editSuggestion => 'Edit this address';

  @override
  String get exitPrivate => 'Close private tabs';

  @override
  String get files => 'Files';

  @override
  String get findInPage => 'Find in page';

  @override
  String get followSystem => 'System default';

  @override
  String get forward => 'Forward';

  @override
  String get general => 'General';

  @override
  String get help => 'Help';

  @override
  String get history => 'History';

  @override
  String historyDeleted(int count) {
    return '$count entries deleted';
  }

  @override
  String get home => 'Home';

  @override
  String includeSiteHost(String host) {
    return 'Include site name ($host)';
  }

  @override
  String get includeSiteHostHint =>
      'Only the domain name, never the full address';

  @override
  String get invalidAddress => 'Enter a valid web address';

  @override
  String get javascript => 'JavaScript';

  @override
  String get language => 'Language';

  @override
  String get linkCopied => 'Link copied';

  @override
  String get location => 'Location';

  @override
  String get media => 'Video & audio';

  @override
  String get menu => 'Menu';

  @override
  String get microphone => 'Microphone';

  @override
  String get mobileSite => 'Mobile site';

  @override
  String get more => 'More';

  @override
  String get moveEarlier => 'Move earlier';

  @override
  String get moveLater => 'Move later';

  @override
  String get moveToFolder => 'Move to folder';

  @override
  String get name => 'Name';

  @override
  String get newFolder => 'New folder';

  @override
  String get newPrivateTab => 'New private tab';

  @override
  String get newSuggestedShortcuts => 'New suggested shortcuts';

  @override
  String get newTab => 'New tab';

  @override
  String get next => 'Next';

  @override
  String get noAppToOpen => 'No app can open this link';

  @override
  String get noBookmarks => 'No bookmarks yet';

  @override
  String get noDownloads =>
      'No files yet. Files you download from websites appear here.';

  @override
  String get noHistory => 'No history';

  @override
  String get noPrivateTabs => 'No private tabs';

  @override
  String get noTabs => 'No open tabs';

  @override
  String get none => 'None';

  @override
  String get ok => 'OK';

  @override
  String get open => 'Open';

  @override
  String openExternalBody(String scheme) {
    return 'This link wants to open another app ($scheme:). Continue?';
  }

  @override
  String get openExternalTitle => 'Leave the browser?';

  @override
  String get openInNewTab => 'Open in new tab';

  @override
  String get openInSystemBrowser => 'Open in other browser';

  @override
  String get openSourceLicenses => 'Open-source licenses';

  @override
  String get pageCrashed => 'This page stopped working. Reload to try again.';

  @override
  String get pageLoadFailed => 'This page couldn\'t be loaded';

  @override
  String get paste => 'Paste';

  @override
  String get permissionCamera => 'This site wants to use your camera.';

  @override
  String get permissionLocation => 'This site wants to know your location.';

  @override
  String get permissionMicrophone => 'This site wants to use your microphone.';

  @override
  String permissionTitle(String host) {
    return '$host';
  }

  @override
  String get pictureInPicture => 'Picture-in-picture';

  @override
  String get previous => 'Previous';

  @override
  String get privacy => 'Privacy';

  @override
  String get privacyPolicy => 'Privacy policy';

  @override
  String get privateDoes =>
      'Private tabs keep their cookies and site data separate from normal tabs, and don\'t save history. Everything is deleted when you close the last private tab.';

  @override
  String get privateDoesNot =>
      'Private mode does not hide you from websites, your employer or your internet provider. Downloads and bookmarks you create are kept.';

  @override
  String get privateIsolationFailed =>
      'This private tab could not be isolated, so the page was not loaded.';

  @override
  String get privateTab => 'Private';

  @override
  String get privateTabs => 'Private tabs';

  @override
  String get privateTitle => 'You\'re browsing privately';

  @override
  String get privateUnavailableBody =>
      'Your device\'s Android System WebView doesn\'t support separate browsing profiles, so private tabs can\'t be isolated. Update \"Android System WebView\" from Google Play and try again.';

  @override
  String get privateUnavailableTitle => 'Private tabs unavailable';

  @override
  String get productsMissing =>
      'Subscriptions are not available in the store yet.';

  @override
  String purchaseError(String error) {
    return 'Purchase problem: $error';
  }

  @override
  String get rangeAll => 'All time';

  @override
  String get rangeLast4Weeks => 'Last 4 weeks';

  @override
  String get rangeLast7Days => 'Last 7 days';

  @override
  String get rangeLastHour => 'Last hour';

  @override
  String get rangeToday => 'Today';

  @override
  String get reload => 'Reload';

  @override
  String get removeAds => 'Remove app ads';

  @override
  String get removeAdsHint => 'Subscription for this app\'s own ads';

  @override
  String get rename => 'Rename';

  @override
  String get reportFailed => 'Couldn\'t send the report. Try again later.';

  @override
  String get reportPreviewTitle => 'This will be sent';

  @override
  String get reportPrivacyNote =>
      'Reports never include your browsing history, full page addresses, cookies or passwords. Links and e-mail addresses in your text are shortened or masked.';

  @override
  String get reportProblem => 'Report a problem';

  @override
  String get reportSent => 'Thanks, report sent';

  @override
  String get reportUnavailable => 'Reporting is not configured in this build.';

  @override
  String get requiredField => 'Required';

  @override
  String get reset => 'Reset';

  @override
  String get restorePurchases => 'Restore purchases';

  @override
  String get restoreTabs => 'Restore tabs on start';

  @override
  String get retry => 'Try again';

  @override
  String get revertBlocklist => 'Use previous';

  @override
  String get reviewAndSend => 'Review and send';

  @override
  String rulesCount(int count) {
    return '$count rules';
  }

  @override
  String get save => 'Save';

  @override
  String get searchBookmarks => 'Search bookmarks';

  @override
  String get searchEngine => 'Search engine';

  @override
  String get searchHistory => 'Search history';

  @override
  String get searchOrType => 'Search or type address';

  @override
  String get searchTabs => 'Search tabs';

  @override
  String searchWith(String engine) {
    return 'Search with $engine or type address';
  }

  @override
  String get send => 'Send';

  @override
  String get settings => 'Settings';

  @override
  String get share => 'Share';

  @override
  String get shareOrOpen => 'Share / open with…';

  @override
  String get siteDataCleared => 'Site data cleared';

  @override
  String get siteInfo => 'Site information';

  @override
  String get sitePermissions => 'Site permissions';

  @override
  String get stop => 'Stop';

  @override
  String get storeUnavailable =>
      'The app store is not available on this device.';

  @override
  String get subscriptionManageHint =>
      'Manage or cancel the subscription in your App Store or Google Play account. Ads come back when it ends.';

  @override
  String get subscriptionNotConfigured =>
      'Subscriptions are not set up in this version yet.';

  @override
  String get subscriptionScope =>
      'The subscription removes the ads shown by this app. It is not a subscription to YouTube or any other platform and does not unlock content on websites.';

  @override
  String get support => 'Support';

  @override
  String get tabs => 'Tabs';

  @override
  String get terms => 'Terms of use';

  @override
  String get textSize => 'Text size';

  @override
  String get theme => 'Theme';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get thirdPartyCookies => 'Allow third-party cookies';

  @override
  String get thirdPartyCookiesHint =>
      'Some sign-ins and embedded videos need them. Always blocked in private tabs.';

  @override
  String validUntil(String date) {
    return 'Valid until $date';
  }

  @override
  String get version => 'Version';
}
