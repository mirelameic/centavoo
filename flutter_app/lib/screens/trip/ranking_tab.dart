import 'package:flutter/material.dart';
import 'package:centavoo/models/category.dart';
import 'package:centavoo/models/transaction.dart';
import 'package:centavoo/stats/stats.dart';
import 'package:centavoo/widgets/trip/primitives.dart';
import 'package:centavoo/widgets/trip/tx_row.dart';

class RankingTab extends StatelessWidget {
  final List<Transaction> txs;
  final Map<String, Category> catById;
  final Map<String, String> cities;
  final String currency;

  const RankingTab({
    super.key,
    required this.txs,
    required this.catById,
    required this.cities,
    required this.currency,
  });

  List<Transaction> _topBy(String period) {
    final filtered = txs.where((tx) => tx.period == period && cost(tx) > 0).toList()
      ..sort((a, b) => cost(b).compareTo(cost(a)));
    return filtered.take(10).toList();
  }

  @override
  Widget build(BuildContext context) {
    final topBefore = _topBy(periodBefore);
    final topDuring = _topBy(periodDuring);

    if (topBefore.isEmpty && topDuring.isEmpty) {
      return Center(
        child: Text('Nenhuma transação ainda.', style: TextStyle(color: Theme.of(context).hintColor)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (topBefore.isNotEmpty) ...[
            sectionHeader(context, 'Maiores gastos · antes', first: true),
            for (final tx in topBefore)
              TxRow(tx: tx, cat: catById[tx.categoryId], cities: cities, currency: currency, showMeta: false),
          ],
          if (topDuring.isNotEmpty) ...[
            sectionHeader(context, 'Maiores gastos · durante', first: topBefore.isEmpty),
            for (final tx in topDuring)
              TxRow(tx: tx, cat: catById[tx.categoryId], cities: cities, currency: currency, showMeta: false),
          ],
        ],
      ),
    );
  }
}
