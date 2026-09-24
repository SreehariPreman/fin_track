import 'package:flutter/material.dart';

import '../models/category.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Bottom sheet to pick (or create) a category for a transaction.
/// Returns the chosen Category, or null if dismissed without a choice.
class CategoryPickerSheet extends StatefulWidget {
  const CategoryPickerSheet({super.key});

  static Future<Category?> show(BuildContext context) {
    return showModalBottomSheet<Category>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Label this transaction', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 14),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_categories.isEmpty)
              Text('No categories yet — add one below.', style: AppTextStyles.bodySecondary)
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
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newCategoryController,
                    decoration: InputDecoration(
                      hintText: 'New category (e.g. Food, Petrol)',
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
