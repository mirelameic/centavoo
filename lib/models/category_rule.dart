class CategoryRule {
  final int? id;
  final String keyword;
  final String categoryId;
  final String? categoryName;
  final int priority;

  CategoryRule({this.id, required this.keyword, required this.categoryId, this.categoryName, required this.priority});
}
