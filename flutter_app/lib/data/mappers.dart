import 'dart:convert';
import 'package:centavoo/data/database.dart';
import 'package:centavoo/models/trip.dart' as model;
import 'package:centavoo/models/category.dart' as model;
import 'package:centavoo/models/category_rule.dart' as model;
import 'package:centavoo/models/transaction.dart' as model;

model.Trip tripFromRow(TripRow row) {
  return model.Trip(
    id: row.id,
    name: row.name,
    destination: row.destination,
    startDate: row.startDate,
    endDate: row.endDate,
    currency: row.currency,
    notes: row.notes,
    cities: Map<String, String>.from(jsonDecode(row.citiesJson) as Map),
    cityList: row.cityListJson == null ? null : List<String>.from(jsonDecode(row.cityListJson!) as List),
    createdAt: row.createdAt,
  );
}

model.Category categoryFromRow(CategoryRow row) {
  return model.Category(
    id: row.id,
    tripId: row.tripId,
    name: row.name,
    color: row.color,
    icon: row.icon,
    sortOrder: row.sortOrder,
  );
}

model.Transaction transactionFromRow(TransactionRow row) {
  return model.Transaction(
    id: row.id,
    tripId: row.tripId,
    period: row.period,
    date: row.date,
    description: row.description,
    amount: row.amount,
    categoryId: row.categoryId,
    kind: row.kind,
    isIof: row.isIof,
    splitCount: row.splitCount,
    city: row.city,
    rawText: row.rawText,
    createdAt: row.createdAt,
  );
}

model.CategoryRule categoryRuleFromRow(CategoryRuleRow row) {
  return model.CategoryRule(
    id: row.id,
    keyword: row.keyword,
    categoryId: row.categoryId,
    priority: row.priority,
  );
}
