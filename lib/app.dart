import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:centavoo/data/database.dart';
import 'package:centavoo/data/seed.dart';
import 'package:centavoo/l10n/arb/app_localizations.dart';
import 'package:centavoo/router.dart';
import 'package:centavoo/theme.dart';
import 'package:centavoo/theme_controller.dart';
import 'package:centavoo/locale_controller.dart';

class CentavooApp extends StatefulWidget {
  final AppDatabase database;
  final Future<String> Function() loadSeedJson;

  const CentavooApp({super.key, required this.database, required this.loadSeedJson});

  @override
  State<CentavooApp> createState() => _CentavooAppState();
}

class _CentavooAppState extends State<CentavooApp> {
  bool _ready = false;
  String? _error;
  late final GoRouter _router;
  Locale _locale = const Locale('pt', 'BR');
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _router = buildRouter();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLocale = prefs.getString(localePrefsKey);
      if (savedLocale == 'en') _locale = const Locale('en');
      final savedThemeMode = prefs.getString(themeModePrefsKey);
      if (savedThemeMode == 'dark') _themeMode = ThemeMode.dark;
      if (savedThemeMode == 'light') _themeMode = ThemeMode.light;
      await ensureSeeded(widget.database, loadJson: widget.loadSeedJson);
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return MaterialApp(
        home: Scaffold(body: Center(child: Text(_error!))),
      );
    }
    if (!_ready) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    return MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: widget.database),
        ChangeNotifierProvider<ThemeController>(create: (_) => ThemeController(mode: _themeMode)),
        ChangeNotifierProvider<LocaleController>(create: (_) => LocaleController(locale: _locale)),
      ],
      child: Consumer2<ThemeController, LocaleController>(
        builder: (context, themeController, localeController, _) => MaterialApp.router(
          routerConfig: _router,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: themeController.mode,
          locale: localeController.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
  }
}
