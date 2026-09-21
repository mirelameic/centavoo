import 'package:centavoo/models/transaction.dart';
import 'package:centavoo/models/category.dart';

double cost(Transaction t) => t.amount / (t.splitCount == 0 ? 1 : t.splitCount);

const cityPalette = [
  '#C2540D', '#0E8C6B', '#B8860B', '#B23368', '#7A4A2A',
  '#3D8B4C', '#C1352E', '#6B8A1E', '#7D1F44', '#5C5650',
];

String colorForCity(String name) {
  int h = 0;
  for (final unit in name.codeUnits) {
    h = (h * 31 + unit) & 0xFFFFFFFF;
  }
  return cityPalette[h % cityPalette.length];
}

class CatAgg {
  final String? id;
  final String name;
  final String color;
  final String? icon;
  double amount;

  CatAgg({this.id, required this.name, required this.color, this.icon, this.amount = 0});
}

class DayDatum {
  final String date;
  final Map<String, double> values;
  DayDatum(this.date, this.values);
}

class CumulativePoint {
  final String date;
  final double total;
  CumulativePoint(this.date, this.total);
}

class BeforeDuringRow {
  final String category;
  final double before;
  final double during;
  BeforeDuringRow(this.category, this.before, this.during);
}

class CityAgg {
  final String city;
  final double amount;
  final String color;
  CityAgg(this.city, this.amount, this.color);
}

class CityRow {
  final String city;
  final int days;
  final double total;
  final double avgPerDay;
  final String topCategory;
  CityRow(this.city, this.days, this.total, this.avgPerDay, this.topCategory);
}

class CategoryTableRow {
  final String name;
  final String color;
  final String? icon;
  final double total;
  final double pct;
  final int count;
  final double avgTicket;
  CategoryTableRow(this.name, this.color, this.icon, this.total, this.pct, this.count, this.avgTicket);
}

class SplitSummary {
  final double integral;
  final double share;
  final double savings;
  SplitSummary(this.integral, this.share, this.savings);
}

class UsedCategory {
  final String name;
  final String color;
  UsedCategory(this.name, this.color);
}

class TripStats {
  final double gross;
  final double refunds;
  final double net;
  final double before;
  final double during;
  final double iofRefund;
  final int days;
  final double avgPerDay;
  final List<CatAgg> byCategory;
  final List<UsedCategory> usedCategories;
  final List<DayDatum> dayData;
  final List<CumulativePoint> cumulativeByDay;
  final List<BeforeDuringRow> beforeDuringData;
  final List<CityAgg> byCity;
  final List<double> weekdayAmounts;
  final List<CityRow> cityTable;
  final List<CategoryTableRow> categoryTable;
  final SplitSummary split;

  TripStats({
    required this.gross,
    required this.refunds,
    required this.net,
    required this.before,
    required this.during,
    required this.iofRefund,
    required this.days,
    required this.avgPerDay,
    required this.byCategory,
    required this.usedCategories,
    required this.dayData,
    required this.cumulativeByDay,
    required this.beforeDuringData,
    required this.byCity,
    required this.weekdayAmounts,
    required this.cityTable,
    required this.categoryTable,
    required this.split,
  });
}

double round(double n) => (n * 100).round() / 100;

class _NameColor {
  final String name;
  final String color;
  const _NameColor(this.name, this.color);
}

const _noCat = _NameColor('No category', '#adb5bd');
const _iofCat = _NameColor('IOF refund', '#868e96');

