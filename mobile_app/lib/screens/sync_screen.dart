import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/transaction.dart';
import '../services/credentials_service.dart';
import '../services/database_service.dart';
import '../services/imap_service.dart';
import 'transaction_detail_screen.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final _credentialsService = CredentialsService();
  final _imapService = ImapService();
  final _db = DatabaseService.instance;

  List<UpiTransaction> _transactions = [];
  bool _fetching = false;
  bool _loadingList = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFromDb();
  }

  Future<void> _loadFromDb() async {
    try {
      final rows = await _db.getAllTransactions();
      if (!mounted) return;
      setState(() {
        _transactions = rows;
        _loadingList = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingList = false;
        _error = 'Could not load local database: $e';
      });
    }
  }

  Future<void> _fetch() async {
    setState(() {
      _fetching = true;
      _error = null;
    });

    final email = await _credentialsService.readEmail();
    final passcode = await _credentialsService.readAppPasscode();

    if (email == null || email.isEmpty || passcode == null || passcode.isEmpty) {
      setState(() {
        _fetching = false;
        _error = 'Set your email and app passcode in Profile first.';
      });
      return;
    }

    try {
      final fetched = await _imapService.fetchLastUpiTransactions(
        email: email,
        appPasscode: passcode,
        maxCount: 10,
      );
      await _db.insertNewTransactions(fetched);
      await _loadFromDb();
      setState(() => _fetching = false);
    } catch (e) {
      setState(() {
        _fetching = false;
        _error = 'Could not fetch mail: $e';
      });
    }
  }

  Future<void> _openDetail(UpiTransaction t) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TransactionDetailScreen(transaction: t)),
    );
    // The detail screen may have changed this transaction's label.
    _loadFromDb();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sync')),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: _loadingList
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  FilledButton.icon(
                    onPressed: _fetching ? null : _fetch,
                    icon: _fetching
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(_fetching ? 'Fetching...' : 'Fetch last 10 UPI transactions'),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(_error!, style: const TextStyle(color: Colors.red)),
                    ),
                  if (_transactions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 32),
                      child: Center(child: Text('No transactions yet. Tap Fetch to load your inbox.')),
                    ),
                  ..._transactions.map(
                    (t) => _TransactionCard(
                      transaction: t,
                      onTap: () => _openDetail(t),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final UpiTransaction transaction;
  final VoidCallback onTap;

  const _TransactionCard({required this.transaction, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateTimeStr = transaction.date != null
        ? DateFormat('dd MMM yyyy · hh:mm a').format(transaction.date!)
        : '—';
    final amountStr = transaction.amount != null
        ? '₹${transaction.amount!.toStringAsFixed(2)}'
        : '—';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(amountStr, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(dateTimeStr),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
