import 'dart:ui';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:centavoo/data/database.dart';
import 'package:centavoo/data/mappers.dart';
import 'package:centavoo/format.dart';
import 'package:centavoo/l10n/arb/app_localizations.dart';
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
import 'package:centavoo/widgets/trip/import_transactions.dart';
import 'package:centavoo/widgets/trip/transaction_form.dart';
import 'package:centavoo/widgets/trip/trip_edit_form.dart';
import 'package:centavoo/stats/stats.dart';
import 'package:centavoo/theme.dart';

const _mobileBreakpoint = 480.0;

class _TabItem {
  final String value;
  final IconData icon;
  const _TabItem(this.value, this.icon);
}

const _tabItems = [
  _TabItem('summary', Icons.pie_chart_outline),
  _TabItem('top', Icons.bar_chart_outlined),
  _TabItem('time', Icons.calendar_month_outlined),
  _TabItem('cities', Icons.location_on_outlined),
  _TabItem('cats', Icons.category_outlined),
  _TabItem('tx', Icons.receipt_long_outlined),
];

String _tabLabel(AppLocalizations l10n, String value) {
  switch (value) {
    case 'summary':
      return l10n.tabSummary;
    case 'top':
      return l10n.tabTop;
    case 'time':
      return l10n.tabTime;
    case 'cities':
      return l10n.tabCities;
    case 'cats':
      return l10n.tabCats;
    case 'tx':
      return l10n.tabTransactions;
    default:
      return value;
  }
}

class TripScreen extends StatefulWidget {
  final String tripId;

  const TripScreen({super.key, required this.tripId});

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  late Stream<TripRow?> _tripStream;
  late Stream<List<CategoryRow>> _categoriesStream;
  late Stream<List<TransactionRow>> _transactionsStream;
  late Stream<List<CategoryRuleRow>> _rulesStream;

  @override
  void initState() {
    super.initState();
    _initStreams();
  }

