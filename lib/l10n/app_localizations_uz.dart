// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Uzbek (`uz`).
class AppLocalizationsUz extends AppLocalizations {
  AppLocalizationsUz([String locale = 'uz']) : super(locale);

  @override
  String get appName => 'MyCloud';

  @override
  String get welcomeBack => 'Xush kelibsiz,';

  @override
  String get home => 'Bosh sahifa';

  @override
  String get files => 'Fayllar';

  @override
  String get shared => 'Ulashilgan';

  @override
  String get profile => 'Profil';

  @override
  String get recent => 'So\'nggi';

  @override
  String get myCloudStorage => 'My Cloud Storage';

  @override
  String get yourCloudStorage => 'Bulut xotirangiz';

  @override
  String get used => 'ishlatilgan';

  @override
  String get total => 'jami';

  @override
  String get quickActions => 'Tezkor amallar';

  @override
  String get myFiles => 'Mening fayllarim';

  @override
  String get favourites => 'Sevimlilar';

  @override
  String get overallStats => 'Umumiy statistika';

  @override
  String get images => 'Rasmlar';

  @override
  String get videos => 'Videolar';

  @override
  String get sharedByMe => 'Men ulashganlar';

  @override
  String get sharedWithMe => 'Menga ulashilgan';

  @override
  String get participants => 'ishtirokchi';

  @override
  String get folders => 'Papkalar';

  @override
  String get folder => 'Papka';

  @override
  String get createFolder => 'Papka yaratish';

  @override
  String get newFolder => 'Yangi papka';

  @override
  String get folderName => 'Papka nomi';

  @override
  String get cancel => 'Bekor qilish';

  @override
  String get create => 'Yaratish';

  @override
  String get save => 'Saqlash';

  @override
  String get delete => 'O\'chirish';

  @override
  String get rename => 'Nomini o\'zgartirish';

  @override
  String get move => 'Ko\'chirish';

  @override
  String get download => 'Yuklab olish';

  @override
  String get share => 'Ulashish';

  @override
  String get preview => 'Ko\'rib chiqish';

  @override
  String get details => 'Batafsil';

  @override
  String get open => 'Ochish';

  @override
  String get addToFavourites => 'Sevimlilarga qo\'shish';

  @override
  String get removeFromFavourites => 'Sevimlilardan olib tashlash';

  @override
  String get deleteConfirm => 'O\'chirilsinmi?';

  @override
  String deleteConfirmMessage(String name) {
    return '\"$name\" ni o\'chirishni xohlaysizmi?\nBu amalni qaytarib bo\'lmaydi.';
  }

  @override
  String get successfullyMoved => 'Muvaffaqiyatli ko\'chirildi';

  @override
  String fileSaved(String name) {
    return 'Fayl saqlandi: $name';
  }

  @override
  String get emptyFolder => 'Hozircha bo\'sh';

  @override
  String get emptyFolderSubtitle => 'Papka yarating yoki rasm/video yuklang';

  @override
  String get noFavourites => 'Sevimli fayllar yo\'q';

  @override
  String get noFavouritesSubtitle =>
      'Qo\'shish uchun fayl ustidagi yulduzni bosing';

  @override
  String get filter => 'Filtr';

  @override
  String get all => 'Barchasi';

  @override
  String get photos => 'Rasmlar';

  @override
  String get pinnedFolders => 'Mahkamlangan papkalar';

  @override
  String get maxPinnedFolders => 'Maksimal 5 ta mahkamlangan papka';

  @override
  String get alreadyPinned => 'Papka allaqachon mahkamlangan';

  @override
  String get pin => 'Mahkamlash';

  @override
  String get unpin => 'Mahkamni olib tashlash';

  @override
  String get unpinFolder => 'Papkani olib tashlash?';

  @override
  String get shareViaLink => 'Havola orqali ulashish';

  @override
  String get shareByPhone => 'Telefon orqali';

  @override
  String get shareByLink => 'Havola orqali';

  @override
  String get linkName => 'Havola nomi';

  @override
  String get generate => 'Yaratish';

  @override
  String get generatedLink => 'Yaratilgan havola';

  @override
  String get linkCopied => 'Havola nusxalandi';

  @override
  String get copy => 'Nusxalash';

  @override
  String get copyLink => 'Havolani nusxalash';

  @override
  String get shareSuccess => 'Muvaffaqiyatli ulashildi';

  @override
  String get addAtLeastOnePhone => 'Kamida bitta telefon raqam qo\'shing';

  @override
  String get enter9Digits => '9 ta raqam kiriting';

  @override
  String get enterLinkName => 'Havola nomini kiriting';

  @override
  String get fileDetails => 'Fayl ma\'lumotlari';

  @override
  String get folderDetails => 'Papka ma\'lumotlari';

  @override
  String get fileName => 'Nomi';

  @override
  String get fileSize => 'Hajmi';

  @override
  String get createdAt => 'Yaratilgan vaqt';

  @override
  String get capturedAt => 'Suratga olingan vaqt';

  @override
  String get totalSize => 'Umumiy hajm';

  @override
  String get fileCount => 'Fayllar';

  @override
  String get folderCount => 'Papkalar';

  @override
  String get shareRequests => 'Ulashish so\'rovlari';

  @override
  String get shareRequestsSubtitle => 'Havolalar va ruxsatlarni boshqarish';

