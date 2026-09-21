class CategoryRule {
  final int? id;
  final String keyword;
  final String categoryId;
  final int priority;

  CategoryRule({
    this.id,
    required this.keyword,
    required this.categoryId,
    required this.priority,
  });
}
