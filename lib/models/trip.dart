typedef CityMap = Map<String, String>;

class Trip {
  final String id;
  final String name;
  final String? destination;
  final String? startDate;
  final String? endDate;
  final String currency;
  final String? notes;
  final CityMap cities;
  final List<String>? cityList;
  final String createdAt;

  Trip({
    required this.id,
    required this.name,
    this.destination,
    this.startDate,
    this.endDate,
    required this.currency,
    this.notes,
    CityMap? cities,
    this.cityList,
    required this.createdAt,
  }) : cities = cities ?? {};
}
