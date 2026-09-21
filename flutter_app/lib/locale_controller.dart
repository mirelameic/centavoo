import 'package:flutter/material.dart';

class LocaleController extends ChangeNotifier {
  Locale locale;

  LocaleController({this.locale = const Locale('pt', 'BR')});

  void setLanguage(String code) {
    locale = code == 'en' ? const Locale('en') : const Locale('pt', 'BR');
    notifyListeners();
  }
}
