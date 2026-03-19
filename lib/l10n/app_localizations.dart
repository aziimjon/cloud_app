import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_uz.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('en'),
    Locale('ru'),
    Locale('uz'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'MyCloud'**
  String get appName;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back,'**
  String get welcomeBack;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @files.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get files;

  /// No description provided for @shared.
  ///
  /// In en, this message translates to:
  /// **'Shared'**
  String get shared;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @recent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recent;

  /// No description provided for @myCloudStorage.
  ///
  /// In en, this message translates to:
  /// **'My Cloud Storage'**
  String get myCloudStorage;

  /// No description provided for @yourCloudStorage.
  ///
  /// In en, this message translates to:
  /// **'Your cloud storage'**
  String get yourCloudStorage;

  /// No description provided for @used.
  ///
  /// In en, this message translates to:
  /// **'used'**
  String get used;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'total'**
  String get total;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @myFiles.
  ///
  /// In en, this message translates to:
  /// **'My Files'**
  String get myFiles;

  /// No description provided for @favourites.
  ///
  /// In en, this message translates to:
  /// **'Favourites'**
  String get favourites;

  /// No description provided for @overallStats.
  ///
  /// In en, this message translates to:
  /// **'Overall Statistics'**
  String get overallStats;

  /// No description provided for @images.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get images;

  /// No description provided for @videos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get videos;

  /// No description provided for @sharedByMe.
  ///
  /// In en, this message translates to:
  /// **'Shared by me'**
  String get sharedByMe;

  /// No description provided for @sharedWithMe.
  ///
  /// In en, this message translates to:
  /// **'Shared with me'**
  String get sharedWithMe;

  /// No description provided for @participants.
  ///
  /// In en, this message translates to:
  /// **'participants'**
  String get participants;

  /// No description provided for @folders.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get folders;

  /// No description provided for @folder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get folder;

  /// No description provided for @createFolder.
  ///
  /// In en, this message translates to:
  /// **'Create Folder'**
  String get createFolder;

  /// No description provided for @newFolder.
  ///
  /// In en, this message translates to:
  /// **'New Folder'**
  String get newFolder;

  /// No description provided for @folderName.
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get folderName;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @move.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get move;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @addToFavourites.
  ///
  /// In en, this message translates to:
  /// **'Add to favourites'**
  String get addToFavourites;

  /// No description provided for @removeFromFavourites.
  ///
  /// In en, this message translates to:
  /// **'Remove from favourites'**
  String get removeFromFavourites;

  /// No description provided for @deleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete?'**
  String get deleteConfirm;

  /// No description provided for @deleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?\nThis action is irreversible.'**
  String deleteConfirmMessage(String name);

  /// No description provided for @successfullyMoved.
  ///
  /// In en, this message translates to:
  /// **'Successfully moved'**
  String get successfullyMoved;

  /// No description provided for @fileSaved.
  ///
  /// In en, this message translates to:
  /// **'File saved: {name}'**
  String fileSaved(String name);

  /// No description provided for @emptyFolder.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get emptyFolder;

  /// No description provided for @emptyFolderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a folder or upload photos / videos'**
  String get emptyFolderSubtitle;

  /// No description provided for @noFavourites.
  ///
  /// In en, this message translates to:
  /// **'No favourite files'**
  String get noFavourites;

  /// No description provided for @noFavouritesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap star on a file to add it'**
  String get noFavouritesSubtitle;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @photos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get photos;

  /// No description provided for @pinnedFolders.
  ///
  /// In en, this message translates to:
  /// **'Pinned folders'**
  String get pinnedFolders;

  /// No description provided for @maxPinnedFolders.
  ///
  /// In en, this message translates to:
  /// **'Maximum 5 pinned folders'**
  String get maxPinnedFolders;

  /// No description provided for @alreadyPinned.
  ///
  /// In en, this message translates to:
  /// **'Folder already pinned'**
  String get alreadyPinned;

  /// No description provided for @pin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get pin;

  /// No description provided for @unpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get unpin;

  /// No description provided for @unpinFolder.
  ///
  /// In en, this message translates to:
  /// **'Unpin folder?'**
  String get unpinFolder;

  /// No description provided for @shareViaLink.
  ///
  /// In en, this message translates to:
  /// **'Share via link'**
  String get shareViaLink;

  /// No description provided for @shareByPhone.
  ///
  /// In en, this message translates to:
  /// **'By phone'**
  String get shareByPhone;

  /// No description provided for @shareByLink.
  ///
  /// In en, this message translates to:
  /// **'By link'**
  String get shareByLink;

  /// No description provided for @linkName.
  ///
  /// In en, this message translates to:
  /// **'Link name'**
  String get linkName;

  /// No description provided for @generate.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get generate;

  /// No description provided for @generatedLink.
  ///
  /// In en, this message translates to:
  /// **'Generated link'**
  String get generatedLink;

  /// No description provided for @linkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get linkCopied;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get copyLink;

  /// No description provided for @shareSuccess.
  ///
  /// In en, this message translates to:
  /// **'Shared successfully'**
  String get shareSuccess;

  /// No description provided for @addAtLeastOnePhone.
  ///
  /// In en, this message translates to:
  /// **'Add at least one phone number'**
  String get addAtLeastOnePhone;

  /// No description provided for @enter9Digits.
  ///
  /// In en, this message translates to:
  /// **'Enter 9 digits'**
  String get enter9Digits;

  /// No description provided for @enterLinkName.
  ///
  /// In en, this message translates to:
  /// **'Enter link name'**
  String get enterLinkName;

  /// No description provided for @fileDetails.
  ///
  /// In en, this message translates to:
  /// **'File details'**
  String get fileDetails;

  /// No description provided for @folderDetails.
  ///
  /// In en, this message translates to:
  /// **'Folder details'**
  String get folderDetails;

  /// No description provided for @fileName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get fileName;

  /// No description provided for @fileSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get fileSize;

  /// No description provided for @createdAt.
  ///
  /// In en, this message translates to:
  /// **'Created at'**
  String get createdAt;

  /// No description provided for @capturedAt.
  ///
  /// In en, this message translates to:
  /// **'Captured at'**
  String get capturedAt;

  /// No description provided for @totalSize.
  ///
  /// In en, this message translates to:
  /// **'Total size'**
  String get totalSize;

  /// No description provided for @fileCount.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get fileCount;

  /// No description provided for @folderCount.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get folderCount;

  /// No description provided for @shareRequests.
  ///
  /// In en, this message translates to:
  /// **'Share Requests'**
  String get shareRequests;

  /// No description provided for @shareRequestsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage links and access'**
  String get shareRequestsSubtitle;

  /// No description provided for @shareRequestDetails.
  ///
  /// In en, this message translates to:
  /// **'Share request details'**
  String get shareRequestDetails;

  /// No description provided for @request.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get request;

  /// No description provided for @linkNameLabel.
  ///
  /// In en, this message translates to:
  /// **'LINK NAME'**
  String get linkNameLabel;

  /// No description provided for @shareLinkLabel.
  ///
  /// In en, this message translates to:
  /// **'SHARE LINK'**
  String get shareLinkLabel;

  /// No description provided for @permissionRequests.
  ///
  /// In en, this message translates to:
  /// **'PERMISSION REQUESTS'**
  String get permissionRequests;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @approved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approved;

  /// No description provided for @rejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get rejected;

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// No description provided for @reviewAccessRequest.
  ///
  /// In en, this message translates to:
  /// **'Review access request'**
  String get reviewAccessRequest;

  /// No description provided for @reviewAccessRequestSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose whether this user should get access.'**
  String get reviewAccessRequestSubtitle;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @accessApproved.
  ///
  /// In en, this message translates to:
  /// **'Access approved'**
  String get accessApproved;

  /// No description provided for @accessRejected.
  ///
  /// In en, this message translates to:
  /// **'Access rejected'**
  String get accessRejected;

  /// No description provided for @noShareRequests.
  ///
  /// In en, this message translates to:
  /// **'No share requests'**
  String get noShareRequests;

  /// No description provided for @noShareRequestsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share files via link and they will appear here'**
  String get noShareRequestsSubtitle;

  /// No description provided for @personalData.
  ///
  /// In en, this message translates to:
  /// **'PERSONAL DATA'**
  String get personalData;

  /// No description provided for @changeName.
  ///
  /// In en, this message translates to:
  /// **'Change name'**
  String get changeName;

  /// No description provided for @changePhone.
  ///
  /// In en, this message translates to:
  /// **'Change phone'**
  String get changePhone;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// No description provided for @newName.
  ///
  /// In en, this message translates to:
  /// **'New name'**
  String get newName;

  /// No description provided for @newPhone.
  ///
  /// In en, this message translates to:
  /// **'New number'**
  String get newPhone;

  /// No description provided for @oldPassword.
  ///
  /// In en, this message translates to:
  /// **'Old password'**
  String get oldPassword;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Minimum 8 characters'**
  String get passwordTooShort;

  /// No description provided for @nameUpdated.
  ///
  /// In en, this message translates to:
  /// **'Name updated'**
  String get nameUpdated;

  /// No description provided for @phoneUpdated.
  ///
  /// In en, this message translates to:
  /// **'Phone updated'**
  String get phoneUpdated;

  /// No description provided for @passwordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get passwordChanged;

  /// No description provided for @avatarUpdated.
  ///
  /// In en, this message translates to:
  /// **'Avatar updated'**
  String get avatarUpdated;

  /// No description provided for @storage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get storage;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'APPEARANCE'**
  String get theme;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get logout;

  /// No description provided for @logoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get logoutConfirm;

  /// No description provided for @logoutConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get logoutConfirmMessage;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @selected.
  ///
  /// In en, this message translates to:
  /// **'Selected: {count}'**
  String selected(int count);

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get selectAll;

  /// No description provided for @deselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect all'**
  String get deselectAll;

  /// No description provided for @uploadFiles.
  ///
  /// In en, this message translates to:
  /// **'Upload files'**
  String get uploadFiles;

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose language'**
  String get chooseLanguage;

  /// No description provided for @home_breadcrumb.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home_breadcrumb;

  /// No description provided for @favourites_breadcrumb.
  ///
  /// In en, this message translates to:
  /// **'Favourites'**
  String get favourites_breadcrumb;

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'Selected: {count}'**
  String selectedCount(int count);

  /// No description provided for @addedToFavourites.
  ///
  /// In en, this message translates to:
  /// **'Added to favourites'**
  String get addedToFavourites;

  /// No description provided for @couldNotOpenImage.
  ///
  /// In en, this message translates to:
  /// **'Could not open image'**
  String get couldNotOpenImage;

  /// No description provided for @couldNotOpenVideo.
  ///
  /// In en, this message translates to:
  /// **'Could not open video'**
  String get couldNotOpenVideo;

  /// No description provided for @noSharedWithMe.
  ///
  /// In en, this message translates to:
  /// **'No one has shared files'**
  String get noSharedWithMe;

  /// No description provided for @noSharedWithMeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When someone shares a file — it will appear here'**
  String get noSharedWithMeSubtitle;

  /// No description provided for @noSharedByMe.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t shared with anyone yet'**
  String get noSharedByMe;

  /// No description provided for @noSharedByMeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap the share button to share files'**
  String get noSharedByMeSubtitle;

  /// No description provided for @noSharedItems.
  ///
  /// In en, this message translates to:
  /// **'No shared items'**
  String get noSharedItems;

  /// No description provided for @sharedWithLabel.
  ///
  /// In en, this message translates to:
  /// **'For {name}'**
  String sharedWithLabel(String name);

  /// No description provided for @revokeAccess.
  ///
  /// In en, this message translates to:
  /// **'Revoke access'**
  String get revokeAccess;

  /// No description provided for @revokeAccessConfirm.
  ///
  /// In en, this message translates to:
  /// **'Revoke access to \"{name}\"?'**
  String revokeAccessConfirm(String name);

  /// No description provided for @revoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get revoke;

  /// No description provided for @filesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} files'**
  String filesCount(int count);

  /// No description provided for @openLabel.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openLabel;

  /// No description provided for @usersTab.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get usersTab;

  /// No description provided for @sharedItemsTab.
  ///
  /// In en, this message translates to:
  /// **'Shared items'**
  String get sharedItemsTab;

  /// No description provided for @newNameHint.
  ///
  /// In en, this message translates to:
  /// **'New name'**
  String get newNameHint;

  /// No description provided for @deleteItems.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String deleteItems(int count);

  /// No description provided for @pinLabel.
  ///
  /// In en, this message translates to:
  /// **'📌 Pin'**
  String get pinLabel;

  /// No description provided for @unpinLabel.
  ///
  /// In en, this message translates to:
  /// **'📌 Unpin'**
  String get unpinLabel;

  /// No description provided for @favourite.
  ///
  /// In en, this message translates to:
  /// **'Favourite'**
  String get favourite;
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
      <String>['en', 'ru', 'uz'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
    case 'uz':
      return AppLocalizationsUz();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
