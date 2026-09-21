import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:centavoo/categorize.dart';
import 'package:centavoo/category_icons.dart';
import 'package:centavoo/data/database.dart';
import 'package:centavoo/data/repo.dart';
import 'package:centavoo/format.dart';
import 'package:centavoo/l10n/arb/app_localizations.dart';
import 'package:centavoo/models/category.dart';
import 'package:centavoo/models/category_rule.dart';
import 'package:centavoo/models/transaction.dart';
import 'package:centavoo/models/trip.dart' as model;
import 'package:centavoo/parse_table.dart';
import 'package:centavoo/theme.dart';

class ImportTransactions extends StatefulWidget {
  final AppDatabase db;
  final model.Trip trip;
  final List<Category> categories;
  final List<CategoryRule> rules;

  const ImportTransactions({
    super.key,
    required this.db,
    required this.trip,
    required this.categories,
    required this.rules,
  });

  @override
  State<ImportTransactions> createState() => _ImportTransactionsState();
}

class _ParsedRow {
  final String? date;
  final String description;
  final double? amount;
  final String kind;
  final String? categoryId;
  final bool isIof;
  final String period;
  final String? error;

  _ParsedRow({
    required this.date,
    required this.description,
    required this.amount,
    required this.kind,
    required this.categoryId,
    required this.isIof,
    required this.period,
    required this.error,
  });
}

class _ImportTransactionsState extends State<ImportTransactions> {
  final _rawTextController = TextEditingController();
  String _delimiter = delimiterAuto;
  bool _noRowsError = false;

  List<List<String>>? _rows;
  List<String> _roles = [];
  bool _hasHeader = false;
  bool _invertSign = false;
  final Set<int> _excluded = {};
  final Map<int, String?> _categoryOverrides = {};
  final Map<int, bool> _iofOverrides = {};
  bool _importing = false;

