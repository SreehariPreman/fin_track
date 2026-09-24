class CategorySpend {
  final int? categoryId;
  final String categoryName;
  final double total;
  final int count;

  const CategorySpend({
    required this.categoryId,
    required this.categoryName,
    required this.total,
    required this.count,
  });
}

class BankSpend {
  final String bankCode;
  final String bankName;
  final double total;
  final int count;

  const BankSpend({
    required this.bankCode,
    required this.bankName,
    required this.total,
    required this.count,
  });
}

class DailySpend {
  final DateTime date;
  final double total;

  const DailySpend({required this.date, required this.total});
}

class MonthlySpend {
  final DateTime month;
  final double total;

  const MonthlySpend({required this.month, required this.total});
}
