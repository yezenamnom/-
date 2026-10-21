// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get about => 'حول التطبيق';

  @override
  String get adFreeActive => 'إزالة الإعلانات مفعّلة';

  @override
  String get adLabel => 'إعلان';

  @override
  String get adPrivacyOptions => 'خيارات خصوصية الإعلانات';

  @override
  String get add => 'إضافة';

  @override
  String get addShortcut => 'إضافة اختصار';

  @override
  String get address => 'العنوان';

  @override
  String get addressBar => 'شريط العنوان';

  @override
  String get adsAndSubscription => 'الإعلانات والاشتراك';

  @override
  String get allowAlways => 'السماح دائماً';

  @override
  String get allowOnce => 'السماح هذه المرة';

  @override
  String get allowed => 'مسموح';

  @override
  String get appAdsExplained => 'عن الإعلانات في هذا التطبيق';

  @override
  String get appAdsExplainedBody =>
      'يعرض التطبيق إعلاناته الخاصة في شاشاته فقط (وليس داخل المواقع أو فوق الفيديو). حجب المحتوى في المواقع ميزة منفصلة ولا يؤثر على هذه الإعلانات.';

  @override
  String get appName => 'فيلا';

  @override
  String get autoPip => 'صورة داخل صورة عند الخروج';

  @override
  String get autoPipHint => 'عند تشغيل فيديو بملء الشاشة ومغادرة التطبيق';

  @override
  String get back => 'رجوع';

  @override
  String get backgroundAudio => 'متابعة الصوت في الخلفية';

  @override
  String get backgroundAudioHint =>
      'فقط حيث يسمح النظام والموقع. بعض المواقع توقف التشغيل بنفسها.';

  @override
  String get blockAdsTrackers => 'حجب الإعلانات والمتتبعات في المواقع';

  @override
  String get blockAdsTrackersHint =>
      'يعمل داخل هذا المتصفح فقط. التغطية تختلف بين أندرويد وiOS وقد تتعطل بعض المواقع.';

  @override
  String get blockOnThisSite => 'الحجب في هذا الموقع';

  @override
  String get blockOnThisSiteHint => 'أوقفه إذا لم يعمل الموقع بشكل صحيح';

  @override
  String get blockPopups => 'حظر النوافذ المنبثقة';

  @override
  String get blockingExceptions => 'مواقع مستثناة من الحجب';

  @override
  String get blockingExceptionsEmpty =>
      'لا توجد استثناءات. استخدم خيار الحجب في معلومات الموقع لإضافة استثناء.';

  @override
  String get blockingGloballyOff => 'الحجب متوقف من الإعدادات';

  @override
  String blocklistVersion(int version) {
    return 'إصدار قائمة الحجب $version';
  }

  @override
  String get bookmarkAdded => 'أُضيفت إلى المفضلة';

  @override
  String get bookmarkRemoved => 'أُزيلت من المفضلة';

  @override
  String get bookmarkThisPage => 'إضافة للمفضلة';

  @override
  String get bookmarks => 'المفضلة';

  @override
  String get bookmarksRoot => 'المفضلة (المستوى الأعلى)';

  @override
  String get browsingDataCleared => 'تم مسح بيانات التصفح';

  @override
  String get cache => 'الصور والملفات المخزنة مؤقتاً';

  @override
  String get camera => 'الكاميرا';

  @override
  String get cancel => 'إلغاء';

  @override
  String get catAds => 'إعلانات التطبيق';

  @override
  String get catBlocking => 'حجب المحتوى';

  @override
  String get catOther => 'أخرى';

  @override
  String get catSiteBroken => 'موقع لا يعمل';

  @override
  String get catVideo => 'فيديو أو صوت';

  @override
  String get category => 'التصنيف';

  @override
  String get certificateError =>
      'شهادة الأمان لهذا الموقع غير صالحة. أُوقف الاتصال لحمايتك.';

  @override
  String get certificateErrorTitle => 'الاتصال غير آمن';

  @override
  String get clear => 'مسح';

  @override
  String get clearBrowsingData => 'مسح بيانات التصفح';

  @override
  String get clearHistory => 'مسح السجل';

  @override
  String get clearSiteData => 'مسح بيانات هذا الموقع';

  @override
  String get clearSiteDataBody =>
      'ستُحذف الكوكيز والبيانات المخزنة لهذا الموقع وقد يتم تسجيل خروجك.';

  @override
  String clearSiteDataTitle(String host) {
    return 'مسح بيانات $host؟';
  }

  @override
  String get close => 'إغلاق';

  @override
  String get closeAll => 'إغلاق الكل';

  @override
  String get closeAllBody => 'سيتم إغلاق جميع التبويبات المفتوحة.';

  @override
  String get closeAllPrivateBody =>
      'سيتم إغلاق كل التبويبات الخاصة وحذف الكوكيز وبيانات المواقع الخاصة بها.';

  @override
  String get closeAllPrivateTitle => 'إغلاق كل التبويبات الخاصة؟';

  @override
  String get closeAllTitle => 'إغلاق كل التبويبات؟';

  @override
  String get closeTab => 'إغلاق التبويب';

  @override
  String get connectionInsecure => 'غير آمن';

  @override
  String get connectionInsecureHint =>
      'قد يتمكن آخرون على الشبكة من قراءة ما ترسله أو تستقبله في هذا الموقع.';

  @override
  String get connectionSecure => 'الاتصال آمن';

  @override
  String get connectionSecureHint =>
      'الاتصال مشفّر (HTTPS). هذا لا يعني أن الموقع نفسه موثوق.';

  @override
  String get contentBlocking => 'حجب المحتوى';

  @override
  String get cookiesAndSiteData => 'الكوكيز وبيانات المواقع';

  @override
  String get cookiesSignOutHint => 'سيسجّل خروجك من معظم المواقع';

  @override
  String get copyLink => 'نسخ الرابط';

  @override
  String get delete => 'حذف';

  @override
  String get deleteFolderBody =>
      'سيُحذف المجلد ومجلداته الفرعية وما فيها من مفضلة.';

  @override
  String get deleteFolderTitle => 'حذف المجلد؟';

  @override
  String get denied => 'محظور';

  @override
  String get deny => 'رفض';

  @override
  String get describeProblem => 'ما المشكلة؟';

  @override
  String get desktopSite => 'نسخة سطح المكتب';

  @override
  String get desktopSiteDefault => 'طلب نسخة سطح المكتب افتراضياً';

  @override
  String get dismiss => 'تجاهل';

  @override
  String get downloadCanceled => 'أُلغي';

  @override
  String downloadFailed(String error) {
    return 'فشل $error';
  }

  @override
  String downloadStarted(String name) {
    return 'جارٍ تنزيل $name';
  }

  @override
  String downloadingBytes(String size) {
    return 'تم تنزيل $size';
  }

  @override
  String get downloads => 'التنزيلات';

  @override
  String get edit => 'تعديل';

  @override
  String get editShortcut => 'تعديل الاختصار';

  @override
  String get editSuggestion => 'تعديل هذا العنوان';

  @override
  String get exitPrivate => 'إغلاق التبويبات الخاصة';

  @override
  String get files => 'الملفات';

  @override
  String get findInPage => 'البحث في الصفحة';

  @override
  String get followSystem => 'حسب النظام';

  @override
  String get forward => 'تقدّم';

  @override
  String get general => 'عام';

  @override
  String get help => 'المساعدة';

  @override
  String get history => 'السجل';

  @override
  String historyDeleted(int count) {
    return 'حُذف $count من السجل';
  }

  @override
  String get home => 'الرئيسية';

  @override
  String includeSiteHost(String host) {
    return 'إرفاق اسم الموقع ($host)';
  }

  @override
  String get includeSiteHostHint => 'اسم النطاق فقط، وليس العنوان الكامل';

  @override
  String get invalidAddress => 'أدخل عنوان ويب صالحاً';

  @override
  String get javascript => 'جافاسكربت';

  @override
  String get language => 'اللغة';

  @override
  String get linkCopied => 'تم نسخ الرابط';

  @override
  String get location => 'الموقع الجغرافي';

  @override
  String get media => 'الفيديو والصوت';

  @override
  String get menu => 'القائمة';

  @override
  String get microphone => 'الميكروفون';

  @override
  String get mobileSite => 'نسخة الجوال';

  @override
  String get more => 'المزيد';

  @override
  String get moveEarlier => 'تقديم';

  @override
  String get moveLater => 'تأخير';

  @override
  String get moveToFolder => 'نقل إلى مجلد';

  @override
  String get name => 'الاسم';

  @override
  String get newFolder => 'مجلد جديد';

  @override
  String get newPrivateTab => 'تبويب خاص جديد';

  @override
  String get newSuggestedShortcuts => 'اختصارات مقترحة جديدة';

  @override
  String get newTab => 'تبويب جديد';

  @override
  String get next => 'التالي';

  @override
  String get noAppToOpen => 'لا يوجد تطبيق يفتح هذا الرابط';

  @override
  String get noBookmarks => 'لا توجد مفضلة بعد';

  @override
  String get noDownloads =>
      'لا توجد ملفات بعد. الملفات التي تنزّلها من المواقع تظهر هنا.';

  @override
  String get noHistory => 'السجل فارغ';

  @override
  String get noPrivateTabs => 'لا توجد تبويبات خاصة';

  @override
  String get noTabs => 'لا توجد تبويبات مفتوحة';

  @override
  String get none => 'لا يوجد';

  @override
  String get ok => 'حسناً';

  @override
  String get open => 'فتح';

  @override
  String openExternalBody(String scheme) {
    return 'هذا الرابط يريد فتح تطبيق آخر ($scheme:). هل تتابع؟';
  }

  @override
  String get openExternalTitle => 'مغادرة المتصفح؟';

  @override
  String get openInNewTab => 'فتح في تبويب جديد';

  @override
  String get openInSystemBrowser => 'فتح في متصفح آخر';

  @override
  String get openSourceLicenses => 'تراخيص المكونات مفتوحة المصدر';

  @override
  String get pageCrashed => 'توقفت هذه الصفحة عن العمل. أعد التحميل للمحاولة.';

  @override
  String get pageLoadFailed => 'تعذّر تحميل الصفحة';

  @override
  String get paste => 'لصق';

  @override
  String get permissionCamera => 'يريد هذا الموقع استخدام الكاميرا.';

  @override
  String get permissionLocation => 'يريد هذا الموقع معرفة موقعك.';

  @override
  String get permissionMicrophone => 'يريد هذا الموقع استخدام الميكروفون.';

  @override
  String permissionTitle(String host) {
    return '$host';
  }

  @override
  String get pictureInPicture => 'صورة داخل صورة';

  @override
  String get previous => 'السابق';

  @override
  String get privacy => 'الخصوصية';

  @override
  String get privacyPolicy => 'سياسة الخصوصية';

  @override
  String get privateDoes =>
      'التبويبات الخاصة تفصل الكوكيز وبيانات المواقع عن التبويبات العادية ولا تحفظ السجل. يُحذف كل شيء عند إغلاق آخر تبويب خاص.';

  @override
  String get privateDoesNot =>
      'الوضع الخاص لا يخفيك عن المواقع أو جهة العمل أو مزود الإنترنت. التنزيلات والمفضلة التي تنشئها تبقى محفوظة.';

  @override
  String get privateIsolationFailed =>
      'تعذّر عزل هذا التبويب الخاص، لذلك لم تُحمّل الصفحة.';

  @override
  String get privateTab => 'خاص';

  @override
  String get privateTabs => 'التبويبات الخاصة';

  @override
  String get privateTitle => 'أنت تتصفح بشكل خاص';

  @override
  String get privateUnavailableBody =>
      'لا يدعم Android System WebView في جهازك ملفات تصفح منفصلة، لذا لا يمكن عزل التبويبات الخاصة. حدّث \"Android System WebView\" من Google Play ثم أعد المحاولة.';

  @override
  String get privateUnavailableTitle => 'التبويبات الخاصة غير متاحة';

  @override
  String get productsMissing => 'الاشتراكات غير متاحة في المتجر بعد.';

  @override
  String purchaseError(String error) {
    return 'مشكلة في الشراء: $error';
  }

  @override
  String get rangeAll => 'كل الوقت';

  @override
  String get rangeLast4Weeks => 'آخر 4 أسابيع';

  @override
  String get rangeLast7Days => 'آخر 7 أيام';

  @override
  String get rangeLastHour => 'آخر ساعة';

  @override
  String get rangeToday => 'اليوم';

  @override
  String get reload => 'إعادة تحميل';

  @override
  String get removeAds => 'إزالة إعلانات التطبيق';

  @override
  String get removeAdsHint => 'اشتراك لإزالة إعلانات هذا التطبيق فقط';

  @override
  String get rename => 'إعادة تسمية';

  @override
  String get reportFailed => 'تعذّر إرسال البلاغ. حاول لاحقاً.';

  @override
  String get reportPreviewTitle => 'سيتم إرسال ما يلي';

  @override
  String get reportPrivacyNote =>
      'لا تتضمن البلاغات سجل التصفح أو العناوين الكاملة أو الكوكيز أو كلمات المرور. تُختصر الروابط وتُخفى عناوين البريد في نصك.';

  @override
  String get reportProblem => 'الإبلاغ عن مشكلة';

  @override
  String get reportSent => 'شكراً، تم إرسال البلاغ';

  @override
  String get reportUnavailable => 'الإبلاغ غير مُعدّ في هذه النسخة.';

  @override
  String get requiredField => 'مطلوب';

  @override
  String get reset => 'إعادة ضبط';

  @override
  String get restorePurchases => 'استعادة المشتريات';

  @override
  String get restoreTabs => 'استعادة التبويبات عند التشغيل';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get revertBlocklist => 'استخدام السابق';

  @override
  String get reviewAndSend => 'مراجعة وإرسال';

  @override
  String rulesCount(int count) {
    return '$count قاعدة';
  }

  @override
  String get save => 'حفظ';

  @override
  String get searchBookmarks => 'البحث في المفضلة';

  @override
  String get searchEngine => 'محرك البحث';

  @override
  String get searchHistory => 'البحث في السجل';

  @override
  String get searchOrType => 'ابحث أو اكتب عنواناً';

  @override
  String get searchTabs => 'البحث في التبويبات';

  @override
  String searchWith(String engine) {
    return 'ابحث عبر $engine أو اكتب عنواناً';
  }

  @override
  String get send => 'إرسال';

  @override
  String get settings => 'الإعدادات';

  @override
  String get share => 'مشاركة';

  @override
  String get shareOrOpen => 'مشاركة / فتح بواسطة…';

  @override
  String get siteDataCleared => 'تم مسح بيانات الموقع';

  @override
  String get siteInfo => 'معلومات الموقع';

  @override
  String get sitePermissions => 'أذونات المواقع';

  @override
  String get stop => 'إيقاف';

  @override
  String get storeUnavailable => 'متجر التطبيقات غير متاح على هذا الجهاز.';

  @override
  String get subscriptionManageHint =>
      'يمكنك إدارة الاشتراك أو إلغاؤه من حسابك في App Store أو Google Play. تعود الإعلانات عند انتهائه.';

  @override
  String get subscriptionNotConfigured =>
      'الاشتراكات غير مُعدّة في هذه النسخة بعد.';

  @override
  String get subscriptionScope =>
      'الاشتراك يزيل الإعلانات التي يعرضها هذا التطبيق فقط. ليس اشتراكاً في يوتيوب أو أي منصة أخرى ولا يفتح أي محتوى في المواقع.';

  @override
  String get support => 'الدعم';

  @override
  String get tabs => 'التبويبات';

  @override
  String get terms => 'شروط الاستخدام';

  @override
  String get textSize => 'حجم النص';

  @override
  String get theme => 'المظهر';

  @override
  String get themeDark => 'داكن';

  @override
  String get themeLight => 'فاتح';

  @override
  String get thirdPartyCookies => 'السماح بكوكيز الطرف الثالث';

  @override
  String get thirdPartyCookiesHint =>
      'تحتاجها بعض عمليات تسجيل الدخول والفيديوهات المضمّنة. محظورة دائماً في التبويبات الخاصة.';

  @override
  String validUntil(String date) {
    return 'صالح حتى $date';
  }

  @override
  String get version => 'الإصدار';
}
