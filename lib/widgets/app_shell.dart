import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:centavoo/data/backup.dart';
import 'package:centavoo/data/database.dart';
import 'package:centavoo/l10n/arb/app_localizations.dart';
import 'package:centavoo/theme.dart';
import 'package:centavoo/theme_controller.dart';
import 'package:centavoo/locale_controller.dart';
import 'package:centavoo/widgets/logo.dart';

Future<void> _handleExport(BuildContext context) async {
  final db = context.read<AppDatabase>();
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  try {
    final json = await exportBackupJson(db);
    final fileName = 'centavoo-backup-${DateTime.now().toIso8601String().substring(0, 10)}.json';
    final savedUri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(json)),
      mimeType: 'application/json',
    );
    if (savedUri == null) return;
    messenger.showSnackBar(SnackBar(content: Text(l10n.backupExportedOk)));
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.backupExportError)));
  }
}

Future<void> _handleImport(BuildContext context) async {
  final db = context.read<AppDatabase>();
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  try {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['json']);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    await importBackupJson(db, utf8.decode(bytes));
    messenger.showSnackBar(SnackBar(content: Text(l10n.backupImportedOk)));
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.backupImportError)));
  }
}

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final themeController = context.watch<ThemeController>();
    final localeController = context.watch<LocaleController>();
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final barTint = (isDark ? darkSurfaces[7] : Colors.white).withValues(alpha: isDark ? 0.6 : 0.8);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: isDark ? null : const Border(bottom: BorderSide(color: lightDivider)),
          ),
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: AppBar(
                backgroundColor: barTint,
                automaticallyImplyLeading: false,
                titleSpacing: 16,
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Logo(size: 26),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              l10n.appTitle.toUpperCase(),
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                              style: unboundedStyle(
                                weight: FontWeight.w700,
                                letterSpacing: 0.4,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      tooltip: 'menu',
                      padding: const EdgeInsets.all(6),
                      onSelected: (value) {
                        switch (value) {
                          case 'lang_pt':
                            localeController.setLanguage('pt');
                          case 'lang_en':
                            localeController.setLanguage('en');
                          case 'theme':
                            themeController.toggle(brightness);
                          case 'export':
                            _handleExport(context);
                          case 'import':
                            _handleImport(context);
                        }
                      },
                      itemBuilder: (context) {
                        final lang = localeController.locale.languageCode;
                        return [
                          _langMenuItem(value: 'lang_pt', label: 'Português', selected: lang == 'pt'),
                          _langMenuItem(value: 'lang_en', label: 'English', selected: lang == 'en'),
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: 'theme',
                            child: Row(
                              children: [
                                Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, size: 18),
                                const SizedBox(width: 12),
                                Text(isDark ? l10n.themeLight : l10n.themeDark),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem(value: 'export', child: Text(l10n.menuExport)),
                          PopupMenuItem(value: 'import', child: Text(l10n.menuImport)),
                        ];
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: child,
    );
  }
}

PopupMenuItem<String> _langMenuItem({required String value, required String label, required bool selected}) {
  return PopupMenuItem(
    value: value,
    child: Row(
      children: [
        SizedBox(width: 18, child: selected ? const Icon(Icons.check, size: 18) : null),
        const SizedBox(width: 12),
        Text(label),
      ],
    ),
  );
}
