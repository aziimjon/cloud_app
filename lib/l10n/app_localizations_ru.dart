// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'MyCloud';

  @override
  String get welcomeBack => 'С возвращением,';

  @override
  String get home => 'Главная';

  @override
  String get files => 'Файлы';

  @override
  String get shared => 'Общие';

  @override
  String get profile => 'Профиль';

  @override
  String get recent => 'Недавние';

  @override
  String get myCloudStorage => 'My Cloud Storage';

  @override
  String get yourCloudStorage => 'Ваше облачное хранилище';

  @override
  String get used => 'использовано';

  @override
  String get total => 'всего';

  @override
  String get quickActions => 'Быстрые действия';

  @override
  String get myFiles => 'Мои файлы';

  @override
  String get favourites => 'Избранное';

  @override
  String get overallStats => 'Общая статистика';

  @override
  String get images => 'Изображения';

  @override
  String get videos => 'Видео';

  @override
  String get sharedByMe => 'Поделился я';

  @override
  String get sharedWithMe => 'Со мной';

  @override
  String get participants => 'участн.';

  @override
  String get folders => 'Папки';

  @override
  String get folder => 'Папка';

  @override
  String get createFolder => 'Создать папку';

  @override
  String get newFolder => 'Новая папка';

  @override
  String get folderName => 'Название папки';

  @override
  String get cancel => 'Отмена';

  @override
  String get create => 'Создать';

  @override
  String get save => 'Сохранить';

  @override
  String get delete => 'Удалить';

  @override
  String get rename => 'Переименовать';

  @override
  String get move => 'Переместить';

  @override
  String get download => 'Скачать';

  @override
  String get share => 'Поделиться';

  @override
  String get preview => 'Предпросмотр';

  @override
  String get details => 'Посмотреть детали';

  @override
  String get open => 'Открыть';

  @override
  String get addToFavourites => 'В избранное';

  @override
  String get removeFromFavourites => 'Убрать из избранного';

  @override
  String get deleteConfirm => 'Удалить?';

  @override
  String deleteConfirmMessage(String name) {
    return 'Вы уверены, что хотите удалить «$name»?\nЭто действие необратимо.';
  }

  @override
  String get successfullyMoved => 'Успешно перемещено';

  @override
  String fileSaved(String name) {
    return 'Файл сохранён: $name';
  }

  @override
  String get emptyFolder => 'Здесь пока пусто';

  @override
  String get emptyFolderSubtitle => 'Создайте папку или загрузите фото / видео';

  @override
  String get noFavourites => 'Нет избранных файлов';

  @override
  String get noFavouritesSubtitle => 'Нажмите звезду на файле чтобы добавить';

  @override
  String get filter => 'Фильтр';

  @override
  String get all => 'Все';

  @override
  String get photos => 'Фото';

  @override
  String get pinnedFolders => 'Закреплённые папки';

  @override
  String get maxPinnedFolders => 'Максимум 5 закреплённых папок';

  @override
  String get alreadyPinned => 'Папка уже закреплена';

  @override
  String get pin => 'Закрепить';

  @override
  String get unpin => 'Открепить';

  @override
  String get unpinFolder => 'Открепить папку?';

  @override
  String get shareViaLink => 'Share via link';

  @override
  String get shareByPhone => 'По номеру';

  @override
  String get shareByLink => 'По ссылке';

  @override
  String get linkName => 'Link name';

  @override
  String get generate => 'Generate';

  @override
  String get generatedLink => 'Generated link';

  @override
  String get linkCopied => 'Ссылка скопирована';

  @override
  String get copy => 'Скопировать';

  @override
  String get copyLink => 'Скопировать ссылку';

  @override
  String get shareSuccess => 'Поделились успешно';

  @override
  String get addAtLeastOnePhone => 'Добавьте хотя бы один номер телефона';

  @override
  String get enter9Digits => 'Введите 9 цифр номера';

  @override
  String get enterLinkName => 'Введите название ссылки';

  @override
  String get fileDetails => 'Сведения о файле';

  @override
  String get folderDetails => 'Сведения о папке';

  @override
  String get fileName => 'Название';

  @override
  String get fileSize => 'Размер';

  @override
  String get createdAt => 'Дата создания';

  @override
  String get capturedAt => 'Снято в';

  @override
  String get totalSize => 'Общий размер';

  @override
  String get fileCount => 'Файлы';

  @override
  String get folderCount => 'Папки';

  @override
  String get shareRequests => 'Share Requests';

  @override
  String get shareRequestsSubtitle => 'Управление ссылками и доступами';

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
  String get accessApproved => 'Доступ одобрен';

  @override
  String get accessRejected => 'Доступ отклонён';

  @override
  String get noShareRequests => 'Нет share requests';

  @override
  String get noShareRequestsSubtitle =>
      'Поделитесь файлами по ссылке и они появятся здесь';

  @override
  String get personalData => 'ЛИЧНЫЕ ДАННЫЕ';

  @override
  String get changeName => 'Изменить имя';

  @override
  String get changePhone => 'Изменить телефон';

  @override
  String get changePassword => 'Изменить пароль';

  @override
  String get newName => 'Новое имя';

  @override
  String get newPhone => 'Новый номер';

  @override
  String get oldPassword => 'Старый пароль';

  @override
  String get newPassword => 'Новый пароль';

  @override
  String get confirmPassword => 'Подтвердить пароль';

  @override
  String get passwordsDoNotMatch => 'Пароли не совпадают';

  @override
  String get passwordTooShort => 'Минимум 8 символов';

  @override
  String get nameUpdated => 'Имя обновлено';

  @override
  String get phoneUpdated => 'Телефон обновлён';

  @override
  String get passwordChanged => 'Пароль изменён';

  @override
  String get avatarUpdated => 'Аватар обновлён';

  @override
  String get storage => 'Хранилище';

  @override
  String get language => 'Язык';

  @override
  String get theme => 'ОФОРМЛЕНИЕ';

  @override
  String get light => 'Светлая';

  @override
  String get dark => 'Тёмная';

  @override
  String get logout => 'Выйти из аккаунта';

  @override
  String get logoutConfirm => 'Выход';

  @override
  String get logoutConfirmMessage =>
      'Вы уверены, что хотите выйти из аккаунта?';

  @override
  String get refresh => 'Обновить';

  @override
  String get retry => 'Повторить';

  @override
  String selected(int count) {
    return 'Выбрано: $count';
  }

  @override
  String get selectAll => 'Все';

  @override
  String get deselectAll => 'Снять все';

  @override
  String get uploadFiles => 'Загрузить файлы';

  @override
  String get chooseLanguage => 'Выберите язык';

  @override
  String get home_breadcrumb => 'Главная';

  @override
  String get favourites_breadcrumb => 'Избранное';

  @override
  String selectedCount(int count) {
    return 'Выбрано: $count';
  }

  @override
  String get addedToFavourites => 'Добавлено в избранное';

  @override
  String get couldNotOpenImage => 'Не удалось открыть изображение';

  @override
  String get couldNotOpenVideo => 'Не удалось открыть видео';

  @override
  String get noSharedWithMe => 'Никто не делился файлами';

  @override
  String get noSharedWithMeSubtitle =>
      'Когда кто-то поделится файлом — они появятся здесь';

  @override
  String get noSharedByMe => 'Вы ещё ни с кем не делились';

  @override
  String get noSharedByMeSubtitle =>
      'Нажмите кнопку шаринга чтобы поделиться файлами';

  @override
  String get noSharedItems => 'Нет расшаренных элементов';

  @override
  String sharedWithLabel(String name) {
    return 'Для $name';
  }

  @override
  String get revokeAccess => 'Отозвать доступ';

  @override
  String revokeAccessConfirm(String name) {
    return 'Отозвать доступ к «$name»?';
  }

  @override
  String get revoke => 'Отозвать';

  @override
  String filesCount(int count) {
    return '$count файлов';
  }

  @override
  String get openLabel => 'Открыть';

  @override
  String get usersTab => 'Пользователи';

  @override
  String get sharedItemsTab => 'Расшаренные';

  @override
  String get newNameHint => 'Новое название';

  @override
  String deleteItems(int count) {
    return '$count элементов';
  }

  @override
  String get pinLabel => '📌 Закрепить';

  @override
  String get unpinLabel => '📌 Открепить';

  @override
  String get favourite => 'Избранное';
}
