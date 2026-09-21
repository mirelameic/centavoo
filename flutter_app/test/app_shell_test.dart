import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:centavoo/theme.dart';
import 'package:centavoo/theme_controller.dart';
import 'package:centavoo/locale_controller.dart';
import 'package:centavoo/widgets/app_shell.dart';

Widget wrap(Widget child, {ThemeController? themeController}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ThemeController>.value(value: themeController ?? ThemeController()),
      ChangeNotifierProvider<LocaleController>.value(value: LocaleController()),
    ],
    child: Consumer<ThemeController>(
      builder: (context, controller, _) => MaterialApp(
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: controller.mode,
        home: AppShell(child: child),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the CENTAVOO wordmark and the child content', (tester) async {
    await tester.pumpWidget(wrap(const Text('body content')));
    expect(find.text('CENTAVOO'), findsOneWidget);
    expect(find.text('body content'), findsOneWidget);
  });

  testWidgets('the overflow menu shows language options and a theme toggle entry', (tester) async {
    await tester.pumpWidget(wrap(const SizedBox.shrink()));
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Português'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Tema escuro'), findsOneWidget);
    expect(find.text('Exportar dados'), findsOneWidget);
    expect(find.text('Importar dados'), findsOneWidget);
  });

  testWidgets('tapping the theme entry switches the icon and label', (tester) async {
    final controller = ThemeController(mode: ThemeMode.dark);
    await tester.pumpWidget(wrap(const SizedBox.shrink(), themeController: controller));

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Tema claro'), findsOneWidget);

    await tester.tap(find.text('Tema claro'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Tema escuro'), findsOneWidget);
  });

  testWidgets('tapping a language entry switches the selected language', (tester) async {
    await tester.pumpWidget(wrap(const SizedBox.shrink()));

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check), findsOneWidget);

    final englishRow = find.ancestor(of: find.text('English'), matching: find.byType(Row)).first;
    expect(find.descendant(of: englishRow, matching: find.byIcon(Icons.check)), findsOneWidget);
  });
}
