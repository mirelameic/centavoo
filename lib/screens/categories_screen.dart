import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:centavoo/category_icons.dart';
import 'package:centavoo/confirm.dart';
import 'package:centavoo/data/database.dart';
import 'package:centavoo/data/mappers.dart';
import 'package:centavoo/data/repo.dart';
import 'package:centavoo/l10n/arb/app_localizations.dart';
import 'package:centavoo/theme.dart';
import 'package:centavoo/widgets/category_form.dart';

class CategoriesScreen extends StatefulWidget {
  final String tripId;

  const CategoriesScreen({super.key, required this.tripId});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late Stream<List<CategoryRow>> _categoriesStream;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  @override
  void didUpdateWidget(CategoriesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tripId != widget.tripId) _initStream();
  }

  void _initStream() {
    final db = context.read<AppDatabase>();
    _categoriesStream = (db.select(db.categoriesTable)
          ..where((c) => c.tripId.equals(widget.tripId))
          ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
        .watch();
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();
    return StreamBuilder<List<CategoryRow>>(
      stream: _categoriesStream,
      builder: (context, snap) {
        final l10n = AppLocalizations.of(context)!;
        final cats = (snap.data ?? const <CategoryRow>[]).map(categoryFromRow).toList();
        final hintColor = Theme.of(context).hintColor;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    onTap: () => context.go('/trip/${widget.tripId}'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.arrow_back, size: 16),
                          const SizedBox(width: 4),
                          Text(l10n.commonBack),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.catTitle,
                        style: unboundedStyle(weight: FontWeight.w500).copyWith(fontSize: 26, height: 1.35),
                      ),
                      const SizedBox(width: 12),
                      IconButton.filled(
                        onPressed: () => showDialog(
                          context: context,
                          builder: (_) => CategoryForm(db: db, tripId: widget.tripId),
                        ),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (cats.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Text(l10n.catEmpty, style: TextStyle(color: hintColor)),
                      ),
                    ),
                  for (final c in cats)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(color: hexColor(c.color), borderRadius: BorderRadius.circular(4)),
                            ),
                            const SizedBox(width: 12),
                            if (categoryIcon(c.icon) != null) ...[
                              Icon(categoryIcon(c.icon), size: 16, color: hintColor),
                              const SizedBox(width: 8),
                            ],
                            Expanded(child: Text(c.name)),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              tooltip: 'edit',
                              onPressed: () => showDialog(
                                context: context,
                                builder: (_) => CategoryForm(db: db, tripId: widget.tripId, editing: c),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              tooltip: 'delete',
                              color: Colors.red,
                              onPressed: () => confirmDelete(
                                context,
                                l10n.catDeleteConfirm,
                                () => deleteCategory(db, c.id),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