TripStats computeStats(List<Transaction> txs, List<Category> cats, [Map<String, String>? cities]) {
  final cityMapArg = cities ?? {};
  final catById = {for (final c in cats) c.id: c};
  _NameColor catNameColorOf(Transaction t) {
    if (t.isIof) return _iofCat;
    if (t.categoryId == null) return _noCat;
    final c = catById[t.categoryId];
    if (c == null) return _noCat;
    return _NameColor(c.name, c.color);
  }

  String? cityOf(Transaction t) {
    if (t.date == null) return null;
    final v = cityMapArg[t.date];
    return (v == null || v.isEmpty) ? null : v;
  }

  double gross = 0, refunds = 0, before = 0, during = 0, iofRefund = 0;
  final days = <String>{};

  final byCat = <String, CatAgg>{};
  final dailyDuring = <String, double>{};
  final dayMap = <String, Map<String, double>>{};
  final bdMap = <String, List<double>>{};
  final cityMap = <String, double>{};
  final weekday = List<double>.filled(7, 0);
  final catCount = <String, int>{};
  final cityDays = <String, Set<String>>{};
  final cityCat = <String, Map<String, double>>{};
  double integralExp = 0;

  for (final t in txs) {
    final c = cost(t);
    final catNameColor = catNameColorOf(t);
    final categoryIcon = (!t.isIof && t.categoryId != null) ? catById[t.categoryId]?.icon : null;
    if (c >= 0) {
      gross += c;
    } else {
      refunds += c;
    }
    if (t.period == periodBefore) {
      before += c;
    } else {
      during += c;
    }
    if (t.isIof) iofRefund += c;
    if (t.period == periodDuring && t.date != null) {
      days.add(t.date!);
      dailyDuring[t.date!] = (dailyDuring[t.date!] ?? 0) + c;
    }

    if (c > 0) {
      final key = t.categoryId ?? catNameColor.name;
      final agg = byCat[key] ??
          CatAgg(id: t.categoryId, name: catNameColor.name, color: catNameColor.color, icon: categoryIcon);
      agg.amount += c;
      byCat[key] = agg;
      catCount[key] = (catCount[key] ?? 0) + 1;
      integralExp += t.amount;

      if (t.period == periodDuring && t.date != null) {
        final dm = dayMap[t.date!] ?? {};
        dm[catNameColor.name] = (dm[catNameColor.name] ?? 0) + c;
        dayMap[t.date!] = dm;
        final parsed = DateTime.parse('${t.date!}T00:00:00');
        weekday[parsed.weekday % 7] += c;
      }

      final bd = bdMap[catNameColor.name] ?? [0, 0];
      if (t.period == periodBefore) {
        bd[0] += c;
      } else {
        bd[1] += c;
      }
      bdMap[catNameColor.name] = bd;

      final cy = cityOf(t);
      if (cy != null) {
        cityMap[cy] = (cityMap[cy] ?? 0) + c;
        if (t.date != null) {
          (cityDays[cy] ??= {}).add(t.date!);
        }
        final cc = cityCat[cy] ??= {};
        cc[catNameColor.name] = (cc[catNameColor.name] ?? 0) + c;
      }
    }
  }

  final byCategory = byCat.values.toList()..sort((a, b) => b.amount.compareTo(a.amount));
  final usedCategories = byCategory.map((c) => UsedCategory(c.name, c.color)).toList();

  final dayEntries = dayMap.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  final dayData = dayEntries.map((e) {
    final parts = e.key.split('-');
    return DayDatum('${parts[2]}/${parts[1]}', e.value.map((k, v) => MapEntry(k, round(v))));
  }).toList();

  final beforeDuringRows = bdMap.entries
      .map((e) => BeforeDuringRow(e.key, round(e.value[0]), round(e.value[1])))
      .where((r) => r.before != 0 || r.during != 0)
      .toList()
    ..sort((a, b) => (b.before + b.during).compareTo(a.before + a.during));

  double running = 0;
  final dailyEntries = dailyDuring.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  final cumulativeByDay = dailyEntries.map((e) {
    running += e.value;
    final parts = e.key.split('-');
    return CumulativePoint('${parts[2]}/${parts[1]}', round(running));
  }).toList();

  final byCity = _paletteByCity(cityMap);
  final weekdayAmounts = weekday.map(round).toList();

  final totalCat = byCategory.fold<double>(0, (s, c) => s + c.amount);
  final totalCatOrOne = totalCat == 0 ? 1 : totalCat;
  final categoryTable = byCategory.map((c) {
    final count = catCount[c.id ?? c.name] ?? 0;
    return CategoryTableRow(
      c.name,
      c.color,
      c.icon,
      round(c.amount),
      round((c.amount / totalCatOrOne) * 100),
      count,
      count > 0 ? round(c.amount / count) : 0,
    );
  }).toList();

  final cityTable = _buildCityTable(byCity, cityDays, cityCat);

  final split = SplitSummary(round(integralExp), round(gross), round(integralExp - gross));

  final nDays = days.length;
  return TripStats(
    gross: round(gross),
    refunds: round(refunds),
    net: round(gross + refunds),
    before: round(before),
    during: round(during),
    iofRefund: round(iofRefund),
    days: nDays,
    avgPerDay: nDays > 0 ? round(during / nDays) : 0,
    byCategory: byCategory.map((c) => CatAgg(id: c.id, name: c.name, color: c.color, icon: c.icon, amount: round(c.amount))).toList(),
    usedCategories: usedCategories,
    dayData: dayData,
    cumulativeByDay: cumulativeByDay,
    beforeDuringData: beforeDuringRows,
    byCity: byCity,
    weekdayAmounts: weekdayAmounts,
    cityTable: cityTable,
    categoryTable: categoryTable,
    split: split,
  );
}

class CityBreakdownResult {
  final List<CityAgg> byCity;
  final List<CityRow> cityTable;
  CityBreakdownResult(this.byCity, this.cityTable);
}

CityBreakdownResult cityBreakdown(
  List<Transaction> txs,
  List<Category> cats,
  Map<String, String> cities, [
  Set<String>? allowed,
]) {
  final catById = {for (final c in cats) c.id: c};
  final cityMap = <String, double>{};
  final cityDays = <String, Set<String>>{};
  final cityCat = <String, Map<String, double>>{};
  for (final t in txs) {
    final c = cost(t);
    if (c <= 0) continue;
    if (allowed != null && (t.categoryId == null || !allowed.contains(t.categoryId))) continue;
    if (t.date == null) continue;
    final cy = cities[t.date];
    if (cy == null || cy.isEmpty) continue;
    cityMap[cy] = (cityMap[cy] ?? 0) + c;
    (cityDays[cy] ??= {}).add(t.date!);
    final cn = (t.categoryId != null ? catById[t.categoryId]?.name : null) ?? '—';
    final cc = cityCat[cy] ??= {};
    cc[cn] = (cc[cn] ?? 0) + c;
  }
  final byCity = _paletteByCity(cityMap);
  return CityBreakdownResult(byCity, _buildCityTable(byCity, cityDays, cityCat));
}

List<CityAgg> _paletteByCity(Map<String, double> cityMap) {
  final entries = cityMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return entries.map((e) => CityAgg(e.key, round(e.value), colorForCity(e.key))).toList();
}

List<CityRow> _buildCityTable(
  List<CityAgg> byCity,
  Map<String, Set<String>> cityDays,
  Map<String, Map<String, double>> cityCat,
) {
  return byCity.map((cc) {
    final days = cityDays[cc.city]?.length ?? 0;
    final cm = cityCat[cc.city];
    String topCategory = '—';
    if (cm != null && cm.isNotEmpty) {
      final sorted = cm.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      topCategory = sorted.first.key;
    }
    return CityRow(cc.city, days, cc.amount, days > 0 ? round(cc.amount / days) : cc.amount, topCategory);
  }).toList();
}
