/// One row of the Google Sheet sync history shown on the Google Sheet
/// screen. Written after every sync/export attempt, successful or not, so
/// the history doubles as a record of what went wrong.
class SheetSyncEntry {
  final int id;
  final DateTime syncedAt;

  /// 'sync' — appended to the connected sheet.
  /// 'export' — wrote a full copy into a brand-new sheet.
  final String kind;

  /// 'success' or 'failed'.
  final String status;

  /// Rows actually written.
  final int rowCount;

  /// Rows already present in the sheet (matched on Email ID) and skipped.
  final int skippedCount;

  final String? spreadsheetId;
  final String? spreadsheetName;

  /// Failure reason, for a failed entry.
  final String? message;

  SheetSyncEntry({
    required this.id,
    required this.syncedAt,
    required this.kind,
    required this.status,
    required this.rowCount,
    required this.skippedCount,
    this.spreadsheetId,
    this.spreadsheetName,
    this.message,
  });

  bool get isExport => kind == 'export';
  bool get isSuccess => status == 'success';
}
