import 'package:centavoo/models/category.dart';
import 'package:centavoo/models/category_rule.dart';

String? _resolveCategoryId(CategoryRule rule, List<Category> categories) {
  for (final c in categories) {
    if (c.id == rule.categoryId) return c.id;
  }
  final name = rule.categoryName?.trim().toLowerCase();
  if (name == null || name.isEmpty) return null;
  for (final c in categories) {
    if (c.name.trim().toLowerCase() == name) return c.id;
  }
  return null;
}

String? suggestCategory(String description, List<CategoryRule> rules, List<Category> categories) {
  final d = description.toLowerCase();
  CategoryRule? best;
  String? bestId;
  for (final r in rules) {
    if (!d.contains(r.keyword.toLowerCase())) continue;
    final id = _resolveCategoryId(r, categories);
    if (id == null) continue;
    if (best == null ||
        r.priority > best.priority ||
        (r.priority == best.priority && r.keyword.length > best.keyword.length)) {
      best = r;
      bestId = id;
    }
  }
  return bestId;
}