  @override
  void didUpdateWidget(TripScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tripId != widget.tripId) _initStreams();
  }

  void _initStreams() {
    final db = context.read<AppDatabase>();
    _tripStream = (db.select(db.tripsTable)..where((t) => t.id.equals(widget.tripId))).watchSingleOrNull();
    _categoriesStream = (db.select(db.categoriesTable)
          ..where((c) => c.tripId.equals(widget.tripId))
          ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
        .watch();
    _transactionsStream = (db.select(db.transactionsTable)..where((t) => t.tripId.equals(widget.tripId))).watch();
    _rulesStream = db.select(db.categoryRulesTable).watch();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TripRow?>(
      stream: _tripStream,
      builder: (context, tripSnap) {
        if (tripSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final tripRow = tripSnap.data;
        if (tripRow == null) {
          final l10n = AppLocalizations.of(context)!;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.tripNotFound),
                TextButton(onPressed: () => context.go('/'), child: Text(l10n.commonBack)),
              ],
            ),
          );
        }
        final trip = tripFromRow(tripRow);
        return StreamBuilder<List<CategoryRow>>(
          stream: _categoriesStream,
          builder: (context, catSnap) {
            final cats = (catSnap.data ?? const <CategoryRow>[]).map(categoryFromRow).toList();
            return StreamBuilder<List<TransactionRow>>(
              stream: _transactionsStream,
              builder: (context, txSnap) {
                final txs = (txSnap.data ?? const <TransactionRow>[]).map(transactionFromRow).toList();
                final stats = computeStats(txs, cats, trip.cities);
                final hasSplit = txs.any((tx) => tx.splitCount > 1);
                final catById = {for (final c in cats) c.id: c};
                return StreamBuilder<List<CategoryRuleRow>>(
                  stream: _rulesStream,
                  builder: (context, ruleSnap) {
                    final rules = (ruleSnap.data ?? const <CategoryRuleRow>[]).map(categoryRuleFromRow).toList();
                    return _TripBody(
                      trip: trip,
                      stats: stats,
                      hasSplit: hasSplit,
                      txs: txs,
                      catById: catById,
                      rules: rules,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

}

class _TripBody extends StatefulWidget {
  final model.Trip trip;
  final TripStats stats;
  final bool hasSplit;
  final List<Transaction> txs;
  final Map<String, Category> catById;
  final List<CategoryRule> rules;

  const _TripBody({
    required this.trip,
    required this.stats,
    required this.hasSplit,
    required this.txs,
    required this.catById,
    required this.rules,
  });

  @override
  State<_TripBody> createState() => _TripBodyState();
}

class _TripBodyState extends State<_TripBody> {
  String? _activeTab;

  void _openTab(String value) => setState(() => _activeTab = _activeTab == value ? null : value);
  void _closeTab() => setState(() => _activeTab = null);

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final stats = widget.stats;
    final hasSplit = widget.hasSplit;
    final txs = widget.txs;
    final catById = widget.catById;
    final rules = widget.rules;
    final tabOpen = _activeTab != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < _mobileBreakpoint;
        final hideHeaderAndKpi = isMobile && tabOpen;
        final l10n = AppLocalizations.of(context)!;

        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: tabOpen
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
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.arrow_back, size: 16),
                                  const SizedBox(width: 4),
                                  Text(l10n.navTrips),
                                ],
                              ),
                            ),
                          ),
                  ),
                  if (!hideHeaderAndKpi)
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _TripHeader(trip: trip, categories: catById.values.toList(), rules: rules),
                          const SizedBox(height: 16),
                          _KpiGrid(stats: stats, currency: trip.currency),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  if (!isMobile) SliverToBoxAdapter(child: _DesktopTabsRow(activeTab: _activeTab, onTap: _openTab)),
                  if (tabOpen) _tabContentSliver(context, stats, trip, hasSplit, txs, catById, rules),
                  SliverToBoxAdapter(
                    child: SizedBox(height: isMobile ? 76 + MediaQuery.of(context).padding.bottom : 0),
                  ),
                ],
              ),
            ),
            if (isMobile)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16 + MediaQuery.of(context).padding.bottom,
                child: _MobileBottomNav(activeTab: _activeTab, onTap: _openTab),
              ),
          ],
        );
      },
    );
  }

  Widget _tabContentSliver(
    BuildContext context,
    TripStats stats,
    model.Trip trip,
    bool hasSplit,
    List<Transaction> txs,
    Map<String, Category> catById,
    List<CategoryRule> rules,
  ) {
    final content = _tabContent(context, stats, trip, hasSplit, txs, catById, rules);
    return _activeTab == 'tx' ? content : SliverToBoxAdapter(child: content);
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
        return _TabPlaceholder(label: _tabLabel(AppLocalizations.of(context)!, _activeTab!));
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
                ),
              ),
              icon: const Icon(Icons.file_upload_outlined, size: 18),
              label: Text(l10n.txImportButton),
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
              label: Text(l10n.txNew),
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
    final l10n = AppLocalizations.of(context)!;
    final items = [
      (l10n.kpiNet.toUpperCase(), money(stats.net, currency: currency), null),
      (l10n.kpiGross.toUpperCase(), money(stats.gross, currency: currency), null),
      (l10n.kpiRefunds.toUpperCase(), money(stats.refunds, currency: currency), const Color(0xFF12B886)),
      (l10n.kpiBefore.toUpperCase(), money(stats.before, currency: currency), null),
      (l10n.kpiDuring.toUpperCase(), money(stats.during, currency: currency), null),
      (l10n.kpiAvgPerDay.toUpperCase(), money(stats.avgPerDay, currency: currency), null),
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
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}

Widget _glassBar({required BuildContext context, required Widget child}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final tint = (isDark ? darkSurfaces[7] : Colors.white).withValues(alpha: isDark ? 0.6 : 0.8);
  final bar = ClipRRect(
    borderRadius: BorderRadius.circular(28),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(28),
          border: isDark ? null : Border.all(color: lightDivider),
        ),
        child: child,
      ),
    ),
  );
  if (isDark) return bar;
  return DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 16, offset: const Offset(0, 4))],
    ),
    child: bar,
  );
}

class _DesktopTabsRow extends StatelessWidget {
  final String? activeTab;
  final ValueChanged<String> onTap;
  const _DesktopTabsRow({required this.activeTab, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Center(
        child: _glassBar(
          context: context,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final item in _tabItems)
                  ChoiceChip(
                    label: Text(_tabLabel(l10n, item.value)),
                    avatar: Icon(item.icon, size: 18),
                    selected: activeTab == item.value,
                    onSelected: (_) => onTap(item.value),
                    shape: const StadiumBorder(),
                    showCheckmark: false,
                  ),
              ],
            ),
          ),
        ),
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
    final l10n = AppLocalizations.of(context)!;
    return _glassBar(
      context: context,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          children: [
            for (final item in _tabItems)
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => onTap(item.value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                    decoration: BoxDecoration(
                      color: activeTab == item.value ? primary.withValues(alpha: 0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(item.icon, size: 20, color: activeTab == item.value ? primary : hintColor),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _tabLabel(l10n, item.value),
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 10,
                              color: activeTab == item.value ? primary : hintColor,
                              fontWeight: activeTab == item.value ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
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
