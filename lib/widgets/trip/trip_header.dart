import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:centavoo/core/theme.dart';
import 'package:centavoo/data/database.dart';
import 'package:centavoo/l10n/arb/app_localizations.dart';
import 'package:centavoo/logic/format.dart';
import 'package:centavoo/models/category.dart';
import 'package:centavoo/models/category_rule.dart';
import 'package:centavoo/models/transaction.dart';
import 'package:centavoo/models/trip.dart' as model;
import 'package:centavoo/widgets/trip/import_transactions.dart';
import 'package:centavoo/widgets/trip/transaction_form.dart';
import 'package:centavoo/widgets/trip/trip_edit_form.dart';

class TripHeader extends StatelessWidget {
  final model.Trip trip;
  final List<Category> categories;
  final List<CategoryRule> rules;
  final List<Transaction> txs;
  const TripHeader({super.key, required this.trip, required this.categories, required this.rules, required this.txs});

  @override
  Widget build(BuildContext context) {
    final hintColor = Theme.of(context).hintColor;
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                trip.name,
                style: unboundedStyle(weight: FontWeight.w500).copyWith(fontSize: 26, height: 1.35),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => TripEditForm(db: context.read<AppDatabase>(), trip: trip),
              ),
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: 'edit-trip',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        if (trip.destination != null) Text(trip.destination!, style: TextStyle(color: hintColor)),
        Text(fmtDateRange(trip.startDate, trip.endDate), style: TextStyle(color: hintColor, fontSize: 14)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => context.push('/trip/${trip.id}/categories'),
              icon: const Icon(Icons.category_outlined, size: 18),
              label: Text(l10n.menuCategories),
            ),
            OutlinedButton.icon(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => ImportTransactions(
                  db: context.read<AppDatabase>(),
                  trip: trip,
                  categories: categories,
                  rules: rules,
                  existing: txs,
                ),
              ),
              icon: const Icon(Icons.file_upload_outlined, size: 18),
              label: Text(l10n.txImportButton),
            ),
            ElevatedButton.icon(
              onPressed: () => showDialog(
                context: context,
                builder: (_) =>
                    TransactionForm(db: context.read<AppDatabase>(), trip: trip, categories: categories, rules: rules),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.txNew),
            ),
          ],
        ),
      ],
    );
  }
}
