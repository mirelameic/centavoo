import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:centavoo/confirm.dart';
import 'package:centavoo/data/database.dart';
import 'package:centavoo/data/mappers.dart';
import 'package:centavoo/data/repo.dart';
import 'package:centavoo/format.dart';
import 'package:centavoo/l10n/arb/app_localizations.dart';
import 'package:centavoo/stats/stats.dart';
import 'package:centavoo/theme.dart';
import 'package:centavoo/widgets/trip/trip_edit_form.dart';

const _containerMaxWidth = 1140.0;
const _gridGap = 16.0;

int _columnsFor(double viewportWidth) {
  if (viewportWidth >= 1200) return 3;
  if (viewportWidth >= 768) return 2;
  return 1;
}

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  late final Stream<List<TripRow>> _tripsStream;
  late final Stream<List<TransactionRow>> _transactionsStream;

  @override
  void initState() {
    super.initState();
    final db = context.read<AppDatabase>();
    _tripsStream = (db.select(db.tripsTable)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).watch();
    _transactionsStream = db.select(db.transactionsTable).watch();
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();
    final l10n = AppLocalizations.of(context)!;

    return StreamBuilder<List<TripRow>>(
      stream: _tripsStream,
      builder: (context, tripsSnapshot) {
        final trips = tripsSnapshot.data ?? const <TripRow>[];
        return StreamBuilder<List<TransactionRow>>(
          stream: _transactionsStream,
          builder: (context, txSnapshot) {
            final txs = txSnapshot.data ?? const <TransactionRow>[];
            final netByTrip = <String, double>{};
            for (final tx in txs) {
              netByTrip[tx.tripId] = (netByTrip[tx.tripId] ?? 0) + cost(transactionFromRow(tx));
            }

            return LayoutBuilder(
              builder: (context, viewport) {
                final columns = _columnsFor(viewport.maxWidth);
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: _containerMaxWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  l10n.tripsTitle,
                                  style: unboundedStyle(weight: FontWeight.w500).copyWith(fontSize: 28),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton.filled(
                                onPressed: () => _openNewTripDialog(context, db),
                                icon: const Icon(Icons.add),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          if (trips.isEmpty)
                            Expanded(
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(l10n.tripsEmpty, style: TextStyle(color: Theme.of(context).hintColor)),
                                    const SizedBox(height: 12),
                                    ElevatedButton.icon(
                                      onPressed: () => _openNewTripDialog(context, db),
                                      icon: const Icon(Icons.add),
                                      label: Text(l10n.tripsCreateFirst),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, inner) {
                                  final cardWidth = (inner.maxWidth - _gridGap * (columns - 1)) / columns;
                                  return SingleChildScrollView(
                                    child: Wrap(
                                      spacing: _gridGap,
                                      runSpacing: _gridGap,
                                      children: [
                                        for (var i = 0; i < trips.length; i++)
                                          SizedBox(
                                            width: cardWidth,
                                            child: _TripCard(
                                              trip: trips[i],
                                              net: netByTrip[trips[i].id] ?? 0,
                                              onTap: () => context.go('/trip/${trips[i].id}'),
                                              onLongPress: () => _showTripActions(
                                                context,
                                                db,
                                                trips[i],
                                                isFirst: i == 0,
                                                isLast: i == trips.length - 1,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _openNewTripDialog(BuildContext context, AppDatabase db) {
    showDialog(context: context, builder: (_) => _NewTripDialog(db: db));
  }

  void _showTripActions(
    BuildContext context,
    AppDatabase db,
    TripRow trip, {
    required bool isFirst,
    required bool isLast,
  }) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l10n.commonEdit),
              onTap: () {
                Navigator.of(sheetContext).pop();
                showDialog(context: context, builder: (_) => TripEditForm(db: db, trip: tripFromRow(trip)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text(l10n.commonDelete, style: const TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                confirmDelete(context, l10n.tripDeleteConfirm, () => deleteTrip(db, trip.id));
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_upward),
              title: Text(l10n.tripsMoveUp),
              enabled: !isFirst,
              onTap: () {
                Navigator.of(sheetContext).pop();
                moveTripUp(db, trip.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_downward),
              title: Text(l10n.tripsMoveDown),
              enabled: !isLast,
              onTap: () {
                Navigator.of(sheetContext).pop();
                moveTripDown(db, trip.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final TripRow trip;
  final double net;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _TripCard({required this.trip, required this.net, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return highlightCard(
      context,
      child: InkWell(
        borderRadius: borderRadiusLg,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(trip.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              if (trip.destination != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 14, color: Theme.of(context).hintColor),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        trip.destination!,
                        style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              Text(
                '${fmtDate(trip.startDate)} – ${fmtDate(trip.endDate)}',
                style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Chip(
                      label: Text(
                        l10n.tripsNetSpend.toUpperCase(),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.16),
                      labelStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(money(net, currency: trip.currency), style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewTripDialog extends StatefulWidget {
  final AppDatabase db;
  const _NewTripDialog({required this.db});

  @override
  State<_NewTripDialog> createState() => _NewTripDialogState();
}

class _NewTripDialogState extends State<_NewTripDialog> {
  final _nameController = TextEditingController();
  final _destinationController = TextEditingController();
  DateTimeRange? _range;

  @override
  void dispose() {
    _nameController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _range = picked);
  }

  String _isoDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    await createTrip(
      widget.db,
      name: name,
      destination: _destinationController.text.trim().isEmpty ? null : _destinationController.text.trim(),
      startDate: _range == null ? null : _isoDate(_range!.start),
      endDate: _range == null ? null : _isoDate(_range!.end),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.tripsNew),
      content: SizedBox(
        width: (MediaQuery.of(context).size.width - 48).clamp(0, 360).toDouble(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.formName, hintText: l10n.formNamePlaceholder),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _destinationController,
              decoration: InputDecoration(labelText: l10n.formDestination, hintText: l10n.formDestPlaceholder),
            ),
            const SizedBox(height: 12),
            TextField(
              readOnly: true,
              onTap: _pickRange,
              controller: TextEditingController(
                text: _range == null ? '' : '${fmtDate(_isoDate(_range!.start))} – ${fmtDate(_isoDate(_range!.end))}',
              ),
              decoration: InputDecoration(labelText: l10n.formDates, hintText: l10n.formDatesPlaceholder),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.commonCancel)),
        ElevatedButton(
          onPressed: _nameController.text.trim().isEmpty ? null : _create,
          child: Text(l10n.commonCreate),
        ),
      ],
    );
  }
}
