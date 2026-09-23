import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/category.dart';
import '../models/transaction.dart';
import '../services/credentials_service.dart';
import '../services/database_service.dart';
import '../services/imap_service.dart';
import '../widgets/category_picker_sheet.dart';
import 'profile_screen.dart';
import 'transaction_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

  Future<void> _pickCategory(UpiTransaction t) async {
    final Category? category = await CategoryPickerSheet.show(context);
    if (category == null || t.id == null) return;
    await _db.assignCategory(t.id!, category.id);
    await _loadFromDb();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fin Track'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
        ],
      ),
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
                      onLabelTap: () => _pickCategory(t),
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
  final VoidCallback onLabelTap;

  const _TransactionCard({required this.transaction, required this.onLabelTap});

  @override
  Widget build(BuildContext context) {
    final dateStr = transaction.date != null
        ? DateFormat('dd MMM yyyy').format(transaction.date!)
        : '—';
    final amountStr = transaction.amount != null
        ? '₹${transaction.amount!.toStringAsFixed(2)}'
        : '—';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(amountStr, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$dateStr · ${transaction.snippet}'),
        trailing: ActionChip(
          avatar: const Icon(Icons.label_outline, size: 16),
          label: Text(transaction.categoryName ?? 'Label'),
          onPressed: onLabelTap,
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TransactionDetailScreen(transaction: transaction)),
        ),
      ),
    );
  }
}
