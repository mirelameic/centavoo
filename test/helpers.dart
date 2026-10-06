import 'package:flutter/material.dart';
import 'package:centavoo/l10n/arb/app_localizations.dart';

const ptBr = Locale('pt', 'BR');

MaterialApp ptApp({required Widget home, ThemeData? theme}) {
  return MaterialApp(
    locale: ptBr,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: theme,
    home: home,
  );
}

MaterialApp ptRouterApp({required RouterConfig<Object> routerConfig, ThemeData? theme, ThemeData? darkTheme}) {
  return MaterialApp.router(
    locale: ptBr,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: theme,
    darkTheme: darkTheme,
    routerConfig: routerConfig,
  );
}
