// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'MyCloud';

  @override
  String get welcomeBack => 'Welcome back,';

  @override
  String get home => 'Home';

  @override
  String get files => 'Files';

  @override
  String get shared => 'Shared';

  @override
  String get profile => 'Profile';

  @override
  String get recent => 'Recent';

  @override
  String get myCloudStorage => 'My Cloud Storage';

  @override
  String get yourCloudStorage => 'Your cloud storage';

  @override
  String get used => 'used';

  @override
  String get total => 'total';

  @override
  String get quickActions => 'Quick Actions';

  @override
  String get myFiles => 'My Files';

  @override
  String get favourites => 'Favourites';

  @override
  String get overallStats => 'Overall Statistics';

  @override
  String get images => 'Images';

  @override
  String get videos => 'Videos';

  @override
  String get sharedByMe => 'Shared by me';

  @override
  String get sharedWithMe => 'Shared with me';

  @override
  String get participants => 'participants';

  @override
  String get folders => 'Folders';

  @override
  String get folder => 'Folder';

  @override
  String get createFolder => 'Create Folder';

  @override
  String get newFolder => 'New Folder';

  @override
  String get folderName => 'Folder name';

  @override
  String get cancel => 'Cancel';

  @override
  String get create => 'Create';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get rename => 'Rename';

  @override
  String get move => 'Move';

  @override
  String get download => 'Download';

  @override
  String get share => 'Share';

  @override
  String get preview => 'Preview';

  @override
  String get details => 'Details';

  @override
  String get open => 'Open';

  @override
  String get addToFavourites => 'Add to favourites';

  @override
  String get removeFromFavourites => 'Remove from favourites';

  @override
  String get deleteConfirm => 'Delete?';

  @override
  String deleteConfirmMessage(String name) {
    return 'Are you sure you want to delete \"$name\"?\nThis action is irreversible.';
  }

  @override
  String get successfullyMoved => 'Successfully moved';

  @override
  String fileSaved(String name) {
    return 'File saved: $name';
  }

  @override
  String get emptyFolder => 'Nothing here yet';

  @override
  String get emptyFolderSubtitle => 'Create a folder or upload photos / videos';

  @override
  String get noFavourites => 'No favourite files';

  @override
  String get noFavouritesSubtitle => 'Tap star on a file to add it';

  @override
  String get filter => 'Filter';

  @override
  String get all => 'All';

  @override
  String get photos => 'Photos';

  @override
  String get pinnedFolders => 'Pinned folders';

  @override
  String get maxPinnedFolders => 'Maximum 5 pinned folders';

  @override
  String get alreadyPinned => 'Folder already pinned';

  @override
  String get pin => 'Pin';

  @override
  String get unpin => 'Unpin';

  @override
  String get unpinFolder => 'Unpin folder?';

  @override
  String get shareViaLink => 'Share via link';

  @override
  String get shareByPhone => 'By phone';

  @override
  String get shareByLink => 'By link';

  @override
  String get linkName => 'Link name';

  @override
  String get generate => 'Generate';

  @override
  String get generatedLink => 'Generated link';

  @override
  String get linkCopied => 'Link copied';

  @override
  String get copy => 'Copy';

  @override
  String get copyLink => 'Copy link';

  @override
  String get shareSuccess => 'Shared successfully';

  @override
  String get addAtLeastOnePhone => 'Add at least one phone number';

  @override
  String get enter9Digits => 'Enter 9 digits';

  @override
  String get enterLinkName => 'Enter link name';

  @override
  String get fileDetails => 'File details';

  @override
  String get folderDetails => 'Folder details';

  @override
  String get fileName => 'Name';

  @override
  String get fileSize => 'Size';

  @override
  String get createdAt => 'Created at';

  @override
  String get capturedAt => 'Captured at';

  @override
  String get totalSize => 'Total size';

  @override
  String get fileCount => 'Files';

  @override
  String get folderCount => 'Folders';

  @override
  String get shareRequests => 'Share Requests';

  @override
  String get shareRequestsSubtitle => 'Manage links and access';

  @override
  String get shareRequestDetails => 'Share request details';

  @override
  String get request => 'Request';

  @override
  String get linkNameLabel => 'LINK NAME';

  @override
  String get shareLinkLabel => 'SHARE LINK';

  @override
  String get permissionRequests => 'PERMISSION REQUESTS';

  @override
  String get pending => 'Pending';

  @override
  String get approved => 'Approved';

  @override
  String get rejected => 'Rejected';

  @override
  String get review => 'Review';

  @override
  String get reviewAccessRequest => 'Review access request';

  @override
  String get reviewAccessRequestSubtitle =>
      'Choose whether this user should get access.';

  @override
  String get reject => 'Reject';

  @override
  String get approve => 'Approve';

  @override
  String get accessApproved => 'Access approved';

  @override
  String get accessRejected => 'Access rejected';

  @override
  String get noShareRequests => 'No share requests';

  @override
  String get noShareRequestsSubtitle =>
      'Share files via link and they will appear here';

  @override
  String get personalData => 'PERSONAL DATA';

  @override
  String get changeName => 'Change name';

  @override
  String get changePhone => 'Change phone';

  @override
  String get changePassword => 'Change password';

  @override
  String get newName => 'New name';

  @override
  String get newPhone => 'New number';

  @override
  String get oldPassword => 'Old password';

  @override
  String get newPassword => 'New password';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get passwordTooShort => 'Minimum 8 characters';

  @override
  String get nameUpdated => 'Name updated';

  @override
  String get phoneUpdated => 'Phone updated';

  @override
  String get passwordChanged => 'Password changed';

  @override
  String get avatarUpdated => 'Avatar updated';

  @override
  String get storage => 'Storage';

  @override
  String get language => 'Language';

  @override
  String get theme => 'APPEARANCE';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get logout => 'Sign out';

  @override
  String get logoutConfirm => 'Sign out';

  @override
  String get logoutConfirmMessage => 'Are you sure you want to sign out?';

  @override
  String get refresh => 'Refresh';

  @override
  String get retry => 'Retry';

  @override
  String selected(int count) {
    return 'Selected: $count';
  }

  @override
  String get selectAll => 'All';

  @override
  String get deselectAll => 'Deselect all';

  @override
  String get uploadFiles => 'Upload files';

  @override
  String get chooseLanguage => 'Choose language';

  @override
  String get home_breadcrumb => 'Home';

  @override
  String get favourites_breadcrumb => 'Favourites';

  @override
  String selectedCount(int count) {
    return 'Selected: $count';
  }

  @override
  String get addedToFavourites => 'Added to favourites';

  @override
  String get couldNotOpenImage => 'Could not open image';

  @override
  String get couldNotOpenVideo => 'Could not open video';

  @override
  String get noSharedWithMe => 'No one has shared files';

  @override
  String get noSharedWithMeSubtitle =>
      'When someone shares a file — it will appear here';

  @override
  String get noSharedByMe => 'You haven\'t shared with anyone yet';

  @override
  String get noSharedByMeSubtitle => 'Tap the share button to share files';

  @override
  String get noSharedItems => 'No shared items';

  @override
  String sharedWithLabel(String name) {
    return 'For $name';
  }

  @override
  String get revokeAccess => 'Revoke access';

  @override
  String revokeAccessConfirm(String name) {
    return 'Revoke access to \"$name\"?';
  }

  @override
  String get revoke => 'Revoke';

  @override
  String filesCount(int count) {
    return '$count files';
  }

  @override
  String get openLabel => 'Open';

  @override
  String get usersTab => 'Users';

  @override
  String get sharedItemsTab => 'Shared items';

  @override
  String get newNameHint => 'New name';

  @override
  String deleteItems(int count) {
    return '$count items';
  }

  @override
  String get pinLabel => '📌 Pin';

  @override
  String get unpinLabel => '📌 Unpin';

  @override
  String get favourite => 'Favourite';

  @override
  String get syncFolderName => '📱 Sync';

  @override
  String syncStatusUploading(int uploaded, int total) {
    return 'Uploading $uploaded of $total';
  }

  @override
  String syncStatusWaiting(int count) {
    return 'Waiting to sync: $count';
  }

  @override
  String get syncStatusComplete => 'Sync complete';

  @override
  String syncStatusErrors(int count) {
    return '$count errors';
  }

  @override
  String get syncSettingsTitle => 'Auto Sync';

  @override
  String get syncEnableToggle => 'Enable auto sync';

  @override
  String get syncWifiOnly => 'Wi-Fi only';

  @override
  String get syncNowButton => 'Sync now';

  @override
  String get syncResetButton => 'Reset queue';

  @override
  String get syncFolderReadOnly =>
      'This is your Sync folder. Files here are managed automatically.';

  @override
  String get syncResetConfirmTitle => 'Reset queue?';

  @override
  String get syncResetConfirmMessage =>
      'All records will be deleted. The app will re-scan the gallery after that.';

  @override
  String get syncResetConfirmButton => 'Reset';

  @override
  String get syncAutoUpload => 'Automatically upload photos and videos';

  @override
  String get syncNoMobileData => 'Do not sync over mobile data';

  @override
  String get syncStatusTitle => 'Sync status';

  @override
  String get syncStatusPending => 'Pending';

  @override
  String get syncStatusUploading2 => 'Uploading';

  @override
  String get syncStatusDone => 'Done';

  @override
  String get syncStatusFailed => 'Errors';

  @override
  String get syncStop => 'Stop';
}
