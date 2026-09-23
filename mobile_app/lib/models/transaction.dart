class Transaction {
  final String emailId;
  final String subject;
  final double? amount;
  final DateTime? date;
  final String snippet;
  final String body;

  Transaction({
    required this.emailId,
    required this.subject,
    required this.amount,
    required this.date,
    required this.snippet,
    required this.body,
  });
}
