import 'package:flutter/material.dart';
import 'package:centavoo/core/theme.dart';
import 'package:centavoo/l10n/arb/app_localizations.dart';
import 'package:centavoo/logic/format.dart';
import 'package:centavoo/logic/stats.dart';

class KpiGrid extends StatelessWidget {
  final TripStats stats;
  final String currency;
  const KpiGrid({super.key, required this.stats, required this.currency});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final groups = [
      [
        (l10n.kpiNet, stats.net, null),
        (l10n.kpiGross, stats.gross, null),
        (l10n.kpiRefunds, stats.refunds, refundColor),
        (l10n.kpiIofRefunds, stats.iofRefund, refundColor),
      ],
      [
        (l10n.kpiBefore, stats.before, null),
        (l10n.kpiDuring, stats.during, null),
        (l10n.kpiAvgPerDay, stats.avgPerDay, null),
      ],
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final wide = constraints.maxWidth >= 768;
        return Column(
          children: [
            for (final (i, group) in groups.indexed) ...[
              if (i > 0) const SizedBox(height: gap),
              Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final (label, value, color) in group)
                    SizedBox(
                      width: wide
                          ? (constraints.maxWidth - gap * (group.length - 1)) / group.length
                          : constraints.maxWidth,
                      child: _KpiCard(
                        label: label.toUpperCase(),
                        value: money(value, currency: currency),
                        color: color,
                      ),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _KpiCard({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return highlightCard(
      context,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).hintColor),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
