import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n/app_localizations.dart';

class LocaleProvider with ChangeNotifier {
  // Always initialize with Japanese
  Locale _locale = const Locale('ja');

  Locale get locale => _locale;

  LocaleProvider() {
    // Explicitly clear any stored locale and set to Japanese on startup
    _resetToJapanese();
  }

  void setLocale(Locale locale) async {
    if (!AppLocalizations.delegate.isSupported(locale)) return;
    _locale = locale;
    notifyListeners();
    // Don't store in SharedPreferences anymore
  }

  void clearLocale() {
    _resetToJapanese();
  }

  Future<void> _resetToJapanese() async {
    _locale = const Locale('ja');
    final prefs = await SharedPreferences.getInstance();
    // Clear any stored locale preference
    await prefs.remove('locale');
    notifyListeners();
  }

  // Remove _loadLocale method as we don't want to load stored preferences
}
