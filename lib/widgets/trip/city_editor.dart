import 'package:flutter/material.dart';
import 'package:centavoo/confirm.dart';
import 'package:centavoo/data/database.dart';
import 'package:centavoo/data/repo.dart';
import 'package:centavoo/format.dart';
import 'package:centavoo/l10n/arb/app_localizations.dart';
import 'package:centavoo/stats/stats.dart';
import 'package:centavoo/theme.dart';
import 'package:centavoo/widgets/trip/primitives.dart';

class CityEditor extends StatefulWidget {
  final AppDatabase db;
  final String tripId;
  final List<String> days;
  final Map<String, String> cities;
  final List<String>? cityList;

  const CityEditor({
    super.key,
    required this.db,
    required this.tripId,
    required this.days,
    required this.cities,
    this.cityList,
  });

  @override
  State<CityEditor> createState() => _CityEditorState();
}

class _CityEditorState extends State<CityEditor> {
  CityBlock? _editing;
  String? _formCity;
  DateTimeRange? _formRange;
  bool _addingCity = false;
  final _newCityController = TextEditingController();

  @override
  void dispose() {
    _newCityController.dispose();
    super.dispose();
  }

  List<String> get _listValue {
    if (widget.cityList != null) return widget.cityList!;
    final distinct = widget.cities.values.where((c) => c.isNotEmpty).toSet().toList()..sort();
    return distinct;
  }

  void _resetForm() {
    setState(() {
      _editing = null;
      _formCity = null;
      _formRange = null;
    });
  }

  void _startEdit(CityBlock b) {
    setState(() {
      _editing = b;
      _formCity = b.city;
      _formRange = DateTimeRange(start: DateTime.parse(b.start), end: DateTime.parse(b.end));
    });
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _formRange,
    );
    if (picked != null) setState(() => _formRange = picked);
  }

  Future<void> _submit() async {
    final city = _formCity;
    final range = _formRange;
    if (city == null || range == null) return;
    if (_editing != null) {
      await setTripCityRange(widget.db, widget.tripId, _editing!.days, '');
    }
    await setTripCityRange(widget.db, widget.tripId, dateRange(isoDate(range.start), isoDate(range.end)), city);
    _resetForm();
  }

  Future<void> _removeBlock(CityBlock b) async {
    final l10n = AppLocalizations.of(context)!;
    await confirmDelete(context, l10n.cityRemoveBlockConfirm, () async {
      await setTripCityRange(widget.db, widget.tripId, b.days, '');
      if (_editing != null && _editing!.city == b.city && _editing!.start == b.start) _resetForm();
    });
  }

  Future<void> _removeCity(String city) async {
    final l10n = AppLocalizations.of(context)!;
    final daysUsed = widget.days.where((d) => widget.cities[d] == city).toList();
    Future<void> doRemove() async {
      if (daysUsed.isNotEmpty) {
        await setTripCityRange(widget.db, widget.tripId, daysUsed, '');
      }
      await updateTripCityList(widget.db, widget.tripId, _listValue.where((c) => c != city).toList());
    }

    if (daysUsed.isNotEmpty) {
      await confirmDelete(
        context,
        '$city — ${daysUsed.length} ${l10n.cityDaysN}. ${l10n.cityRemoveUsedWarning}',
        doRemove,
      );
    } else {
      await doRemove();
    }
  }

  void _cancelAddCity() {
    setState(() {
      _addingCity = false;
      _newCityController.clear();
    });
  }

  Future<void> _confirmAddCity() async {
    final v = _newCityController.text.trim();
    final alreadyExists = _listValue.any((c) => c.toLowerCase() == v.toLowerCase());
    if (v.isNotEmpty && !alreadyExists) {
      await updateTripCityList(widget.db, widget.tripId, [..._listValue, v]);
    }
    _cancelAddCity();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hintColor = Theme.of(context).hintColor;
    final blocks = groupCityBlocks(widget.days, widget.cities);
    final unassigned = widget.days.length - blocks.fold<int>(0, (n, b) => n + b.days.length);
    final listValue = _listValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.cityList, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final city in listValue)
              Chip(
                avatar: categoryDot(hexColor(colorForCity(city))),
                label: Text(city),
                onDeleted: () => _removeCity(city),
                deleteButtonTooltipMessage: '${l10n.cityRemoveCity} $city',
              ),
            if (_addingCity)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _newCityController,
                      autofocus: true,
                      decoration: InputDecoration(hintText: l10n.cityPlaceholder, isDense: true),
                      onSubmitted: (_) => _confirmAddCity(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check, size: 18),
                    tooltip: 'confirm-add-city',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                    onPressed: _confirmAddCity,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'cancel-add-city',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                    onPressed: _cancelAddCity,
                  ),
                ],
              )
            else
              ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: Text(l10n.cityAddCity),
                onPressed: () => setState(() => _addingCity = true),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: [
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<String>(
                key: ValueKey('city-select-${_editing?.start ?? 'new'}'),
                initialValue: _formCity,
                decoration: InputDecoration(labelText: l10n.cityBlockCityLabel),
                items: [for (final c in listValue) DropdownMenuItem(value: c, child: Text(c))],
                onChanged: (v) => setState(() => _formCity = v),
              ),
            ),
            SizedBox(
              width: 200,
              child: InkWell(
                onTap: _pickRange,
                child: InputDecorator(
                  decoration: InputDecoration(labelText: l10n.cityBlockRangeLabel),
                  child: Text(
                    _formRange == null
                        ? l10n.formDatesPlaceholder
                        : '${fmtDate(isoDate(_formRange!.start))} – ${fmtDate(isoDate(_formRange!.end))}',
                  ),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: (_formCity != null && _formRange != null) ? _submit : null,
              child: Text(_editing != null ? l10n.commonSave : l10n.cityAddBlock),
            ),
            if (_editing != null) TextButton(onPressed: _resetForm, child: Text(l10n.commonCancel)),
          ],
        ),
        const SizedBox(height: 12),
        if (blocks.isEmpty)
          Text(l10n.cityNoBlocks, style: TextStyle(fontSize: 13, color: hintColor))
        else
          for (final b in blocks)
            Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    categoryDot(hexColor(colorForCity(b.city))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(b.city, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text(
                            '${b.start == b.end ? fmtDate(b.start) : '${fmtDate(b.start)} – ${fmtDate(b.end)}'} · ${b.days.length} ${l10n.cityDaysN}',
                            style: TextStyle(fontSize: 12, color: hintColor),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'edit-city-block',
                      onPressed: () => _startEdit(b),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      tooltip: 'delete-city-block',
                      color: Colors.red,
                      onPressed: () => _removeBlock(b),
                    ),
                  ],
                ),
              ),
            ),
        if (unassigned > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('$unassigned ${l10n.cityUnassignedN}', style: TextStyle(fontSize: 12, color: hintColor)),
          ),
      ],
    );
  }
}
