import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:centavoo/category_icons.dart';
import 'package:centavoo/confirm.dart';
import 'package:centavoo/data/database.dart';
import 'package:centavoo/data/mappers.dart';
import 'package:centavoo/data/repo.dart';
import 'package:centavoo/theme.dart';
import 'package:centavoo/widgets/category_form.dart';

class CategoriesScreen extends StatelessWidget {
  final String tripId;

  const CategoriesScreen({super.key, required this.tripId});

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AppDatabase>();
    return StreamBuilder<List<CategoryRow>>(
      stream: (db.select(db.categoriesTable)
            ..where((c) => c.tripId.equals(tripId))
            ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
          .watch(),
      builder: (context, snap) {
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
                    onTap: () => context.go('/trip/$tripId'),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back, size: 16),
                          SizedBox(width: 4),
                          Text('Voltar'),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Categorias',
                        style: unboundedStyle(weight: FontWeight.w500).copyWith(fontSize: 26, height: 1.35),
                      ),
                      const SizedBox(width: 12),
                      IconButton.filled(
                        onPressed: () => showDialog(
                          context: context,
                          builder: (_) => CategoryForm(db: db, tripId: tripId),
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
                        child: Text('Nenhuma categoria.', style: TextStyle(color: hintColor)),
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
                                builder: (_) => CategoryForm(db: db, tripId: tripId, editing: c),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              tooltip: 'delete',
                              color: Colors.red,
                              onPressed: () => confirmDelete(
                                context,
                                'Excluir categoria? As transações dela ficam sem categoria.',
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
