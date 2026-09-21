import 'package:centavoo/models/category_rule.dart';

String? suggestCategory(String description, List<CategoryRule> rules) {
  final d = description.toLowerCase();
  CategoryRule? best;
  for (final r in rules) {
    if (!d.contains(r.keyword.toLowerCase())) continue;
    if (best == null ||
        r.priority > best.priority ||
        (r.priority == best.priority && r.keyword.length > best.keyword.length)) {
      best = r;
    }
  }
  return best?.categoryId;
}
