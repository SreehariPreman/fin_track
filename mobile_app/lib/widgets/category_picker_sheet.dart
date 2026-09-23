import 'package:flutter/material.dart';

import '../models/category.dart';
import '../services/database_service.dart';

/// Bottom sheet to pick (or create) a category for a transaction.
/// Returns the chosen Category, or null if dismissed without a choice.
class CategoryPickerSheet extends StatefulWidget {
  const CategoryPickerSheet({super.key});

  static Future<Category?> show(BuildContext context) {
    return showModalBottomSheet<Category>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const CategoryPickerSheet(),
    );
  }

  @override
  State<CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<CategoryPickerSheet> {
  final _db = DatabaseService.instance;
  final _newCategoryController = TextEditingController();
  List<Category> _categories = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final categories = await _db.getCategories();
    setState(() {
      _categories = categories;
      _loading = false;
    });
  }

  Future<void> _createCategory() async {
    final name = _newCategoryController.text.trim();
    if (name.isEmpty) return;
    try {
      final category = await _db.createCategory(name);
      if (!mounted) return;
      Navigator.of(context).pop(category);
    } catch (_) {
      setState(() => _error = 'Category "$name" already exists.');
    }
  }

  @override
  void dispose() {
    _newCategoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Label this transaction', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_categories.isEmpty)
              const Text('No categories yet — add one below.')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories
                    .map((c) => ActionChip(
                          label: Text(c.name),
                          onPressed: () => Navigator.of(context).pop(c),
                        ))
                    .toList(),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newCategoryController,
                    decoration: InputDecoration(
                      hintText: 'New category (e.g. Food, Petrol)',
                      border: const OutlineInputBorder(),
                      errorText: _error,
                    ),
                    onSubmitted: (_) => _createCategory(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _createCategory,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
