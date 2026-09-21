import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:centavoo/theme.dart';
import 'package:centavoo/theme_controller.dart';
import 'package:centavoo/locale_controller.dart';
import 'package:centavoo/widgets/logo.dart';

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    final localeController = context.watch<LocaleController>();
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final barTint = (isDark ? darkSurfaces[7] : Colors.white).withValues(alpha: isDark ? 0.6 : 0.62);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
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
                            'CENTAVOO',
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
                              Text(isDark ? 'Tema claro' : 'Tema escuro'),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(value: 'export', child: Text('Exportar dados')),
                        const PopupMenuItem(value: 'import', child: Text('Importar dados')),
                      ];
                    },
                  ),
                ],
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
