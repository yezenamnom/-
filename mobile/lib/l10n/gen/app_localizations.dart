import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @adFreeActive.
  ///
  /// In en, this message translates to:
  /// **'Ad-free active'**
  String get adFreeActive;

  /// No description provided for @adLabel.
  ///
  /// In en, this message translates to:
  /// **'Ad'**
  String get adLabel;

  /// No description provided for @adPrivacyOptions.
  ///
  /// In en, this message translates to:
  /// **'Ad privacy choices'**
  String get adPrivacyOptions;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @addShortcut.
  ///
  /// In en, this message translates to:
  /// **'Add shortcut'**
  String get addShortcut;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @addressBar.
  ///
  /// In en, this message translates to:
  /// **'Address bar'**
  String get addressBar;

  /// No description provided for @adsAndSubscription.
  ///
  /// In en, this message translates to:
  /// **'Ads & subscription'**
  String get adsAndSubscription;

  /// No description provided for @allowAlways.
  ///
  /// In en, this message translates to:
  /// **'Always allow'**
  String get allowAlways;

  /// No description provided for @allowOnce.
  ///
  /// In en, this message translates to:
  /// **'Allow this time'**
  String get allowOnce;

  /// No description provided for @allowed.
  ///
  /// In en, this message translates to:
  /// **'Allowed'**
  String get allowed;

  /// No description provided for @appAdsExplained.
  ///
  /// In en, this message translates to:
  /// **'About ads in this app'**
  String get appAdsExplained;

  /// No description provided for @appAdsExplainedBody.
  ///
  /// In en, this message translates to:
  /// **'The app shows its own ads in its screens (never on websites or over videos). Content blocking on websites is separate and does not affect these ads.'**
  String get appAdsExplainedBody;

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Vela'**
  String get appName;

  /// No description provided for @autoPip.
  ///
  /// In en, this message translates to:
  /// **'Picture-in-picture on leave'**
  String get autoPip;

  /// No description provided for @autoPipHint.
  ///
  /// In en, this message translates to:
  /// **'When a video is fullscreen and you leave the app'**
  String get autoPipHint;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @backgroundAudio.
  ///
  /// In en, this message translates to:
  /// **'Keep audio playing in background'**
  String get backgroundAudio;

  /// No description provided for @backgroundAudioHint.
  ///
  /// In en, this message translates to:
  /// **'Only where the system and the website\'s terms allow it (not on YouTube, where background play is a Premium feature). Some sites pause playback themselves.'**
  String get backgroundAudioHint;

  /// No description provided for @blockAdsTrackers.
  ///
  /// In en, this message translates to:
  /// **'Block ads & trackers on websites'**
  String get blockAdsTrackers;

  /// No description provided for @blockAdsTrackersHint.
  ///
  /// In en, this message translates to:
  /// **'Works only inside this browser. Coverage differs between Android and iOS and some sites may break.'**
  String get blockAdsTrackersHint;

  /// No description provided for @blockOnThisSite.
  ///
  /// In en, this message translates to:
  /// **'Blocking on this site'**
  String get blockOnThisSite;

  /// No description provided for @blockOnThisSiteHint.
  ///
  /// In en, this message translates to:
  /// **'Turn off if the site does not work correctly'**
  String get blockOnThisSiteHint;

  /// No description provided for @blockPopups.
  ///
  /// In en, this message translates to:
  /// **'Block pop-ups'**
  String get blockPopups;

  /// No description provided for @blockingExceptions.
  ///
  /// In en, this message translates to:
  /// **'Sites without blocking'**
  String get blockingExceptions;

  /// No description provided for @blockingExceptionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No exceptions yet. Use the shield in a site\'s info panel to add one.'**
  String get blockingExceptionsEmpty;

  /// No description provided for @blockingGloballyOff.
  ///
  /// In en, this message translates to:
  /// **'Blocking is turned off in settings'**
  String get blockingGloballyOff;

  /// No description provided for @blocklistVersion.
  ///
  /// In en, this message translates to:
  /// **'Block list version {version}'**
  String blocklistVersion(int version);

  /// No description provided for @bookmarkAdded.
  ///
  /// In en, this message translates to:
  /// **'Bookmark added'**
  String get bookmarkAdded;

  /// No description provided for @bookmarkRemoved.
  ///
  /// In en, this message translates to:
  /// **'Bookmark removed'**
  String get bookmarkRemoved;

  /// No description provided for @bookmarkThisPage.
  ///
  /// In en, this message translates to:
  /// **'Bookmark'**
  String get bookmarkThisPage;

  /// No description provided for @bookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get bookmarks;

  /// No description provided for @bookmarksRoot.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks (top level)'**
  String get bookmarksRoot;

  /// No description provided for @browsingDataCleared.
  ///
  /// In en, this message translates to:
  /// **'Browsing data cleared'**
  String get browsingDataCleared;

  /// No description provided for @cache.
  ///
  /// In en, this message translates to:
  /// **'Cached images and files'**
  String get cache;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @catAds.
  ///
  /// In en, this message translates to:
  /// **'Ads in the app'**
  String get catAds;

  /// No description provided for @catBlocking.
  ///
  /// In en, this message translates to:
  /// **'Content blocking'**
  String get catBlocking;

  /// No description provided for @catOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get catOther;

  /// No description provided for @catSiteBroken.
  ///
  /// In en, this message translates to:
  /// **'Website doesn\'t work'**
  String get catSiteBroken;

  /// No description provided for @catVideo.
  ///
  /// In en, this message translates to:
  /// **'Video or audio'**
  String get catVideo;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @certificateError.
  ///
  /// In en, this message translates to:
  /// **'The site\'s security certificate is not valid. The connection was stopped to protect you.'**
  String get certificateError;

  /// No description provided for @certificateErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection not secure'**
  String get certificateErrorTitle;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @clearBrowsingData.
  ///
  /// In en, this message translates to:
  /// **'Clear browsing data'**
  String get clearBrowsingData;

  /// No description provided for @clearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get clearHistory;

  /// No description provided for @clearSiteData.
  ///
  /// In en, this message translates to:
  /// **'Clear data for this site'**
  String get clearSiteData;

  /// No description provided for @clearSiteDataBody.
  ///
  /// In en, this message translates to:
  /// **'Cookies and stored data for this site will be deleted. You may be signed out.'**
  String get clearSiteDataBody;

  /// No description provided for @clearSiteDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear data for {host}?'**
  String clearSiteDataTitle(String host);

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @closeAll.
  ///
  /// In en, this message translates to:
  /// **'Close all'**
  String get closeAll;

  /// No description provided for @closeAllBody.
  ///
  /// In en, this message translates to:
  /// **'All open tabs will be closed.'**
  String get closeAllBody;

  /// No description provided for @closeAllPrivateBody.
  ///
  /// In en, this message translates to:
  /// **'All private tabs will be closed and their cookies and site data deleted.'**
  String get closeAllPrivateBody;

  /// No description provided for @closeAllPrivateTitle.
  ///
  /// In en, this message translates to:
  /// **'Close all private tabs?'**
  String get closeAllPrivateTitle;

  /// No description provided for @closeAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Close all tabs?'**
  String get closeAllTitle;

  /// No description provided for @closeTab.
  ///
  /// In en, this message translates to:
  /// **'Close tab'**
  String get closeTab;

  /// No description provided for @connectionInsecure.
  ///
  /// In en, this message translates to:
  /// **'Not secure'**
  String get connectionInsecure;

  /// No description provided for @connectionInsecureHint.
  ///
  /// In en, this message translates to:
  /// **'Information you send or receive on this site could be read by others on the network.'**
  String get connectionInsecureHint;

  /// No description provided for @connectionSecure.
  ///
  /// In en, this message translates to:
  /// **'Connection is secure'**
  String get connectionSecure;

  /// No description provided for @connectionSecureHint.
  ///
  /// In en, this message translates to:
  /// **'Encrypted (HTTPS). This does not mean the site itself is trustworthy.'**
  String get connectionSecureHint;

  /// No description provided for @contentBlocking.
  ///
  /// In en, this message translates to:
  /// **'Content blocking'**
  String get contentBlocking;

  /// No description provided for @cookiesAndSiteData.
  ///
  /// In en, this message translates to:
  /// **'Cookies and site data'**
  String get cookiesAndSiteData;

  /// No description provided for @cookiesSignOutHint.
  ///
  /// In en, this message translates to:
  /// **'Signs you out of most sites'**
  String get cookiesSignOutHint;

  /// No description provided for @copyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get copyLink;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteFolderBody.
  ///
  /// In en, this message translates to:
  /// **'The folder, its subfolders and bookmarks will be deleted.'**
  String get deleteFolderBody;

  /// No description provided for @deleteFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete folder?'**
  String get deleteFolderTitle;

  /// No description provided for @denied.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get denied;

  /// No description provided for @deny.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get deny;

  /// No description provided for @describeProblem.
  ///
  /// In en, this message translates to:
  /// **'What went wrong?'**
  String get describeProblem;

  /// No description provided for @desktopSite.
  ///
  /// In en, this message translates to:
  /// **'Desktop site'**
  String get desktopSite;

  /// No description provided for @desktopSiteDefault.
  ///
  /// In en, this message translates to:
  /// **'Request desktop sites by default'**
  String get desktopSiteDefault;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @downloadCanceled.
  ///
  /// In en, this message translates to:
  /// **'Canceled'**
  String get downloadCanceled;

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed {error}'**
  String downloadFailed(String error);

  /// No description provided for @downloadStarted.
  ///
  /// In en, this message translates to:
  /// **'Downloading {name}'**
  String downloadStarted(String name);

  /// No description provided for @downloadingBytes.
  ///
  /// In en, this message translates to:
  /// **'{size} downloaded'**
  String downloadingBytes(String size);

  /// No description provided for @downloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloads;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @editShortcut.
  ///
  /// In en, this message translates to:
  /// **'Edit shortcut'**
  String get editShortcut;

  /// No description provided for @editSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Edit this address'**
  String get editSuggestion;

  /// No description provided for @exitPrivate.
  ///
  /// In en, this message translates to:
  /// **'Close private tabs'**
  String get exitPrivate;

  /// No description provided for @files.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get files;

  /// No description provided for @findInPage.
  ///
  /// In en, this message translates to:
  /// **'Find in page'**
  String get findInPage;

  /// No description provided for @followSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get followSystem;

  /// No description provided for @forward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get forward;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @historyDeleted.
  ///
  /// In en, this message translates to:
  /// **'{count} entries deleted'**
  String historyDeleted(int count);

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @includeSiteHost.
  ///
  /// In en, this message translates to:
  /// **'Include site name ({host})'**
  String includeSiteHost(String host);

  /// No description provided for @includeSiteHostHint.
  ///
  /// In en, this message translates to:
  /// **'Only the domain name, never the full address'**
  String get includeSiteHostHint;

  /// No description provided for @invalidAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid web address'**
  String get invalidAddress;

  /// No description provided for @javascript.
  ///
  /// In en, this message translates to:
  /// **'JavaScript'**
  String get javascript;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @linkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get linkCopied;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @media.
  ///
  /// In en, this message translates to:
  /// **'Video & audio'**
  String get media;

  /// No description provided for @menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @microphone.
  ///
  /// In en, this message translates to:
  /// **'Microphone'**
  String get microphone;

  /// No description provided for @mobileSite.
  ///
  /// In en, this message translates to:
  /// **'Mobile site'**
  String get mobileSite;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @moveEarlier.
  ///
  /// In en, this message translates to:
  /// **'Move earlier'**
  String get moveEarlier;

  /// No description provided for @moveLater.
  ///
  /// In en, this message translates to:
  /// **'Move later'**
  String get moveLater;

  /// No description provided for @moveToFolder.
  ///
  /// In en, this message translates to:
  /// **'Move to folder'**
  String get moveToFolder;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @newFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get newFolder;

  /// No description provided for @newPrivateTab.
  ///
  /// In en, this message translates to:
  /// **'New private tab'**
  String get newPrivateTab;

  /// No description provided for @newSuggestedShortcuts.
  ///
  /// In en, this message translates to:
  /// **'New suggested shortcuts'**
  String get newSuggestedShortcuts;

  /// No description provided for @newTab.
  ///
  /// In en, this message translates to:
  /// **'New tab'**
  String get newTab;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @noAppToOpen.
  ///
  /// In en, this message translates to:
  /// **'No app can open this link'**
  String get noAppToOpen;

  /// No description provided for @noBookmarks.
  ///
  /// In en, this message translates to:
  /// **'No bookmarks yet'**
  String get noBookmarks;

  /// No description provided for @noDownloads.
  ///
  /// In en, this message translates to:
  /// **'No files yet. Files you download from websites appear here.'**
  String get noDownloads;

  /// No description provided for @noHistory.
  ///
  /// In en, this message translates to:
  /// **'No history'**
  String get noHistory;

  /// No description provided for @noPrivateTabs.
  ///
  /// In en, this message translates to:
  /// **'No private tabs'**
  String get noPrivateTabs;

  /// No description provided for @noTabs.
  ///
  /// In en, this message translates to:
  /// **'No open tabs'**
  String get noTabs;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @openExternalBody.
  ///
  /// In en, this message translates to:
  /// **'This link wants to open another app ({scheme}:). Continue?'**
  String openExternalBody(String scheme);

  /// No description provided for @openExternalTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave the browser?'**
  String get openExternalTitle;

  /// No description provided for @openInNewTab.
  ///
  /// In en, this message translates to:
  /// **'Open in new tab'**
  String get openInNewTab;

  /// No description provided for @openInSystemBrowser.
  ///
  /// In en, this message translates to:
  /// **'Open in other browser'**
  String get openInSystemBrowser;

  /// No description provided for @openSourceLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source licenses'**
  String get openSourceLicenses;

  /// No description provided for @pageCrashed.
  ///
  /// In en, this message translates to:
  /// **'This page stopped working. Reload to try again.'**
  String get pageCrashed;

  /// No description provided for @pageLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'This page couldn\'t be loaded'**
  String get pageLoadFailed;

  /// No description provided for @paste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get paste;

  /// No description provided for @permissionCamera.
  ///
  /// In en, this message translates to:
  /// **'This site wants to use your camera.'**
  String get permissionCamera;

  /// No description provided for @permissionLocation.
  ///
  /// In en, this message translates to:
  /// **'This site wants to know your location.'**
  String get permissionLocation;

  /// No description provided for @permissionMicrophone.
  ///
  /// In en, this message translates to:
  /// **'This site wants to use your microphone.'**
  String get permissionMicrophone;

  /// No description provided for @permissionTitle.
  ///
  /// In en, this message translates to:
  /// **'{host}'**
  String permissionTitle(String host);

  /// No description provided for @pictureInPicture.
  ///
  /// In en, this message translates to:
  /// **'Picture-in-picture'**
  String get pictureInPicture;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicy;

  /// No description provided for @privateDoes.
  ///
  /// In en, this message translates to:
  /// **'Private tabs keep their cookies and site data separate from normal tabs, and don\'t save history. Everything is deleted when you close the last private tab.'**
  String get privateDoes;

  /// No description provided for @privateDoesNot.
  ///
  /// In en, this message translates to:
  /// **'Private mode does not hide you from websites, your employer or your internet provider. Downloads and bookmarks you create are kept.'**
  String get privateDoesNot;

  /// No description provided for @privateIsolationFailed.
  ///
  /// In en, this message translates to:
  /// **'This private tab could not be isolated, so the page was not loaded.'**
  String get privateIsolationFailed;

  /// No description provided for @privateTab.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get privateTab;

  /// No description provided for @privateTabs.
  ///
  /// In en, this message translates to:
  /// **'Private tabs'**
  String get privateTabs;

  /// No description provided for @privateTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re browsing privately'**
  String get privateTitle;

  /// No description provided for @privateUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'Your device\'s Android System WebView doesn\'t support separate browsing profiles, so private tabs can\'t be isolated. Update \"Android System WebView\" from Google Play and try again.'**
  String get privateUnavailableBody;

  /// No description provided for @privateUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Private tabs unavailable'**
  String get privateUnavailableTitle;

  /// No description provided for @productsMissing.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions are not available in the store yet.'**
  String get productsMissing;

  /// No description provided for @purchaseError.
  ///
  /// In en, this message translates to:
  /// **'Purchase problem: {error}'**
  String purchaseError(String error);

  /// No description provided for @rangeAll.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get rangeAll;

  /// No description provided for @rangeLast4Weeks.
  ///
  /// In en, this message translates to:
  /// **'Last 4 weeks'**
  String get rangeLast4Weeks;

  /// No description provided for @rangeLast7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get rangeLast7Days;

  /// No description provided for @rangeLastHour.
  ///
  /// In en, this message translates to:
  /// **'Last hour'**
  String get rangeLastHour;

  /// No description provided for @rangeToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get rangeToday;

  /// No description provided for @reload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get reload;

  /// No description provided for @removeAds.
  ///
  /// In en, this message translates to:
  /// **'Remove app ads'**
  String get removeAds;

  /// No description provided for @removeAdsHint.
  ///
  /// In en, this message translates to:
  /// **'Subscription for this app\'s own ads'**
  String get removeAdsHint;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @reportFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the report. Try again later.'**
  String get reportFailed;

  /// No description provided for @reportPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'This will be sent'**
  String get reportPreviewTitle;

  /// No description provided for @reportPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'Reports never include your browsing history, full page addresses, cookies or passwords. Links and e-mail addresses in your text are shortened or masked.'**
  String get reportPrivacyNote;

  /// No description provided for @reportProblem.
  ///
  /// In en, this message translates to:
  /// **'Report a problem'**
  String get reportProblem;

  /// No description provided for @reportSent.
  ///
  /// In en, this message translates to:
  /// **'Thanks, report sent'**
  String get reportSent;

  /// No description provided for @reportUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Reporting is not configured in this build.'**
  String get reportUnavailable;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get requiredField;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @restorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get restorePurchases;

  /// No description provided for @restoreTabs.
  ///
  /// In en, this message translates to:
  /// **'Restore tabs on start'**
  String get restoreTabs;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @revertBlocklist.
  ///
  /// In en, this message translates to:
  /// **'Use previous'**
  String get revertBlocklist;

  /// No description provided for @reviewAndSend.
  ///
  /// In en, this message translates to:
  /// **'Review and send'**
  String get reviewAndSend;

  /// No description provided for @rulesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} rules'**
  String rulesCount(int count);

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @searchBookmarks.
  ///
  /// In en, this message translates to:
  /// **'Search bookmarks'**
  String get searchBookmarks;

  /// No description provided for @searchEngine.
  ///
  /// In en, this message translates to:
  /// **'Search engine'**
  String get searchEngine;

  /// No description provided for @searchHistory.
  ///
  /// In en, this message translates to:
  /// **'Search history'**
  String get searchHistory;

  /// No description provided for @searchOrType.
  ///
  /// In en, this message translates to:
  /// **'Search or type address'**
  String get searchOrType;

  /// No description provided for @searchTabs.
  ///
  /// In en, this message translates to:
  /// **'Search tabs'**
  String get searchTabs;

  /// No description provided for @searchWith.
  ///
  /// In en, this message translates to:
  /// **'Search with {engine} or type address'**
  String searchWith(String engine);

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @shareOrOpen.
  ///
  /// In en, this message translates to:
  /// **'Share / open with…'**
  String get shareOrOpen;

  /// No description provided for @siteDataCleared.
  ///
  /// In en, this message translates to:
  /// **'Site data cleared'**
  String get siteDataCleared;

  /// No description provided for @siteInfo.
  ///
  /// In en, this message translates to:
  /// **'Site information'**
  String get siteInfo;

  /// No description provided for @sitePermissions.
  ///
  /// In en, this message translates to:
  /// **'Site permissions'**
  String get sitePermissions;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @storeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The app store is not available on this device.'**
  String get storeUnavailable;

  /// No description provided for @subscriptionManageHint.
  ///
  /// In en, this message translates to:
  /// **'Manage or cancel the subscription in your App Store or Google Play account. Ads come back when it ends.'**
  String get subscriptionManageHint;

  /// No description provided for @subscriptionNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions are not set up in this version yet.'**
  String get subscriptionNotConfigured;

  /// No description provided for @subscriptionScope.
  ///
  /// In en, this message translates to:
  /// **'The subscription removes the ads shown by this app. It is not a subscription to YouTube or any other platform and does not unlock content on websites.'**
  String get subscriptionScope;

  /// No description provided for @support.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// No description provided for @tabs.
  ///
  /// In en, this message translates to:
  /// **'Tabs'**
  String get tabs;

  /// No description provided for @terms.
  ///
  /// In en, this message translates to:
  /// **'Terms of use'**
  String get terms;

  /// No description provided for @textSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get textSize;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @thirdPartyCookies.
  ///
  /// In en, this message translates to:
  /// **'Allow third-party cookies'**
  String get thirdPartyCookies;

  /// No description provided for @thirdPartyCookiesHint.
  ///
  /// In en, this message translates to:
  /// **'Some sign-ins and embedded videos need them. Always blocked in private tabs.'**
  String get thirdPartyCookiesHint;

  /// No description provided for @validUntil.
  ///
  /// In en, this message translates to:
  /// **'Valid until {date}'**
  String validUntil(String date);

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
