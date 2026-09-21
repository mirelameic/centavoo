import 'package:flutter/material.dart';

class ThemeController extends ChangeNotifier {
  ThemeMode mode;

  ThemeController({this.mode = ThemeMode.system});

  void toggle(Brightness current) {
    mode = current == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }
}
