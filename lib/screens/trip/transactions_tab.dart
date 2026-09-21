import 'package:flutter/material.dart';
import 'package:centavoo/confirm.dart';
import 'package:centavoo/data/database.dart';
import 'package:centavoo/data/repo.dart';
import 'package:centavoo/format.dart';
import 'package:centavoo/l10n/arb/app_localizations.dart';
import 'package:centavoo/models/category.dart';
import 'package:centavoo/models/transaction.dart';
import 'package:centavoo/stats/stats.dart';
import 'package:centavoo/widgets/trip/primitives.dart';
import 'package:centavoo/widgets/trip/tx_row.dart';

typedef _SortField = String;

const _sortFields = <_SortField>[
  'date',
  'category',
  'city',
  'period',
  'amount',
];

String _sortLabel(AppLocalizations l10n, _SortField f) {
  switch (f) {
    case 'date':
      return l10n.tableDate;
    case 'category':
      return l10n.tableCategory;
    case 'city':
      return l10n.tableCity;
    case 'period':
      return l10n.tablePeriod;
    case 'amount':
      return l10n.tableAmount;
  }
  return f;
}

class TransactionsTab extends StatefulWidget {
  final AppDatabase db;
  final List<Transaction> txs;
  final Map<String, Category> catById;
  final List<Category> cats;
  final Map<String, String> cities;
  final List<String>? cityList;
  final String currency;
  final ValueChanged<Transaction>? onEdit;

  const TransactionsTab({
    super.key,
    required this.db,
    required this.txs,
    required this.catById,
    required this.cats,
    required this.cities,
    this.cityList,
    required this.currency,
    this.onEdit,
  });

