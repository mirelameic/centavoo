import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:centavoo/l10n/arb/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:centavoo/models/category.dart';
import 'package:centavoo/models/transaction.dart';
import 'package:centavoo/screens/trip/time_tab.dart';
import 'package:centavoo/stats/stats.dart';

Transaction tx({
  required String id,
  String period = periodDuring,
  String? date,
  double amount = 0,
  String? categoryId,
}) {
  return Transaction(
    id: id,
    tripId: 't1',
    period: period,
    date: date,
    description: 'd',
    amount: amount,
    categoryId: categoryId,
    kind: kindExpense,
    isIof: false,
    splitCount: 1,
    createdAt: '2026-01-01T00:00:00Z',
  );
}

Category cat(String id, String name, {String color = '#0E8C6B'}) {
  return Category(id: id, tripId: 't1', name: name, color: color, sortOrder: 0);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  testWidgets('shows the empty state for both dated charts when there is no dated data', (tester) async {
    final stats = computeStats([], []);
    await tester.pumpWidget(MaterialApp(locale: const Locale('pt', 'BR'), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, 
      home: Scaffold(body: SingleChildScrollView(child: TimeTab(stats: stats, currency: 'BRL'))),
    ));
    expect(find.text('Sem gastos com data neste período.'), findsNWidgets(2));
  });

  testWidgets('shows the toggleable category legend for the day chart and toggles a series', (tester) async {
    final cats = [cat('c1', 'Hospedagem')];
    final txs = [tx(id: '1', date: '2026-05-01', amount: 100, categoryId: 'c1')];
    final stats = computeStats(txs, cats);

    await tester.pumpWidget(MaterialApp(locale: const Locale('pt', 'BR'), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, 
      home: Scaffold(body: SingleChildScrollView(child: TimeTab(stats: stats, currency: 'BRL'))),
    ));

    expect(find.text('Hospedagem'), findsOneWidget);
    final textBefore = tester.widget<Text>(find.text('Hospedagem'));
    expect(textBefore.style?.decoration, isNot(TextDecoration.lineThrough));

    await tester.tap(find.text('Hospedagem'));
    await tester.pump();

    final textAfter = tester.widget<Text>(find.text('Hospedagem'));
    expect(textAfter.style?.decoration, TextDecoration.lineThrough);
  });

  testWidgets('shows weekday short labels for all seven days', (tester) async {
    final stats = computeStats([], []);
    await tester.pumpWidget(MaterialApp(locale: const Locale('pt', 'BR'), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, 
      home: Scaffold(body: SingleChildScrollView(child: TimeTab(stats: stats, currency: 'BRL'))),
    ));

    for (final label in ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom']) {
      expect(find.text(label), findsOneWidget, reason: 'missing weekday label $label');
    }
  });

  testWidgets('shows the cumulative area chart when there is dated data', (tester) async {
    final txs = [tx(id: '1', date: '2026-05-01', amount: 100)];
    final stats = computeStats(txs, []);

    await tester.pumpWidget(MaterialApp(locale: const Locale('pt', 'BR'), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, 
      home: Scaffold(body: SingleChildScrollView(child: TimeTab(stats: stats, currency: 'BRL'))),
    ));

    expect(find.text('Nenhuma transação com data.'), findsNothing);
    expect(find.byType(LineChart), findsOneWidget);
  });
}
