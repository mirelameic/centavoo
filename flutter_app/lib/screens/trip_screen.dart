import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:centavoo/data/database.dart';
import 'package:centavoo/data/mappers.dart';
import 'package:centavoo/format.dart';
import 'package:centavoo/models/category.dart';
import 'package:centavoo/models/category_rule.dart';
import 'package:centavoo/models/transaction.dart';
import 'package:centavoo/models/trip.dart' as model;
import 'package:centavoo/screens/trip/categories_tab.dart';
import 'package:centavoo/screens/trip/cities_tab.dart';
import 'package:centavoo/screens/trip/ranking_tab.dart';
import 'package:centavoo/screens/trip/summary_tab.dart';
import 'package:centavoo/screens/trip/time_tab.dart';
import 'package:centavoo/screens/trip/transactions_tab.dart';
import 'package:centavoo/widgets/trip/transaction_form.dart';
import 'package:centavoo/widgets/trip/trip_edit_form.dart';
import 'package:centavoo/stats/stats.dart';
import 'package:centavoo/theme.dart';

const _mobileBreakpoint = 480.0;

class _TabItem {
  final String value;
  final String label;
  final IconData icon;
  const _TabItem(this.value, this.label, this.icon);
}

const _tabItems = [
  _TabItem('summary', 'Resumo', Icons.pie_chart_outline),
  _TabItem('top', 'Ranking', Icons.bar_chart_outlined),
  _TabItem('time', 'Tempo', Icons.calendar_month_outlined),
  _TabItem('cities', 'Cidades', Icons.location_on_outlined),
  _TabItem('cats', 'Categorias', Icons.category_outlined),
  _TabItem('tx', 'Transações', Icons.receipt_long_outlined),
];

class TripScreen extends StatefulWidget {
  final String tripId;

  const TripScreen({super.key, required this.tripId});

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  String? _activeTab;

  void _openTab(String value) => setState(() => _activeTab = _activeTab == value ? null : value);
  void _closeTab() => setState(() => _activeTab = null);

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();
    return StreamBuilder<TripRow?>(
      stream: (db.select(db.tripsTable)..where((t) => t.id.equals(widget.tripId))).watchSingleOrNull(),
      builder: (context, tripSnap) {
        if (tripSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final tripRow = tripSnap.data;
        if (tripRow == null) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Viagem não encontrada.'),
                TextButton(onPressed: () => context.go('/'), child: const Text('Voltar')),
              ],
            ),
          );
        }
        final trip = tripFromRow(tripRow);
        return StreamBuilder<List<CategoryRow>>(
          stream: (db.select(db.categoriesTable)
                ..where((c) => c.tripId.equals(widget.tripId))
                ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
              .watch(),
          builder: (context, catSnap) {
            final cats = (catSnap.data ?? const <CategoryRow>[]).map(categoryFromRow).toList();
            return StreamBuilder<List<TransactionRow>>(
              stream: (db.select(db.transactionsTable)..where((t) => t.tripId.equals(widget.tripId))).watch(),
              builder: (context, txSnap) {
                final txs = (txSnap.data ?? const <TransactionRow>[]).map(transactionFromRow).toList();
                final stats = computeStats(txs, cats, trip.cities);
                final hasSplit = txs.any((tx) => tx.splitCount > 1);
                final catById = {for (final c in cats) c.id: c};
                return StreamBuilder<List<CategoryRuleRow>>(
                  stream: db.select(db.categoryRulesTable).watch(),
                  builder: (context, ruleSnap) {
                    final rules = (ruleSnap.data ?? const <CategoryRuleRow>[]).map(categoryRuleFromRow).toList();
                    return _buildBody(context, trip, stats, hasSplit, txs, catById, rules);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    model.Trip trip,
    TripStats stats,
    bool hasSplit,
    List<Transaction> txs,
    Map<String, Category> catById,
    List<CategoryRule> rules,
  ) {
    final tabOpen = _activeTab != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < _mobileBreakpoint;
        final hideHeaderAndKpi = isMobile && tabOpen;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      tabOpen
                          ? Align(
                              alignment: Alignment.centerLeft,
                              child: IconButton(
                                onPressed: _closeTab,
                                icon: const Icon(Icons.arrow_back),
                                visualDensity: VisualDensity.compact,
                              ),
                            )
                          : InkWell(
                              onTap: () => context.go('/'),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.arrow_back, size: 16),
                                    SizedBox(width: 4),
                                    Text('Viagens'),
                                  ],
                                ),
                              ),
                            ),
                      if (!hideHeaderAndKpi) ...[
                        _TripHeader(trip: trip, categories: catById.values.toList(), rules: rules),
                        const SizedBox(height: 16),
                        _KpiGrid(stats: stats, currency: trip.currency),
                        const SizedBox(height: 16),
                      ],
                      if (!isMobile) _DesktopTabsRow(activeTab: _activeTab, onTap: _openTab),
                      if (tabOpen) _tabContent(context, stats, trip, hasSplit, txs, catById, rules),
                    ],
                  ),
                ),
              ),
              if (isMobile) _MobileBottomNav(activeTab: _activeTab, onTap: _openTab),
            ],
          ),
        );
      },
    );
  }

  Widget _tabContent(
    BuildContext context,
    TripStats stats,
    model.Trip trip,
    bool hasSplit,
    List<Transaction> txs,
    Map<String, Category> catById,
    List<CategoryRule> rules,
  ) {
    switch (_activeTab) {
      case null:
        return const SizedBox.shrink();
      case 'summary':
        return SummaryTab(stats: stats, currency: trip.currency, hasSplit: hasSplit);
      case 'top':
        return RankingTab(txs: txs, catById: catById, cities: trip.cities, currency: trip.currency);
      case 'time':
        return TimeTab(stats: stats, currency: trip.currency);
      case 'cities':
        return CitiesTab(
          db: context.read<AppDatabase>(),
          tripId: trip.id,
          txs: txs,
          cats: catById.values.toList(),
          cities: trip.cities,
          cityList: trip.cityList,
          startDate: trip.startDate,
          endDate: trip.endDate,
          currency: trip.currency,
        );
      case 'cats':
        return CategoriesTab(stats: stats, currency: trip.currency);
      case 'tx':
        return TransactionsTab(
          db: context.read<AppDatabase>(),
          txs: txs,
          catById: catById,
          cats: catById.values.toList(),
          cities: trip.cities,
          cityList: trip.cityList,
          currency: trip.currency,
          onEdit: (tx) => showDialog(
            context: context,
            builder: (_) => TransactionForm(
              db: context.read<AppDatabase>(),
              trip: trip,
              categories: catById.values.toList(),
              rules: rules,
              editing: tx,
            ),
          ),
        );
      default:
        return _TabPlaceholder(label: _tabItems.firstWhere((t) => t.value == _activeTab).label);
    }
  }
}

