import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:centavoo/models/transaction.dart';
import 'package:centavoo/widgets/trip/tx_row.dart';

Transaction tx({
  String period = periodDuring,
  String? date,
  String description = '',
  double amount = 0,
  String? categoryId,
  String kind = kindExpense,
  bool isIof = false,
  int splitCount = 1,
}) {
  return Transaction(
    id: 'tx1',
    tripId: 't1',
    period: period,
    date: date,
    description: description,
    amount: amount,
    categoryId: categoryId,
    kind: kind,
    isIof: isIof,
    splitCount: splitCount,
    createdAt: '2026-01-01T00:00:00Z',
  );
}

void main() {
  testWidgets('shows description and formatted amount', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TxRow(tx: tx(description: 'Jantar', amount: 100), cities: const {}, currency: 'BRL'),
      ),
    ));

    expect(find.text('Jantar'), findsOneWidget);
    expect(find.text('R\$ 100,00'), findsOneWidget);
  });

  testWidgets('shows the split marker and the full amount when split', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TxRow(tx: tx(description: 'Aluguel', amount: 300, splitCount: 3), cities: const {}, currency: 'BRL'),
      ),
    ));

    expect(find.textContaining('÷3'), findsOneWidget);
    expect(find.text('integral R\$ 300,00'), findsOneWidget);
  });

  testWidgets('shows the Reembolso badge for refunds and hides meta when showMeta is false', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TxRow(tx: tx(description: 'Devolução', amount: -20, kind: kindRefund), cities: const {}, currency: 'BRL'),
      ),
    ));
    expect(find.text('Reembolso'), findsOneWidget);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TxRow(
          tx: tx(description: 'Devolução', amount: -20, kind: kindRefund),
          cities: const {},
          currency: 'BRL',
          showMeta: false,
        ),
      ),
    ));
    expect(find.text('Reembolso'), findsNothing);
  });

  testWidgets('shows a checkbox and highlights the row in selecting mode', (tester) async {
    var toggled = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TxRow(
          tx: tx(description: 'Jantar', amount: 100),
          cities: const {},
          currency: 'BRL',
          selecting: true,
          onToggleSelect: () => toggled = true,
        ),
      ),
    ));

    expect(find.byType(Checkbox), findsOneWidget);
    await tester.tap(find.text('Jantar'));
    expect(toggled, isTrue);
  });

  testWidgets('shows edit/delete menu only when callbacks are provided', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TxRow(tx: tx(description: 'Jantar', amount: 100), cities: const {}, currency: 'BRL'),
      ),
    ));
    expect(find.byIcon(Icons.more_vert), findsNothing);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TxRow(
          tx: tx(description: 'Jantar', amount: 100),
          cities: const {},
          currency: 'BRL',
          onEdit: () {},
          onDelete: () {},
        ),
      ),
    ));
    expect(find.byIcon(Icons.more_vert), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Excluir'), findsOneWidget);
  });
}
