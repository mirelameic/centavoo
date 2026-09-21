import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:centavoo/confirm.dart';
import 'package:centavoo/data/database.dart';
import 'package:centavoo/data/repo.dart';
import 'package:centavoo/format.dart';
import 'package:centavoo/models/trip.dart' as model;

class TripEditForm extends StatefulWidget {
  final AppDatabase db;
  final model.Trip trip;

  const TripEditForm({super.key, required this.db, required this.trip});

  @override
  State<TripEditForm> createState() => _TripEditFormState();
}

class _TripEditFormState extends State<TripEditForm> {
  late final TextEditingController _nameController;
  late final TextEditingController _destinationController;
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.trip.name);
    _destinationController = TextEditingController(text: widget.trip.destination ?? '');
    _range = (widget.trip.startDate != null && widget.trip.endDate != null)
        ? DateTimeRange(start: DateTime.parse(widget.trip.startDate!), end: DateTime.parse(widget.trip.endDate!))
        : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final startDate = _range == null ? null : _iso(_range!.start);
    final endDate = _range == null ? null : _iso(_range!.end);
    await updateTripDetails(
      widget.db,
      widget.trip.id,
      name: name,
      destination: _destinationController.text.trim().isEmpty ? null : _destinationController.text.trim(),
      startDate: startDate,
      endDate: endDate,
    );
    await reassignTransactionPeriods(widget.db, widget.trip.id, startDate);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    await confirmDelete(
      context,
      'Excluir esta viagem permanentemente? Todas as transações e categorias dela serão apagadas. Não dá pra desfazer.',
      () async {
        await deleteTrip(widget.db, widget.trip.id);
        if (mounted) {
          Navigator.of(context).pop();
          context.go('/');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar viagem'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nome'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _destinationController,
              decoration: const InputDecoration(labelText: 'Destino'),
            ),
            const SizedBox(height: 12),
            TextField(
              readOnly: true,
              onTap: _pickRange,
              controller: TextEditingController(
                text: _range == null ? '' : '${fmtDate(_iso(_range!.start))} – ${fmtDate(_iso(_range!.end))}',
              ),
              decoration: const InputDecoration(labelText: 'Período', hintText: 'início – fim'),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Excluir viagem'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _nameController.text.trim().isEmpty ? null : _save,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