  @override
  void dispose() {
    _rawTextController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['csv', 'txt']);
    if (file == null) return;
    try {
      final bytes = await file.readAsBytes();
      setState(() => _rawTextController.text = utf8.decode(bytes));
    } catch (_) {
      setState(() => _noRowsError = true);
    }
  }

  void _handleContinue() {
    final parsed = splitRows(_rawTextController.text, delimiter: _delimiter);
    if (parsed.isEmpty) {
      setState(() => _noRowsError = true);
      return;
    }
    final guessedRoles = guessRoles(parsed);
    setState(() {
      _noRowsError = false;
      _rows = parsed;
      _roles = guessedRoles;
      _hasHeader = looksLikeHeaderRow(parsed, guessedRoles);
      _excluded.clear();
      _categoryOverrides.clear();
      _iofOverrides.clear();
    });
  }

  void _handleBack() => setState(() => _rows = null);

  List<List<String>> get _dataRows {
    final rows = _rows;
    if (rows == null) return const [];
    return _hasHeader ? rows.skip(1).toList() : rows;
  }

  List<_ParsedRow> get _parsedRows {
    final l10n = AppLocalizations.of(context)!;
    final dateCol = _roles.indexOf(colDate);
    final descCol = _roles.indexOf(colDescription);
    final amountCol = _roles.indexOf(colAmount);

    return [
      for (var i = 0; i < _dataRows.length; i++) _parseRow(l10n, _dataRows[i], i, dateCol, descCol, amountCol),
    ];
  }

  _ParsedRow _parseRow(AppLocalizations l10n, List<String> cols, int i, int dateCol, int descCol, int amountCol) {
    final description = descCol >= 0 ? cols[descCol].trim() : '';
    final dateRaw = dateCol >= 0 ? cols[dateCol].trim() : '';
    final date = dateRaw.isNotEmpty ? parseDate(dateRaw) : null;
    var amount = amountCol >= 0 ? parseAmount(cols[amountCol]) : null;
    if (amount != null && _invertSign) amount = -amount;

    String? error;
    if (amountCol < 0 || amount == null) {
      error = l10n.txImportErrAmount;
    } else if (description.isEmpty) {
      error = l10n.txImportErrDescription;
    } else if (dateRaw.isNotEmpty && date == null) {
      error = l10n.txImportErrDate;
    }

    final kind = deriveKind(amount);

    final suggested = error == null ? suggestCategory(description, widget.rules) : null;
    final categoryId = kind == kindRefund
        ? null
        : (_categoryOverrides[i] ?? (suggested != null && widget.categories.any((c) => c.id == suggested) ? suggested : null));

    final isIof = _iofOverrides[i] ?? deriveIsIof(kind, description);

    final period = periodForDate(date, widget.trip.startDate) ?? periodDuring;

    return _ParsedRow(
      date: date,
      description: description,
      amount: amount,
      kind: kind,
      categoryId: categoryId,
      isIof: isIof,
      period: period,
      error: error,
    );
  }

  Future<void> _handleImport() async {
    final l10n = AppLocalizations.of(context)!;
    final parsed = _parsedRows;
    final toInsert = [
      for (var i = 0; i < parsed.length; i++)
        if (parsed[i].error == null && !_excluded.contains(i)) parsed[i],
    ];
    if (toInsert.isEmpty) return;

    setState(() => _importing = true);
    try {
      await bulkAddTransactions(
        widget.db,
        [
          for (final r in toInsert)
            TransactionsTableCompanion.insert(
              id: '',
              tripId: widget.trip.id,
              period: r.period,
              date: Value(r.date),
              description: r.description,
              amount: r.amount!,
              categoryId: Value(r.categoryId),
              kind: r.kind,
              isIof: r.isIof,
              splitCount: 1,
              createdAt: '',
            ),
        ],
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${toInsert.length} ${l10n.txImportSuccessSuffix}')));
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.txImportError)));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dialogWidth = (MediaQuery.of(context).size.width - 48).clamp(0, 600).toDouble();
    return AlertDialog(
      title: Text(l10n.txImportTitle),
      content: SizedBox(
        width: dialogWidth,
        child: _rows == null ? _pasteStep(context, l10n) : _previewStep(context, l10n),
      ),
      actions: _rows == null
          ? [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.commonCancel)),
              ElevatedButton(
                onPressed: _rawTextController.text.trim().isEmpty ? null : _handleContinue,
                child: Text(l10n.txImportContinue),
              ),
            ]
          : null,
    );
  }

  Widget _pasteStep(BuildContext context, AppLocalizations l10n) {
    final hintColor = Theme.of(context).hintColor;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.txImportIntro, style: TextStyle(fontSize: 13, color: hintColor)),
          const SizedBox(height: 16),
          TextField(
            controller: _rawTextController,
            minLines: 6,
            maxLines: 12,
            decoration: InputDecoration(
              labelText: l10n.txImportPasteLabel,
              hintText: l10n.txImportPastePlaceholder,
              alignLabelWithHint: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 48),
                child: OutlinedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: Text(l10n.txImportUploadButton, overflow: TextOverflow.ellipsis),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  initialValue: _delimiter,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.txImportDelimiter),
                  items: [
                    DropdownMenuItem(value: delimiterAuto, child: Text(l10n.txImportDelimiterAuto)),
                    DropdownMenuItem(value: delimiterComma, child: Text(l10n.txImportDelimiterComma)),
                    DropdownMenuItem(value: delimiterSemicolon, child: Text(l10n.txImportDelimiterSemicolon)),
                    DropdownMenuItem(value: delimiterTab, child: Text(l10n.txImportDelimiterTab)),
                  ],
                  onChanged: (v) => setState(() => _delimiter = v ?? delimiterAuto),
                ),
              ),
            ],
          ),
          if (_noRowsError) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: borderRadiusLg,
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l10n.txImportNoRows, style: const TextStyle(color: Colors.red))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _previewStep(BuildContext context, AppLocalizations l10n) {
    final hintColor = Theme.of(context).hintColor;
    final parsedRows = _parsedRows;
    final validCount = [for (var i = 0; i < parsedRows.length; i++) if (parsedRows[i].error == null && !_excluded.contains(i)) i].length;
    final errorCount = parsedRows.where((r) => r.error != null).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 24,
          runSpacing: 8,
          children: [
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              visualDensity: VisualDensity.compact,
              title: Text(l10n.txImportHasHeader),
              value: _hasHeader,
              onChanged: (v) => setState(() => _hasHeader = v ?? false),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              visualDensity: VisualDensity.compact,
              title: Text(l10n.txImportInvertSign),
              value: _invertSign,
              onChanged: (v) => setState(() => _invertSign = v ?? false),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(l10n.txImportMapHint, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            for (var i = 0; i < _roles.length; i++)
              SizedBox(
                width: 160,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.txImportColumnN('${i + 1}'), style: TextStyle(fontSize: 11, color: hintColor)),
                    const SizedBox(height: 2),
                    DropdownButtonFormField<String>(
                      initialValue: _roles[i],
                      isDense: true,
                      isExpanded: true,
                      decoration: const InputDecoration(isDense: true),
                      items: [
                        DropdownMenuItem(value: colIgnore, child: Text(l10n.txImportColIgnore)),
                        DropdownMenuItem(value: colDate, child: Text(l10n.tableDate)),
                        DropdownMenuItem(value: colDescription, child: Text(l10n.tableDescription)),
                        DropdownMenuItem(value: colAmount, child: Text(l10n.tableAmount)),
                      ],
                      onChanged: (v) => setState(() => _roles = [
                        for (var j = 0; j < _roles.length; j++) j == i ? (v ?? colIgnore) : _roles[j],
                      ]),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _dataRows.isNotEmpty && i < _dataRows[0].length && _dataRows[0][i].isNotEmpty
                          ? _dataRows[0][i]
                          : '—',
                      style: TextStyle(fontSize: 11, color: hintColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Scrollbar(
            child: ListView.builder(
              itemCount: parsedRows.length,
              itemBuilder: (context, i) => _previewRow(context, l10n, parsedRows[i], i),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                '$validCount ${l10n.txImportRowsReady}${errorCount > 0 ? ' · $errorCount ${l10n.txImportRowsSkipped}' : ''}',
                style: TextStyle(fontSize: 13, color: hintColor),
              ),
            ),
            TextButton(onPressed: _handleBack, child: Text(l10n.txImportBack)),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: validCount == 0 || _importing ? null : _handleImport,
              child: _importing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('${l10n.txImportConfirmButton} ($validCount)'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _previewRow(BuildContext context, AppLocalizations l10n, _ParsedRow r, int i) {
    final hintColor = Theme.of(context).hintColor;
    final excluded = _excluded.contains(i);
    return Opacity(
      opacity: r.error != null || excluded ? 0.5 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: !excluded,
              onChanged: r.error != null
                  ? null
                  : (_) => setState(() {
                      if (excluded) {
                        _excluded.remove(i);
                      } else {
                        _excluded.add(i);
                      }
                    }),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(r.description.isEmpty ? '—' : r.description, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 5,
                    children: [
                      Text(r.date ?? '—', style: TextStyle(fontSize: 12, color: hintColor)),
                      Text('·', style: TextStyle(color: hintColor.withValues(alpha: 0.5))),
                      Text(
                        r.period == periodBefore ? l10n.periodBefore : l10n.periodDuring,
                        style: TextStyle(fontSize: 12, color: hintColor),
                      ),
                      Text('·', style: TextStyle(color: hintColor.withValues(alpha: 0.5))),
                      Text(
                        r.error ?? l10n.txImportRowOk,
                        style: TextStyle(fontSize: 12, color: r.error != null ? Colors.red : _tealColor),
                      ),
                    ],
                  ),
                  if (r.kind == kindRefund)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: (r.isIof ? hintColor : _tealColor).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              r.isIof ? 'IOF' : l10n.typeRefund,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: r.isIof ? hintColor : _tealColor),
                            ),
                          ),
                          SizedBox(
                            height: 28,
                            child: CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              title: Text(l10n.typeIof, style: const TextStyle(fontSize: 12)),
                              value: r.isIof,
                              onChanged: r.error != null ? null : (v) => setState(() => _iofOverrides[i] = v ?? false),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<String?>(
                          initialValue: r.categoryId,
                          isDense: true,
                          isExpanded: true,
                          decoration: const InputDecoration(isDense: true, hintText: '—'),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('—')),
                            for (final c in widget.categories)
                              DropdownMenuItem(
                                value: c.id,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(categoryIcon(c.icon) ?? Icons.category_outlined, size: 14, color: hexColor(c.color)),
                                    const SizedBox(width: 6),
                                    Text(c.name, style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                              ),
                          ],
                          onChanged: r.error != null ? null : (v) => setState(() => _categoryOverrides[i] = v),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              r.amount != null ? r.amount!.toStringAsFixed(2) : '—',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

const _tealColor = Color(0xFF12B886);
