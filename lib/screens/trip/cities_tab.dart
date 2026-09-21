import 'package:flutter/material.dart';
import 'package:centavoo/category_icons.dart';
import 'package:centavoo/data/database.dart';
import 'package:centavoo/format.dart';
import 'package:centavoo/l10n/arb/app_localizations.dart';
import 'package:centavoo/models/category.dart';
import 'package:centavoo/models/transaction.dart';
import 'package:centavoo/stats/stats.dart';
import 'package:centavoo/theme.dart';
import 'package:centavoo/widgets/trip/city_editor.dart';
import 'package:centavoo/widgets/trip/primitives.dart';

const _donutSize = 220.0;
const _donutThickness = 32.0;

class CitiesTab extends StatefulWidget {
  final AppDatabase db;
  final String tripId;
  final List<Transaction> txs;
  final List<Category> cats;
  final Map<String, String> cities;
  final List<String>? cityList;
  final String? startDate;
  final String? endDate;
  final String currency;

  const CitiesTab({
    super.key,
    required this.db,
    required this.tripId,
    required this.txs,
    required this.cats,
    required this.cities,
    this.cityList,
    this.startDate,
    this.endDate,
    required this.currency,
  });

  @override
  State<CitiesTab> createState() => _CitiesTabState();
}

class _CitiesTabState extends State<CitiesTab> {
  final Set<String> _selectedCatIds = {};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hintColor = Theme.of(context).hintColor;
    final cityBd = cityBreakdown(
      widget.txs,
      widget.cats,
      widget.cities,
      _selectedCatIds.isEmpty ? null : _selectedCatIds,
    );
    final cityTotal = cityBd.byCity.fold<double>(0, (s, c) => s + c.amount);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.cityFilter, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in widget.cats)
                FilterChip(
                  label: Text(c.name),
                  avatar: Icon(categoryIcon(c.icon) ?? Icons.category_outlined, size: 16, color: hexColor(c.color)),
                  selected: _selectedCatIds.contains(c.id),
                  onSelected: (selected) => setState(() {
                    if (selected) {
                      _selectedCatIds.add(c.id);
                    } else {
                      _selectedCatIds.remove(c.id);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (cityBd.byCity.isEmpty)
            Text(l10n.chartNoCity, style: TextStyle(color: hintColor))
          else ...[
            sectionHeader(context, l10n.secByCity, first: true),
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
                  values: [for (final c in cityBd.byCity) c.amount],
                  colors: [for (final c in cityBd.byCity) hexColor(c.color)],
                  centerLabel: money(cityTotal, currency: widget.currency),
                ),
                legendList(
                  context,
                  currency: widget.currency,
                  rows: [
                    for (final c in cityBd.byCity)
                      LegendRow(key: c.city, color: hexColor(c.color), label: c.city, amount: c.amount),
                  ],
                ),
              ],
            ),
            sectionHeader(context, l10n.secCityTable),
            for (final c in cityBd.cityTable)
              summaryRow(
                context,
                leading: Text(c.city),
                metaLines: [
                  Text('${c.days} ${l10n.cityDaysN} · ${l10n.colAvgDay}: ${money(c.avgPerDay, currency: widget.currency)}'),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_upward, size: 12),
                      const SizedBox(width: 4),
                      Text(c.topCategory),
                    ],
                  ),
                ],
                amount: money(c.total, currency: widget.currency),
              ),
          ],
          if (_tripDays.isNotEmpty) ...[
            sectionHeader(context, l10n.cityPerDay),
            CityEditor(
              db: widget.db,
              tripId: widget.tripId,
              days: _tripDays,
              cities: widget.cities,
              cityList: widget.cityList,
            ),
          ],
        ],
      ),
    );
  }

  List<String> get _tripDays {
    final rangeDays = (widget.startDate != null && widget.endDate != null)
        ? dateRange(widget.startDate!, widget.endDate!)
        : const <String>[];
    final txDates = widget.txs.where((tx) => tx.date != null).map((tx) => tx.date!);
    return {...rangeDays, ...txDates}.toList()..sort();
  }
}
