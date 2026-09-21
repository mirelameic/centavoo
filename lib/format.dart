import 'package:intl/intl.dart';
import 'package:centavoo/models/transaction.dart' show periodBefore, periodDuring;

String appLocale = 'pt_BR';

String money(double n, {String currency = 'BRL', String? locale}) {
  final loc = locale ?? appLocale;
  final symbol = currency == 'BRL' ? 'R\$' : currency;
  final isNegative = n < 0;
  final valueStr = NumberFormat.currency(locale: loc, symbol: '', decimalDigits: 2).format(n.abs()).trim();
  return '${isNegative ? '-' : ''}$symbol $valueStr';
}

double? parseAmountInput(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;
  final hasDot = s.contains('.');
  final hasComma = s.contains(',');
  if (hasDot && hasComma) {
    final lastDot = s.lastIndexOf('.');
    final lastComma = s.lastIndexOf(',');
    s = lastComma > lastDot ? s.replaceAll('.', '').replaceAll(',', '.') : s.replaceAll(',', '');
  } else if (hasComma) {
    s = s.replaceAll(',', '.');
  }
  return double.tryParse(s);
}

String fmtDate(String? d, {String? locale}) {
  if (d == null) return '—';
  final loc = locale ?? appLocale;
  final date = DateTime.parse(d);
  final pattern = loc.startsWith('en') ? 'MMM d' : "dd 'de' MMM";
  return DateFormat(pattern, loc).format(date);
}

String? periodForDate(String? date, String? tripStartDate) {
  if (date == null || tripStartDate == null) return null;
  return date.compareTo(tripStartDate) < 0 ? periodBefore : periodDuring;
}

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

List<String> dateRange(String start, String end) {
  final out = <String>[];
  final endDate = DateTime.parse('${end}T00:00:00');
  for (var d = DateTime.parse('${start}T00:00:00'); !d.isAfter(endDate); d = d.add(const Duration(days: 1))) {
    out.add(isoDate(d));
  }
  return out;
}

class CityBlock {
  final String city;
  final String start;
  final String end;
  final List<String> days;

  CityBlock({required this.city, required this.start, required this.end, required this.days});
}

bool _isNextDay(String a, String b) {
  final d = DateTime.parse('${a}T00:00:00').add(const Duration(days: 1));
  return isoDate(d) == b;
}

List<CityBlock> groupCityBlocks(List<String> days, Map<String, String> cities) {
  final blocks = <CityBlock>[];
  for (final d in days) {
    final city = cities[d];
    if (city == null || city.isEmpty) continue;
    final last = blocks.isNotEmpty ? blocks.last : null;
    if (last != null && last.city == city && _isNextDay(last.end, d)) {
      blocks[blocks.length - 1] = CityBlock(city: city, start: last.start, end: d, days: [...last.days, d]);
    } else {
      blocks.add(CityBlock(city: city, start: d, end: d, days: [d]));
    }
  }
  return blocks;
}
