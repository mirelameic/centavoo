import 'package:flutter/material.dart';
import 'package:centavoo/format.dart';
import 'package:centavoo/l10n/arb/app_localizations.dart';
import 'package:centavoo/stats/stats.dart';
import 'package:centavoo/theme.dart';
import 'package:centavoo/widgets/trip/primitives.dart';

const _donutSize = 240.0;
const _donutThickness = 34.0;

class SummaryTab extends StatelessWidget {
  final TripStats stats;
  final String currency;
  final bool hasSplit;

  const SummaryTab({super.key, required this.stats, required this.currency, required this.hasSplit});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 32,
            runSpacing: 24,
            children: [
              donutChart(
                context,
                size: _donutSize,
                thickness: _donutThickness,
                values: [for (final c in stats.byCategory) c.amount],
                colors: [for (final c in stats.byCategory) hexColor(c.color)],
                centerLabel: money(stats.gross, currency: currency),
              ),
              legendList(
                context,
                currency: currency,
                rows: [
                  for (final c in stats.byCategory)
                    LegendRow(key: c.name, color: hexColor(c.color), label: c.name, icon: c.icon, amount: c.amount),
                ],
              ),
            ],
          ),
          if (hasSplit) ...[
            sectionHeader(context, l10n.secSplit),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 480;
                final columns = isWide ? 3 : 1;
                final gap = 8.0;
                final cardWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    SizedBox(
                      width: cardWidth,
                      child: _SplitCard(
                        label: l10n.splitIntegral.toUpperCase(),
                        value: money(stats.split.integral, currency: currency),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _SplitCard(
                        label: l10n.splitShare.toUpperCase(),
                        value: money(stats.split.share, currency: currency),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _SplitCard(
                        label: l10n.splitSavings.toUpperCase(),
                        value: money(stats.split.savings, currency: currency),
                        color: const Color(0xFF12B886),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _SplitCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _SplitCard({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}
