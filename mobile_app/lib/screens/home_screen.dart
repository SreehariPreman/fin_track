import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/transaction.dart';
import '../services/credentials_service.dart';
import '../services/imap_service.dart';
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

  List<Transaction> _transactions = [];
  bool _loading = false;
  String? _error;

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final email = await _credentialsService.readEmail();
    final passcode = await _credentialsService.readAppPasscode();

    if (email == null || email.isEmpty || passcode == null || passcode.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Set your email and app passcode in Profile first.';
      });
      return;
    }

    try {
      final results = await _imapService.fetchLastUpiTransactions(
        email: email,
        appPasscode: passcode,
        maxCount: 10,
      );
      setState(() {
        _transactions = results;
        _loading = false;
        if (results.isEmpty) {
          _error = 'No UPI transactions found in the last emails.';
        }
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Could not fetch mail: $e';
      });
    }
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
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FilledButton.icon(
              onPressed: _loading ? null : _fetch,
              icon: _loading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.refresh),
              label: Text(_loading ? 'Fetching...' : 'Fetch last 10 UPI transactions'),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            ..._transactions.map((t) => _TransactionCard(transaction: t)),
          ],
        ),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final Transaction transaction;

  const _TransactionCard({required this.transaction});

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
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TransactionDetailScreen(transaction: transaction)),
        ),
      ),
    );
  }
}
