import 'package:flutter/material.dart';
import 'package:centavoo/category_icons.dart';
import 'package:centavoo/format.dart';
import 'package:centavoo/l10n/arb/app_localizations.dart';
import 'package:centavoo/models/category.dart';
import 'package:centavoo/models/transaction.dart';
import 'package:centavoo/stats/stats.dart';
import 'package:centavoo/theme.dart';

const _tealColor = Color(0xFF12B886);

class TxRow extends StatelessWidget {
  final Transaction tx;
  final Category? cat;
  final Map<String, String> cities;
  final String currency;
  final bool showMeta;
  final bool showPeriod;
  final bool selecting;
  final bool selected;
  final VoidCallback? onToggleSelect;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const TxRow({
    super.key,
    required this.tx,
    this.cat,
    required this.cities,
    required this.currency,
    this.showMeta = true,
    this.showPeriod = false,
    this.selecting = false,
    this.selected = false,
    this.onToggleSelect,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hintColor = Theme.of(context).hintColor;
    final amount = cost(tx);
    final cityName = tx.date != null ? cities[tx.date] : null;
    final isIof = tx.isIof;
    final isRefund = tx.kind == kindRefund;

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selecting
                ? null
                : isRefund
                    ? _tealColor.withValues(alpha: 0.12)
                    : cat != null
                        ? hexColor(cat!.color).withValues(alpha: 0x26 / 255)
                        : hintColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: selecting
              ? IgnorePointer(child: Checkbox(value: selected, onChanged: (_) {}))
              : isRefund
                  ? const Icon(Icons.u_turn_left, size: 17, color: _tealColor)
                  : cat != null
                      ? Icon(categoryIcon(cat!.icon) ?? Icons.category_outlined, size: 17, color: hexColor(cat!.color))
                      : Text('—', style: TextStyle(color: hintColor)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: tx.description),
                    if (tx.splitCount > 1)
                      TextSpan(text: ' (÷${tx.splitCount})', style: TextStyle(fontWeight: FontWeight.normal, color: hintColor, fontSize: 12)),
                  ],
                ),
                style: const TextStyle(fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (showMeta)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 5,
                    children: [
                      if (isIof)
                        _metaBadge(context, 'IOF', hintColor)
                      else if (isRefund)
                        _metaBadge(context, l10n.typeRefund, _tealColor)
                      else
                        Text(cat?.name ?? '—', style: TextStyle(fontSize: 12, color: hintColor)),
                      if (cityName != null) ...[
                        Text('·', style: TextStyle(color: hintColor.withValues(alpha: 0.5))),
                        Text(cityName, style: TextStyle(fontSize: 12, color: hintColor)),
                      ],
                      Text('·', style: TextStyle(color: hintColor.withValues(alpha: 0.5))),
                      Text(fmtDate(tx.date), style: TextStyle(fontSize: 12, color: hintColor)),
                      if (showPeriod) ...[
                        Text('·', style: TextStyle(color: hintColor.withValues(alpha: 0.5))),
                        Text(
                          tx.period == periodBefore ? l10n.periodBefore : l10n.periodDuring,
                          style: TextStyle(fontSize: 12, color: hintColor),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              money(amount, currency: currency),
              style: TextStyle(fontWeight: FontWeight.w600, color: amount < 0 ? _tealColor : null),
            ),
            if (tx.splitCount > 1)
              Text('${l10n.tableFull} ${money(tx.amount, currency: currency)}', style: TextStyle(fontSize: 12, color: hintColor)),
          ],
        ),
        if (!selecting && (onEdit != null || onDelete != null))
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 16),
            padding: EdgeInsets.zero,
            onSelected: (value) {
              if (value == 'edit') onEdit?.call();
              if (value == 'delete') onDelete?.call();
            },
            itemBuilder: (context) => [
              if (onEdit != null)
                PopupMenuItem(value: 'edit', child: Text(l10n.commonEdit)),
              if (onDelete != null)
                PopupMenuItem(value: 'delete', child: Text(l10n.txDeleteOne)),
            ],
          ),
      ],
    );

    return InkWell(
      onTap: selecting ? onToggleSelect : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12) : null,
          border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
        ),
        child: row,
      ),
    );
  }
}

Widget _metaBadge(BuildContext context, String label, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
    child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
  );
}