  @override
  String get shareRequestDetails => 'Ulashish so\'rovi tafsilotlari';

  @override
  String get request => 'So\'rov';

  @override
  String get linkNameLabel => 'HAVOLA NOMI';

  @override
  String get shareLinkLabel => 'ULASHISH HAVOLASI';

  @override
  String get permissionRequests => 'RUXSAT SO\'ROVLARI';

  @override
  String get pending => 'Kutilmoqda';

  @override
  String get approved => 'Tasdiqlangan';

  @override
  String get rejected => 'Rad etilgan';

  @override
  String get review => 'Ko\'rib chiqish';

  @override
  String get reviewAccessRequest => 'Ruxsat so\'rovini ko\'rib chiqish';

  @override
  String get reviewAccessRequestSubtitle =>
      'Bu foydalanuvchi ulashilgan kontentga kirish huquqiga ega bo\'lishi kerakmi?';

  @override
  String get reject => 'Rad etish';

  @override
  String get approve => 'Tasdiqlash';

  @override
  String get accessApproved => 'Ruxsat berildi';

  @override
  String get accessRejected => 'Ruxsat rad etildi';

  @override
  String get noShareRequests => 'Ulashish so\'rovlari yo\'q';

  @override
  String get noShareRequestsSubtitle =>
      'Fayllarni havola orqali ulashing va ular bu yerda paydo bo\'ladi';

  @override
  String get personalData => 'SHAXSIY MA\'LUMOTLAR';

  @override
  String get changeName => 'Ismni o\'zgartirish';

  @override
  String get changePhone => 'Telefon raqamini o\'zgartirish';

  @override
  String get changePassword => 'Parolni o\'zgartirish';

  @override
  String get newName => 'Yangi ism';

  @override
  String get newPhone => 'Yangi raqam';

  @override
  String get oldPassword => 'Eski parol';

  @override
  String get newPassword => 'Yangi parol';

  @override
  String get confirmPassword => 'Parolni tasdiqlash';

  @override
  String get passwordsDoNotMatch => 'Parollar mos kelmaydi';

  @override
  String get passwordTooShort => 'Kamida 8 ta belgi';

  @override
  String get nameUpdated => 'Ism yangilandi';

  @override
  String get phoneUpdated => 'Telefon yangilandi';

  @override
  String get passwordChanged => 'Parol o\'zgartirildi';

  @override
  String get avatarUpdated => 'Avatar yangilandi';

  @override
  String get storage => 'Xotira';

  @override
  String get language => 'Til';

  @override
  String get theme => 'KO\'RINISH';

  @override
  String get light => 'Yorug\'';

  @override
  String get dark => 'Qorong\'u';

  @override
  String get logout => 'Hisobdan chiqish';

  @override
  String get logoutConfirm => 'Chiqish';

  @override
  String get logoutConfirmMessage => 'Hisobdan chiqishni xohlaysizmi?';

  @override
  String get refresh => 'Yangilash';

  @override
  String get retry => 'Qayta urinish';

  @override
  String selected(int count) {
    return 'Tanlangan: $count';
  }

  @override
  String get selectAll => 'Barchasi';

  @override
  String get deselectAll => 'Barchasini bekor qilish';

  @override
  String get uploadFiles => 'Fayllarni yuklash';

  @override
  String get chooseLanguage => 'Tilni tanlang';

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
  String get syncFolderName => '📱 Sinxronizatsiya';

  @override
  String syncStatusUploading(int uploaded, int total) {
    return '$total tadan $uploaded yuklandi';
  }

  @override
  String syncStatusWaiting(int count) {
    return 'Sinxronizatsiya kutilmoqda: $count';
  }

  @override
  String get syncStatusComplete => 'Sinxronizatsiya tugadi';

  @override
  String syncStatusErrors(int count) {
    return '$count ta xato';
  }

  @override
  String get syncSettingsTitle => 'Avtomatik sinxronizatsiya';

  @override
  String get syncEnableToggle => 'Avtomatik sinxronizatsiyani yoqish';

  @override
  String get syncWifiOnly => 'Faqat Wi-Fi orqali';

  @override
  String get syncNowButton => 'Hozir sinxronlashtirish';

  @override
  String get syncResetButton => 'Navbatni tozalash';

  @override
  String get syncFolderReadOnly =>
      'Bu sinxronizatsiya papkasi. Fayllar avtomatik boshqariladi.';

  @override
  String get syncResetConfirmTitle => 'Navbatni tozalash?';

  @override
  String get syncResetConfirmMessage =>
      'Barcha yozuvlar o\'chiriladi. Ilova galereyani qaytadan skanerlaydi.';

  @override
  String get syncResetConfirmButton => 'Tozalash';

  @override
  String get syncAutoUpload => 'Rasmlar va videolarni avtomatik yuklash';

  @override
  String get syncNoMobileData => 'Mobil internet orqali sinxronlamaslik';

  @override
  String get syncStatusTitle => 'Sinxronizatsiya holati';

  @override
  String get syncStatusPending => 'Kutilmoqda';

  @override
  String get syncStatusUploading2 => 'Yuklanmoqda';

  @override
  String get syncStatusDone => 'Tayyor';

  @override
  String get syncStatusFailed => 'Xatolar';

  @override
  String get syncStop => 'To\'xtatish';
}
