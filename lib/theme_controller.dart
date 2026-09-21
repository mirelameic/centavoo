import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const themeModePrefsKey = 'themeMode';

class ThemeController extends ChangeNotifier {
  ThemeMode mode;

  ThemeController({this.mode = ThemeMode.system});

  void toggle(Brightness current) {
    mode = current == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setString(themeModePrefsKey, mode == ThemeMode.dark ? 'dark' : 'light'));
  }
}
