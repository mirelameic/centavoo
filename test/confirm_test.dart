import 'package:flutter/material.dart';
import 'package:centavoo/l10n/arb/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:centavoo/confirm.dart';

Future<void> pump(WidgetTester tester, VoidCallback onConfirm) async {
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('pt', 'BR'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => ElevatedButton(
        onPressed: () => confirmDelete(context, 'Excluir isso?', onConfirm),
        child: const Text('open'),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tapping Cancelar does not run the confirm callback', (tester) async {
    var called = false;
    await pump(tester, () => called = true);

    expect(find.text('Excluir isso?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(called, isFalse);
    expect(find.text('Excluir isso?'), findsNothing);
  });

  testWidgets('tapping Excluir runs the confirm callback', (tester) async {
    var called = false;
    await pump(tester, () => called = true);

    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();

    expect(called, isTrue);
  });

  testWidgets('dismissing the dialog by tapping outside does not run the callback', (tester) async {
    var called = false;
    await pump(tester, () => called = true);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(called, isFalse);
    expect(find.text('Excluir isso?'), findsNothing);
  });
}