class _TripHeader extends StatelessWidget {
  final model.Trip trip;
  final List<Category> categories;
  final List<CategoryRule> rules;
  const _TripHeader({required this.trip, required this.categories, required this.rules});

  @override
  Widget build(BuildContext context) {
    final hintColor = Theme.of(context).hintColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              trip.name,
              style: unboundedStyle(weight: FontWeight.w500).copyWith(fontSize: 26, height: 1.35),
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
        Text(
          '${fmtDate(trip.startDate)} – ${fmtDate(trip.endDate)}',
          style: TextStyle(color: hintColor, fontSize: 14),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => context.go('/trip/${trip.id}/categories'),
              icon: const Icon(Icons.category_outlined, size: 18),
              label: const Text('Categorias'),
            ),
            ElevatedButton.icon(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => TransactionForm(
                  db: context.read<AppDatabase>(),
                  trip: trip,
                  categories: categories,
                  rules: rules,
                ),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nova transação'),
            ),
          ],
        ),
      ],
    );
  }
}

class _KpiGrid extends StatelessWidget {
  final TripStats stats;
  final String currency;
  const _KpiGrid({required this.stats, required this.currency});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('LÍQUIDO', money(stats.net, currency: currency), null),
      ('BRUTO', money(stats.gross, currency: currency), null),
      ('REEMBOLSOS', money(stats.refunds, currency: currency), const Color(0xFF12B886)),
      ('ANTES', money(stats.before, currency: currency), null),
      ('DURANTE', money(stats.during, currency: currency), null),
      ('MÉDIA/DIA', money(stats.avgPerDay, currency: currency), null),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 768 ? 3 : 1;
        final gap = 8.0;
        final cardWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final (label, value, color) in items)
              SizedBox(width: cardWidth, child: _KpiCard(label: label, value: value, color: color)),
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
    return Card(
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
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}

class _DesktopTabsRow extends StatelessWidget {
  final String? activeTab;
  final ValueChanged<String> onTap;
  const _DesktopTabsRow({required this.activeTab, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final item in _tabItems)
            ChoiceChip(
              label: Text(item.label),
              avatar: Icon(item.icon, size: 18),
              selected: activeTab == item.value,
              onSelected: (_) => onTap(item.value),
            ),
        ],
      ),
    );
  }
}

class _MobileBottomNav extends StatelessWidget {
  final String? activeTab;
  final ValueChanged<String> onTap;
  const _MobileBottomNav({required this.activeTab, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final hintColor = Theme.of(context).hintColor;
    return Row(
      children: [
        for (final item in _tabItems)
          Expanded(
            child: InkWell(
              onTap: () => onTap(item.value),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.icon, size: 20, color: activeTab == item.value ? primary : hintColor),
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: activeTab == item.value ? primary : hintColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TabPlaceholder extends StatelessWidget {
  final String label;
  const _TabPlaceholder({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(label, style: TextStyle(color: Theme.of(context).hintColor)));
  }
}
