import 'package:flutter/material.dart';
import 'package:centavoo/format.dart' as format;

class LocaleController extends ChangeNotifier {
  Locale locale;

  LocaleController({this.locale = const Locale('pt', 'BR')}) {
    format.appLocale = locale.languageCode == 'en' ? 'en' : 'pt_BR';
  }

  void setLanguage(String code) {
    locale = code == 'en' ? const Locale('en') : const Locale('pt', 'BR');
    format.appLocale = code == 'en' ? 'en' : 'pt_BR';
    notifyListeners();
  }
}
