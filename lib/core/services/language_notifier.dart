import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageNotifier extends ChangeNotifier {
  LanguageNotifier._();
  static final LanguageNotifier instance = LanguageNotifier._();

  static const _key = 'language_code';
  Locale _locale = const Locale('en');
  Locale get locale => _locale;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored != null) {
      _locale = Locale(stored);
    }
    notifyListeners();
  }

  void setLanguage(String languageCode) {
    if (_locale.languageCode == languageCode) return;
    _locale = Locale(languageCode);
    notifyListeners();
    SharedPreferences.getInstance().then((p) {
      p.setString(_key, languageCode);
    });
  }

  void toggleLanguage() {
    if (_locale.languageCode == 'en') {
      setLanguage('ru');
    } else if (_locale.languageCode == 'ru') {
      setLanguage('uz');
    } else {
      setLanguage('en');
    }
  }
}