  @override
  State<TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends State<TransactionsTab> {
  String _search = '';
  final Set<String> _catFilter = {};
  final Set<String> _cityFilter = {};
  String? _periodFilter;
  DateTimeRange? _dateFilter;
  _SortField? _sortField;
  bool _sortAsc = true;
  bool _selectMode = false;
  final Set<String> _selected = {};

  bool get _filtersActive =>
      _search.trim().isNotEmpty ||
      _catFilter.isNotEmpty ||
      _cityFilter.isNotEmpty ||
      _periodFilter != null ||
      _dateFilter != null;

  void _clearFilters() {
    setState(() {
      _search = '';
      _catFilter.clear();
      _cityFilter.clear();
      _periodFilter = null;
      _dateFilter = null;
    });
  }

  void _toggleSelectMode() {
    setState(() {
      _selectMode = !_selectMode;
      _selected.clear();
    });
  }

  String _cityOf(Transaction tx) =>
      (tx.date != null ? widget.cities[tx.date] : null) ?? '';

  List<Transaction> get _filtered {
    final query = _search.trim().toLowerCase();
    final list = widget.txs.where((tx) {
      if (query.isNotEmpty && !tx.description.toLowerCase().contains(query)) {
        return false;
      }
      if (_periodFilter != null && tx.period != _periodFilter) return false;
      if (_catFilter.isNotEmpty &&
          !(tx.categoryId != null && _catFilter.contains(tx.categoryId))) {
        return false;
      }
      final city = _cityOf(tx);
      if (_cityFilter.isNotEmpty &&
          !(city.isNotEmpty && _cityFilter.contains(city))) {
        return false;
      }
      if (_dateFilter != null) {
        if (tx.date == null) return false;
        final start = isoDate(_dateFilter!.start);
        final end = isoDate(_dateFilter!.end);
        if (tx.date!.compareTo(start) < 0 || tx.date!.compareTo(end) > 0) {
          return false;
        }
      }
      return true;
    }).toList();

    final compare = <_SortField, int Function(Transaction, Transaction)>{
      'date': (a, b) => (a.date ?? '').compareTo(b.date ?? ''),
      'category': (a, b) => (widget.catById[a.categoryId]?.name ?? '')
          .compareTo(widget.catById[b.categoryId]?.name ?? ''),
      'city': (a, b) => _cityOf(a).compareTo(_cityOf(b)),
      'period': (a, b) =>
          a.period == b.period ? 0 : (a.period == periodBefore ? -1 : 1),
      'amount': (a, b) => cost(a).compareTo(cost(b)),
    };

    list.sort((a, b) {
      if (_sortField != null) {
        final dir = _sortAsc ? 1 : -1;
        final primary = compare[_sortField]!(a, b) * dir;
        if (primary != 0) return primary;
      }
      if (a.period != b.period) return a.period == periodBefore ? -1 : 1;
      return (a.date ?? '').compareTo(b.date ?? '');
    });
    return list;
  }

  List<String> get _cityOptions {
    final options = <String>{
      ...?widget.cityList,
      ...widget.cities.values,
    }.where((c) => c.isNotEmpty).toList()..sort();
    return options;
  }

  Future<void> _pickDateFilter() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dateFilter = picked);
  }

  Future<void> _removeTx(Transaction tx) async {
    final l10n = AppLocalizations.of(context)!;
    await confirmDelete(context, l10n.txDeleteConfirm, () {
      deleteTransaction(widget.db, tx.id);
    });
  }

  Future<void> _bulkDelete() async {
    if (_selected.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    await confirmDelete(context, l10n.txDeleteSelectedConfirm, () {
      deleteTransactions(widget.db, _selected.toList());
      setState(() => _selected.clear());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final filtered = _filtered;
    final total = filtered.fold<double>(0, (s, tx) => s + cost(tx));
    final hintColor = Theme.of(context).hintColor;

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(child: _filters(context, l10n, filtered, total, hintColor)),
        SliverList.builder(
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final tx = filtered[index];
            return TxRow(
              key: ValueKey(tx.id),
              tx: tx,
              cat: tx.categoryId != null ? widget.catById[tx.categoryId] : null,
              cities: widget.cities,
              currency: widget.currency,
              showPeriod: true,
              selecting: _selectMode,
              selected: _selected.contains(tx.id),
              onToggleSelect: () => setState(() {
                if (_selected.contains(tx.id)) {
                  _selected.remove(tx.id);
                } else {
                  _selected.add(tx.id);
                }
              }),
              onDelete: () => _removeTx(tx),
              onEdit: widget.onEdit == null ? null : () => widget.onEdit!(tx),
            );
          },
        ),
      ],
    );
  }

  Widget _filters(
    BuildContext context,
    AppLocalizations l10n,
    List<Transaction> filtered,
    double total,
    Color hintColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, size: 18),
              hintText: l10n.txSearchPlaceholder,
              isDense: true,
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.date_range, size: 16),
                label: Text(
                  _dateFilter == null
                      ? '${l10n.txFilterDate}: ${l10n.txFilterDatePlaceholder}'
                      : '${l10n.txFilterDate}: ${fmtDate(isoDate(_dateFilter!.start))} – ${fmtDate(isoDate(_dateFilter!.end))}',
                ),
                onPressed: _pickDateFilter,
              ),
              for (final c in widget.cats)
                categoryFilterChip(
                  c,
                  selected: _catFilter.contains(c.id),
                  onSelected: (v) => setState(
                    () => v ? _catFilter.add(c.id) : _catFilter.remove(c.id),
                  ),
                ),
              for (final city in _cityOptions)
                FilterChip(
                  label: Text(city),
                  selected: _cityFilter.contains(city),
                  onSelected: (v) => setState(
                    () => v ? _cityFilter.add(city) : _cityFilter.remove(city),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SegmentedButton<String?>(
            segments: [
              ButtonSegment(value: null, label: Text(l10n.txPeriodAll)),
              ButtonSegment(value: periodBefore, label: Text(l10n.periodBefore)),
              ButtonSegment(value: periodDuring, label: Text(l10n.periodDuring)),
            ],
            selected: {_periodFilter},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _periodFilter = s.first),
          ),
          const SizedBox(height: 12),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                '${filtered.length} ${l10n.txFilterResultsN} · ${money(total, currency: widget.currency)}',
                style: TextStyle(fontSize: 13, color: hintColor),
              ),
              if (_filtersActive)
                TextButton(
                  onPressed: _clearFilters,
                  child: Text(l10n.txClearFilters),
                ),
              TextButton(
                onPressed: _toggleSelectMode,
                child: Text(_selectMode ? l10n.txCancelSelect : l10n.txSelect),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l10n.txSortBy,
                style: TextStyle(fontSize: 13, color: hintColor),
              ),
              DropdownButton<String?>(
                value: _sortField,
                hint: Text(l10n.txSortDefault),
                items: [
                  DropdownMenuItem(value: null, child: Text(l10n.txSortDefault)),
                  for (final f in _sortFields)
                    DropdownMenuItem(value: f, child: Text(_sortLabel(l10n, f))),
                ],
                onChanged: (v) => setState(() {
                  _sortField = v;
                  _sortAsc = true;
                }),
              ),
              IconButton(
                icon: Icon(
                  _sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 16,
                ),
                tooltip: 'toggle-sort-direction',
                onPressed: _sortField == null
                    ? null
                    : () => setState(() => _sortAsc = !_sortAsc),
              ),
            ],
          ),
          if (_selectMode)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${_selected.length} ${l10n.txSelectedN}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      if (_selected.length == filtered.length) {
                        _selected.clear();
                      } else {
                        _selected
                          ..clear()
                          ..addAll(filtered.map((tx) => tx.id));
                      }
                    }),
                    child: Text(
                      _selected.length == filtered.length
                          ? l10n.txClearSelection
                          : l10n.txSelectAll,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _selected.isEmpty ? null : _bulkDelete,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: Text(l10n.txDeleteSelected),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
