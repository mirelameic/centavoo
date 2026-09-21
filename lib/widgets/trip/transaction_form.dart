import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:centavoo/categorize.dart';
import 'package:centavoo/data/database.dart';
import 'package:centavoo/data/repo.dart';
import 'package:centavoo/format.dart';
import 'package:centavoo/l10n/arb/app_localizations.dart';
import 'package:centavoo/models/category.dart';
import 'package:centavoo/models/category_rule.dart';
import 'package:centavoo/models/transaction.dart';
import 'package:centavoo/models/trip.dart' as model;
import 'package:centavoo/theme.dart';
import 'package:centavoo/widgets/trip/primitives.dart';

class TransactionForm extends StatefulWidget {
  final AppDatabase db;
  final model.Trip trip;
  final List<Category> categories;
  final List<CategoryRule> rules;
  final Transaction? editing;

  const TransactionForm({
    super.key,
    required this.db,
    required this.trip,
    required this.categories,
    required this.rules,
    this.editing,
  });

  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  late final TextEditingController _descriptionController;
  late final TextEditingController _amountController;
  late final TextEditingController _splitController;
  String? _date;
  String _kind = kindExpense;
  bool _isIof = false;
  String? _categoryId;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    _date = editing != null ? editing.date : widget.trip.startDate;
    _descriptionController = TextEditingController(text: editing?.description ?? '');
    _amountController = TextEditingController(text: editing != null ? editing.amount.abs().toStringAsFixed(2) : '');
    _splitController = TextEditingController(text: (editing != null && editing.splitCount > 1) ? '${editing.splitCount}' : '1');
    _kind = editing?.kind ?? kindExpense;
    _isIof = editing?.isIof ?? false;
    _categoryId = editing?.categoryId;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _splitController.dispose();
    super.dispose();
  }

  double? get _amount => parseAmountInput(_amountController.text);

  bool get _valid => _descriptionController.text.trim().isNotEmpty && (_amount ?? 0) > 0;

  void _suggestFromDescription() {
    if (_categoryId == null && _descriptionController.text.trim().isNotEmpty) {
      final suggested = suggestCategory(_descriptionController.text, widget.rules);
      if (suggested != null && widget.categories.any((c) => c.id == suggested)) {
        setState(() => _categoryId = suggested);
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date != null ? DateTime.parse(_date!) : DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _date = '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _save() async {
    if (!_valid) return;
    final abs = _amount!.abs();
    final signed = _kind == kindExpense ? abs : -abs;
    final period = periodForDate(_date, widget.trip.startDate) ?? widget.editing?.period ?? periodDuring;
    final splitCount = int.tryParse(_splitController.text) ?? 1;
    final categoryId = _kind == kindExpense ? _categoryId : null;

    if (widget.editing != null) {
      await updateTransaction(
        widget.db,
        widget.editing!.id,
        TransactionsTableCompanion(
          period: Value(period),
          date: Value(_date),
          description: Value(_descriptionController.text.trim()),
          amount: Value(signed),
          categoryId: Value(categoryId),
          kind: Value(_kind),
          isIof: Value(_kind == kindRefund && _isIof),
          splitCount: Value(splitCount < 1 ? 1 : splitCount),
        ),
      );
    } else {
      await addTransaction(
        widget.db,
        TransactionsTableCompanion.insert(
          id: '',
          tripId: widget.trip.id,
          period: period,
          date: Value(_date),
          description: _descriptionController.text.trim(),
          amount: signed,
          categoryId: Value(categoryId),
          kind: _kind,
          isIof: _kind == kindRefund && _isIof,
          splitCount: splitCount < 1 ? 1 : splitCount,
          createdAt: '',
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.editing != null ? l10n.txEdit : l10n.txNew),
      content: SizedBox(
        width: dialogWidth(context, 360),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                readOnly: true,
                onTap: _pickDate,
                controller: TextEditingController(text: _date == null ? '' : fmtDate(_date)),
                decoration: InputDecoration(labelText: l10n.tableDate, hintText: '—'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                autofocus: true,
                decoration: InputDecoration(labelText: l10n.tableDescription),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _suggestFromDescription(),
                onEditingComplete: _suggestFromDescription,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: l10n.tableAmount, prefixText: widget.trip.currency == 'BRL' ? 'R\$ ' : ''),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _splitController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: l10n.fieldSplit),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _kind,
                decoration: InputDecoration(labelText: l10n.fieldType),
                items: [
                  DropdownMenuItem(value: kindExpense, child: Text(l10n.typeExpense)),
                  DropdownMenuItem(value: kindRefund, child: Text(l10n.typeRefund)),
                ],
                onChanged: (v) => setState(() => _kind = v ?? kindExpense),
              ),
              if (_kind == kindRefund)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(l10n.typeIof),
                  value: _isIof,
                  onChanged: (v) => setState(() => _isIof = v ?? false),
                ),
              if (_kind == kindExpense) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _categoryId,
                  decoration: InputDecoration(labelText: l10n.tableCategory, hintText: '—'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('—')),
                    for (final c in widget.categories) categoryDropdownItem(c),
                  ],
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.commonCancel)),
        ElevatedButton(onPressed: _valid ? _save : null, child: Text(l10n.commonSave)),
      ],
    );
  }
}
