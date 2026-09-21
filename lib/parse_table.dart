import 'package:centavoo/models/transaction.dart' show kindExpense, kindRefund;

const colDate = 'date';
const colDescription = 'description';
const colAmount = 'amount';
const colIgnore = 'ignore';

const delimiterAuto = 'auto';
const delimiterComma = ',';
const delimiterSemicolon = ';';
const delimiterTab = '\t';

String deriveKind(double? amount) => (amount ?? 0) < 0 ? kindRefund : kindExpense;

bool deriveIsIof(String kind, String description) =>
    kind == kindRefund && description.toLowerCase().contains('iof');

List<String> _splitLine(String line, String delimiter) {
  final out = <String>[];
  var cur = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          cur.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        cur.write(c);
      }
    } else if (c == '"') {
      inQuotes = true;
    } else if (c == delimiter) {
      out.add(cur.toString().trim());
      cur = StringBuffer();
    } else {
      cur.write(c);
    }
  }
  out.add(cur.toString().trim());
  return out;
}

int _mostCommonCount(List<int> counts) {
  final tally = <int, int>{};
  for (final n in counts) {
    tally[n] = (tally[n] ?? 0) + 1;
  }
  return tally.values.reduce((a, b) => a > b ? a : b);
}

String _detectDelimiter(List<String> lines) {
  var best = delimiterComma;
  var bestScore = -1;
  for (final candidate in [delimiterTab, delimiterSemicolon, delimiterComma]) {
    final counts = lines.map((l) => _splitLine(l, candidate).length).toList();
    if (counts.reduce((a, b) => a > b ? a : b) < 2) continue;
    final score = _mostCommonCount(counts);
    if (score > bestScore) {
      bestScore = score;
      best = candidate;
    }
  }
  return best;
}

List<List<String>> splitRows(String text, {String delimiter = delimiterAuto}) {
  final lines = text
      .replaceAll(RegExp(r'\r\n?'), '\n')
      .split('\n')
      .where((l) => l.trim().isNotEmpty)
      .toList();
  if (lines.isEmpty) return [];

  final delim = delimiter == delimiterAuto ? _detectDelimiter(lines) : delimiter;
  final rows = lines.map((l) => _splitLine(l, delim)).toList();
  final width = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
  return rows.map((r) => r.length < width ? [...r, ...List.filled(width - r.length, '')] : r).toList();
}

double? parseAmount(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;

  var negative = false;
  if (RegExp(r'^\(.*\)$').hasMatch(s)) {
    negative = true;
    s = s.substring(1, s.length - 1);
  }
  s = s.replaceAll(RegExp(r'[^0-9.,-]'), '');
  if (s.startsWith('-')) {
    negative = true;
    s = s.substring(1);
  }
  if (s.endsWith('-')) {
    negative = true;
    s = s.substring(0, s.length - 1);
  }
  s = s.replaceAll('-', '');
  if (s.isEmpty) return null;

  final lastComma = s.lastIndexOf(',');
  final lastDot = s.lastIndexOf('.');
  String normalized;

  if (lastComma != -1 && lastDot != -1) {
    normalized = lastComma > lastDot ? s.replaceAll('.', '').replaceAll(',', '.') : s.replaceAll(',', '');
  } else if (lastComma != -1) {
    final decimals = s.length - lastComma - 1;
    final commaCount = RegExp(',').allMatches(s).length;
    final isDecimal = decimals == 2 && commaCount == 1;
    normalized = isDecimal ? s.replaceAll(',', '.') : s.replaceAll(',', '');
  } else if (lastDot != -1) {
    final decimals = s.length - lastDot - 1;
    final dotCount = RegExp(r'\.').allMatches(s).length;
    normalized = dotCount > 1 || decimals == 3 ? s.replaceAll('.', '') : s;
  } else {
    normalized = s;
  }

  final n = double.tryParse(normalized);
  if (n == null || !n.isFinite) return null;
  return negative ? -n : n;
}

String? _toIsoDate(int year, int month, int day) {
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  String pad(int n) => n.toString().padLeft(2, '0');
  return '$year-${pad(month)}-${pad(day)}';
}

String? parseDate(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;

  var m = RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})').firstMatch(s);
  if (m != null) {
    return _toIsoDate(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
  }

  m = RegExp(r'^(\d{1,2})[/.-](\d{1,2})[/.-](\d{2,4})').firstMatch(s);
  if (m != null) {
    final yearRaw = int.parse(m.group(3)!);
    final year = yearRaw < 100 ? 2000 + yearRaw : yearRaw;
    return _toIsoDate(year, int.parse(m.group(2)!), int.parse(m.group(1)!));
  }
  return null;
}

List<String> guessRoles(List<List<String>> rows) {
  final width = rows.isNotEmpty ? rows[0].length : 0;
  final roles = List<String>.filled(width, colIgnore);

  int scoreCol(int col, bool Function(String) test) =>
      rows.fold(0, (n, r) => n + (test(r[col]) ? 1 : 0));

  var dateCol = -1;
  var dateScore = 0;
  for (var c = 0; c < width; c++) {
    final s = scoreCol(c, (v) => parseDate(v) != null);
    if (s > dateScore) {
      dateScore = s;
      dateCol = c;
    }
  }
  if (dateCol >= 0 && dateScore > 0) roles[dateCol] = colDate;

  var amountCol = -1;
  var amountScore = 0;
  for (var c = 0; c < width; c++) {
    if (c == dateCol) continue;
    final s = scoreCol(c, (v) => RegExp(r'\d').hasMatch(v) && parseAmount(v) != null);
    if (s > amountScore) {
      amountScore = s;
      amountCol = c;
    }
  }
  if (amountCol >= 0 && amountScore > 0) roles[amountCol] = colAmount;

  final descCol = roles.indexOf(colIgnore);
  if (descCol >= 0) roles[descCol] = colDescription;

  return roles;
}

bool looksLikeHeaderRow(List<List<String>> rows, List<String> roles) {
  if (rows.length < 2) return false;
  final checkCols = [
    for (var i = 0; i < roles.length; i++)
      if (roles[i] == colDate || roles[i] == colAmount) (role: roles[i], i: i),
  ];
  if (checkCols.isEmpty) return false;

  bool rowParses(List<String> r) =>
      checkCols.any((c) => (c.role == colDate ? parseDate(r[c.i]) : parseAmount(r[c.i])) != null);

  return !rowParses(rows[0]) && rows.skip(1).any(rowParses);
}
