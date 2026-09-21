class Category {
  final String id;
  final String tripId;
  final String name;
  final String color;
  final String? icon;
  final int sortOrder;

  Category({
    required this.id,
    required this.tripId,
    required this.name,
    required this.color,
    this.icon,
    required this.sortOrder,
  });
}
