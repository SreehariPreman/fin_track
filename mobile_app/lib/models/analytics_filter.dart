/// A named date range preset from the Filters sheet. `custom` carries its
/// own explicit from/to rather than computing one.
enum DateRangePreset { today, thisWeek, thisMonth, last3Months, custom }

extension DateRangePresetLabel on DateRangePreset {
  String get label => switch (this) {
        DateRangePreset.today => 'Today',
        DateRangePreset.thisWeek => 'This Week',
        DateRangePreset.thisMonth => 'This Month',
        DateRangePreset.last3Months => 'Last 3 Months',
        DateRangePreset.custom => 'Custom Range',
      };
}

class DateRange {
  final DateTime start;

  /// Exclusive end.
  final DateTime end;

  const DateRange({required this.start, required this.end});

  static DateRange forMonth(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    return DateRange(start: start, end: end);
  }

  static DateRange forPreset(DateRangePreset preset, {DateRange? custom}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (preset) {
      case DateRangePreset.today:
        return DateRange(start: today, end: today.add(const Duration(days: 1)));
      case DateRangePreset.thisWeek:
        final weekday = today.weekday; // 1 = Monday
        final start = today.subtract(Duration(days: weekday - 1));
        return DateRange(start: start, end: start.add(const Duration(days: 7)));
      case DateRangePreset.thisMonth:
        return forMonth(today);
      case DateRangePreset.last3Months:
        final start = DateTime(today.year, today.month - 2, 1);
        return DateRange(start: start, end: DateTime(today.year, today.month + 1, 1));
      case DateRangePreset.custom:
        return custom ?? forMonth(today);
    }
  }

  Duration get span => end.difference(start);
}

/// Filter state for the Analytics tab. Date range comes either from the
/// month selector (the default) or a Filters-sheet override; the other
/// dimensions (bank/category/transaction type) are always additive.
class AnalyticsFilter {
  /// Null means "driven by the month selector, not overridden".
  final DateRangePreset? dateRangePreset;
  final DateRange? customRange;

  final Set<String> bankCodes;
  final Set<int> categoryIds;
  final Set<String> transactionTypes;

  const AnalyticsFilter({
    this.dateRangePreset,
    this.customRange,
    this.bankCodes = const {},
    this.categoryIds = const {},
    this.transactionTypes = const {},
  });

  bool get hasDateOverride => dateRangePreset != null;

  bool get isEmpty =>
      dateRangePreset == null &&
      bankCodes.isEmpty &&
      categoryIds.isEmpty &&
      transactionTypes.isEmpty;

  int get activeCount =>
      (dateRangePreset != null ? 1 : 0) + bankCodes.length + categoryIds.length + transactionTypes.length;

  DateRange resolveDateRange(DateTime selectedMonth) {
    if (dateRangePreset != null) {
      return DateRange.forPreset(dateRangePreset!, custom: customRange);
    }
    return DateRange.forMonth(selectedMonth);
  }

  AnalyticsFilter copyWith({
    DateRangePreset? dateRangePreset,
    bool clearDateOverride = false,
    DateRange? customRange,
    Set<String>? bankCodes,
    Set<int>? categoryIds,
    Set<String>? transactionTypes,
  }) {
    return AnalyticsFilter(
      dateRangePreset: clearDateOverride ? null : (dateRangePreset ?? this.dateRangePreset),
      customRange: customRange ?? this.customRange,
      bankCodes: bankCodes ?? this.bankCodes,
      categoryIds: categoryIds ?? this.categoryIds,
      transactionTypes: transactionTypes ?? this.transactionTypes,
    );
  }

  static const empty = AnalyticsFilter();
}
