const periodBefore = 'BEFORE';
const periodDuring = 'DURING';
const kindExpense = 'EXPENSE';
const kindRefund = 'REFUND';

class Transaction {
  final String id;
  final String tripId;
  final String period;
  final String? date;
  final String description;
  final double amount;
  final String? categoryId;
  final String kind;
  final bool isIof;
  final int splitCount;
  final String createdAt;

  Transaction({
    required this.id,
    required this.tripId,
    required this.period,
    this.date,
    required this.description,
    required this.amount,
    this.categoryId,
    required this.kind,
    required this.isIof,
    required this.splitCount,
    required this.createdAt,
  });
}
