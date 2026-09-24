class UpiTransaction {
  /// Local database row id. Null until it has been saved.
  final int? id;
  final String emailId;
  final String subject;
  final double? amount;
  final DateTime? date;
  final String snippet;
  final String body;
  final int? categoryId;
  final String? categoryName;
  final bool syncedToSheet;

  /// Short bank code, e.g. "HDFC", "UBI" — see bank_profiles.dart.
  final String? bankCode;
  final String? bankName;
  final String? merchantName;
  final String? upiId;
  final String? referenceNo;
  final String? transactionType;
  final String? status;
  final String? notes;

  UpiTransaction({
    this.id,
    required this.emailId,
    required this.subject,
    required this.amount,
    required this.date,
    required this.snippet,
    required this.body,
    this.categoryId,
    this.categoryName,
    this.syncedToSheet = false,
    this.bankCode,
    this.bankName,
    this.merchantName,
    this.upiId,
    this.referenceNo,
    this.transactionType,
    this.status,
    this.notes,
  });

  /// Display name for the transaction — the parsed merchant/payee name
  /// when we have one, otherwise the snippet (older/legacy rows).
  String get displayName => (merchantName != null && merchantName!.isNotEmpty)
      ? merchantName!
      : (snippet.isNotEmpty ? snippet : subject);

  UpiTransaction copyWith({
    int? id,
    int? categoryId,
    String? categoryName,
    bool? syncedToSheet,
    String? notes,
  }) {
    return UpiTransaction(
      id: id ?? this.id,
      emailId: emailId,
      subject: subject,
      amount: amount,
      date: date,
      snippet: snippet,
      body: body,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      syncedToSheet: syncedToSheet ?? this.syncedToSheet,
      bankCode: bankCode,
      bankName: bankName,
      merchantName: merchantName,
      upiId: upiId,
      referenceNo: referenceNo,
      transactionType: transactionType,
      status: status,
      notes: notes ?? this.notes,
    );
  }
}
