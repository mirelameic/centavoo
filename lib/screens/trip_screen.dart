import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:centavoo/data/database.dart';
import 'package:centavoo/data/mappers.dart';
import 'package:centavoo/logic/format.dart';
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
import 'package:centavoo/widgets/trip/transaction_form.dart';
import 'package:centavoo/widgets/trip/kpi_grid.dart';
import 'package:centavoo/widgets/trip/trip_header.dart';
import 'package:centavoo/widgets/trip/trip_tab_bar.dart';
import 'package:centavoo/logic/stats.dart';

const _mobileBreakpoint = 480.0;

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
    _categoriesStream =
        (db.select(db.categoriesTable)
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
                final l10n = AppLocalizations.of(context)!;
                final stats = computeStats(
                  txs,
                  cats,
                  tripDays: trip.startDate != null && trip.endDate != null
                      ? dateRange(trip.startDate!, trip.endDate!).length
                      : null,
                  noCategoryLabel: l10n.statsNoCategory,
                  iofLabel: l10n.statsIofRefund,
                );
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
  TripTab? _activeTab;

  void _openTab(TripTab value) => setState(() => _activeTab = _activeTab == value ? null : value);
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

    return PopScope(
      canPop: !tabOpen,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _closeTab();
      },
      child: LayoutBuilder(
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
                              onTap: () => context.canPop() ? context.pop() : context.go('/'),
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
                            TripHeader(trip: trip, categories: catById.values.toList(), rules: rules, txs: txs),
                            const SizedBox(height: 16),
                            KpiGrid(stats: stats, currency: trip.currency),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    if (!isMobile)
                      SliverToBoxAdapter(
                        child: TripTabsRow(activeTab: _activeTab, onTap: _openTab),
                      ),
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
                  child: TripBottomNav(activeTab: _activeTab, onTap: _openTab),
                ),
            ],
          );
        },
      ),
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
    return _activeTab == TripTab.tx ? content : SliverToBoxAdapter(child: content);
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
      case TripTab.summary:
        return SummaryTab(stats: stats, currency: trip.currency, hasSplit: hasSplit);
      case TripTab.top:
        return RankingTab(txs: txs, catById: catById, cities: trip.cities, currency: trip.currency);
      case TripTab.time:
        return TimeTab(stats: stats, currency: trip.currency);
      case TripTab.cities:
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
      case TripTab.cats:
        return CategoriesTab(stats: stats, currency: trip.currency);
      case TripTab.tx:
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
    }
  }
}
