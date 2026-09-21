import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
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

  @override
  void initState() {
    super.initState();
    _router = buildRouter();
    ensureSeeded(widget.database, loadJson: widget.loadSeedJson).then((_) {
      if (mounted) setState(() => _ready = true);
    }).catchError((e) {
      if (mounted) setState(() => _error = e.toString());
    });
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
        ChangeNotifierProvider<ThemeController>(create: (_) => ThemeController()),
        ChangeNotifierProvider<LocaleController>(create: (_) => LocaleController()),
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
