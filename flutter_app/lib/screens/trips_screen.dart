import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:centavoo/data/database.dart';
import 'package:centavoo/data/mappers.dart';
import 'package:centavoo/data/repo.dart';
import 'package:centavoo/format.dart';
import 'package:centavoo/stats/stats.dart';
import 'package:centavoo/theme.dart';

const _containerMaxWidth = 1140.0;
const _gridGap = 16.0;

int _columnsFor(double viewportWidth) {
  if (viewportWidth >= 1200) return 3;
  if (viewportWidth >= 768) return 2;
  return 1;
}

class TripsScreen extends StatelessWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();

    return StreamBuilder<List<TripRow>>(
      stream: (db.select(db.tripsTable)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch(),
      builder: (context, tripsSnapshot) {
        final trips = tripsSnapshot.data ?? const <TripRow>[];
        return StreamBuilder<List<TransactionRow>>(
          stream: db.select(db.transactionsTable).watch(),
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
                              Text('Minhas viagens', style: unboundedStyle(weight: FontWeight.w500).copyWith(fontSize: 28)),
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
                                    Text('Nenhuma viagem ainda.', style: TextStyle(color: Theme.of(context).hintColor)),
                                    const SizedBox(height: 12),
                                    ElevatedButton.icon(
                                      onPressed: () => _openNewTripDialog(context, db),
                                      icon: const Icon(Icons.add),
                                      label: const Text('Criar a primeira'),
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
                                        for (final trip in trips)
                                          SizedBox(
                                            width: cardWidth,
                                            child: _TripCard(
                                              trip: trip,
                                              net: netByTrip[trip.id] ?? 0,
                                              onTap: () => context.go('/trip/${trip.id}'),
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
}

class _TripCard extends StatelessWidget {
  final TripRow trip;
  final double net;
  final VoidCallback onTap;

  const _TripCard({required this.trip, required this.net, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: borderRadiusLg,
        onTap: onTap,
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
                    Text(trip.destination!, style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor)),
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
                      label: const Text(
                        'GASTO LÍQUIDO',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
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
    return AlertDialog(
      title: const Text('Nova viagem'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nome', hintText: 'ex. Europa 2025'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _destinationController,
              decoration: const InputDecoration(labelText: 'Destino', hintText: 'ex. Espanha · Grécia'),
            ),
            const SizedBox(height: 12),
            TextField(
              readOnly: true,
              onTap: _pickRange,
              controller: TextEditingController(
                text: _range == null ? '' : '${fmtDate(_isoDate(_range!.start))} – ${fmtDate(_isoDate(_range!.end))}',
              ),
              decoration: const InputDecoration(labelText: 'Período', hintText: 'início – fim'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _nameController.text.trim().isEmpty ? null : _create,
          child: const Text('Criar'),
        ),
      ],
    );
  }
}
