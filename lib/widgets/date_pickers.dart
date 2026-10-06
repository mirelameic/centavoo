import 'package:flutter/material.dart';
import 'package:centavoo/logic/format.dart';

final _firstDate = DateTime(2000);
final _lastDate = DateTime(2100);

DateTime _clamp(DateTime d) => d.isBefore(_firstDate) ? _firstDate : (d.isAfter(_lastDate) ? _lastDate : d);

Future<DateTimeRange?> pickDateRange(BuildContext context, {DateTimeRange? initial}) {
  return showDateRangePicker(
    context: context,
    firstDate: _firstDate,
    lastDate: _lastDate,
    initialDateRange: initial == null ? null : DateTimeRange(start: _clamp(initial.start), end: _clamp(initial.end)),
  );
}

Future<DateTime?> pickDate(BuildContext context, {DateTime? initial}) {
  return showDatePicker(
    context: context,
    initialDate: _clamp(initial ?? DateTime.now()),
    firstDate: _firstDate,
    lastDate: _lastDate,
  );
}

String fmtPickedRange(DateTimeRange range) => fmtDateRange(isoDate(range.start), isoDate(range.end));
