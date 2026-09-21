import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:centavoo/category_icons.dart';
import 'package:centavoo/data/database.dart';
import 'package:centavoo/data/repo.dart';
import 'package:centavoo/l10n/arb/app_localizations.dart';
import 'package:centavoo/models/category.dart';
import 'package:centavoo/theme.dart';

const _colorOptions = [
  '#0E8C6B', '#3D8B4C', '#6B8A1E', '#8A7220', '#B8860B', '#C2540D',
  '#C1352E', '#B23368', '#7D1F44', '#9C4221', '#7A4A2A', '#4F7942',
  '#0F7A82', '#5C5650', '#3A3733', '#A8481F',
];
const _defaultColor = '#C2540D';

class CategoryForm extends StatefulWidget {
  final AppDatabase db;
  final String tripId;
  final Category? editing;

  const CategoryForm({super.key, required this.db, required this.tripId, this.editing});

  @override
  State<CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<CategoryForm> {
  late final TextEditingController _nameController;
  late String _color;
  late String _icon;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.editing?.name ?? '');
    _color = widget.editing?.color ?? _defaultColor;
    _icon = widget.editing?.icon ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    if (widget.editing != null) {
      await updateCategory(
        widget.db,
        widget.editing!.id,
        CategoriesTableCompanion(
          name: Value(name),
          color: Value(_color),
          icon: Value(_icon.isEmpty ? null : _icon),
        ),
      );
    } else {
      await addCategory(
        widget.db,
        tripId: widget.tripId,
        name: name,
        color: _color,
        icon: _icon.isEmpty ? null : _icon,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hintColor = Theme.of(context).hintColor;
    final primary = Theme.of(context).colorScheme.primary;
    return AlertDialog(
      title: Text(widget.editing != null ? l10n.commonEdit : l10n.catNew),
      content: SizedBox(
        width: dialogWidth(context, 340),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                autofocus: true,
                decoration: InputDecoration(labelText: l10n.formName),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              Text(l10n.catColor, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: hintColor)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in _colorOptions)
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setState(() => _color = c),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(color: hexColor(c), shape: BoxShape.circle),
                        child: _color == c ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(l10n.catIcon, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: hintColor)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final key in iconOptions)
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _icon = _icon == key ? '' : key),
                      child: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _icon == key ? primary : Theme.of(context).dividerColor,
                            width: _icon == key ? 2 : 1,
                          ),
                          color: _icon == key ? primary.withValues(alpha: 0.12) : null,
                        ),
                        child: Icon(categoryIcon(key), size: 20, color: _icon == key ? primary : hintColor),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.commonCancel)),
        ElevatedButton(
          onPressed: _nameController.text.trim().isEmpty ? null : _save,
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}
