import 'package:flutter/material.dart';
import 'package:centavoo/category_icons.dart';
import 'package:centavoo/confirm.dart';
import 'package:centavoo/data/database.dart';
import 'package:centavoo/data/repo.dart';
import 'package:centavoo/format.dart';
import 'package:centavoo/models/category.dart';
import 'package:centavoo/models/transaction.dart';
import 'package:centavoo/stats/stats.dart';
import 'package:centavoo/theme.dart';
import 'package:centavoo/widgets/trip/tx_row.dart';

typedef _SortField = String;

const _sortFields = <_SortField>[
  'date',
  'category',
  'city',
  'period',
  'amount',
];
const _sortLabels = {
  'date': 'Data',
  'category': 'Categoria',
  'city': 'Cidade',
  'period': 'Período',
  'amount': 'Valor',
};

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
        final start = _iso(_dateFilter!.start);
        final end = _iso(_dateFilter!.end);
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

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDateFilter() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dateFilter = picked);
  }

  Future<void> _removeTx(Transaction tx) async {
    await confirmDelete(context, 'Excluir esta transação?', () {
      deleteTransaction(widget.db, tx.id);
    });
  }

  Future<void> _bulkDelete() async {
    if (_selected.isEmpty) return;
    await confirmDelete(context, 'Excluir as transações selecionadas?', () {
      deleteTransactions(widget.db, _selected.toList());
      setState(() => _selected.clear());
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final total = filtered.fold<double>(0, (s, tx) => s + cost(tx));
    final hintColor = Theme.of(context).hintColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search, size: 18),
              hintText: 'Buscar por descrição…',
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
                      ? 'Data: qualquer data'
                      : 'Data: ${fmtDate(_iso(_dateFilter!.start))} – ${fmtDate(_iso(_dateFilter!.end))}',
                ),
                onPressed: _pickDateFilter,
              ),
              for (final c in widget.cats)
                FilterChip(
                  label: Text(c.name),
                  avatar: Icon(
                    categoryIcon(c.icon) ?? Icons.category_outlined,
                    size: 16,
                    color: hexColor(c.color),
                  ),
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
            segments: const [
              ButtonSegment(value: null, label: Text('Todos')),
              ButtonSegment(value: periodBefore, label: Text('Antes')),
              ButtonSegment(value: periodDuring, label: Text('Durante')),
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
                '${filtered.length} resultado(s) · ${money(total, currency: widget.currency)}',
                style: TextStyle(fontSize: 13, color: hintColor),
              ),
              if (_filtersActive)
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text('Limpar filtros'),
                ),
              TextButton(
                onPressed: _toggleSelectMode,
                child: Text(_selectMode ? 'Cancelar' : 'Selecionar'),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                'Ordenar por',
                style: TextStyle(fontSize: 13, color: hintColor),
              ),
              const SizedBox(width: 8),
              DropdownButton<String?>(
                value: _sortField,
                hint: const Text('Padrão'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Padrão')),
                  for (final f in _sortFields)
                    DropdownMenuItem(value: f, child: Text(_sortLabels[f]!)),
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
              child: Row(
                children: [
                  Text(
                    '${_selected.length} selecionadas',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 12),
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
                          ? 'Limpar seleção'
                          : 'Selecionar todos',
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _selected.isEmpty ? null : _bulkDelete,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Excluir selecionadas'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ),
            ),
          for (final tx in filtered)
            TxRow(
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
            ),
        ],
      ),
    );
  }
}
