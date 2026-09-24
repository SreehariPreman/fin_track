import 'package:flutter/material.dart';

import '../models/category.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_card.dart';
import '../widgets/category_avatar.dart';

/// Manage categories: view, add, delete. Deleting a category un-labels
/// (doesn't delete) any transactions that had it.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final _db = DatabaseService.instance;
  List<Category> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final categories = await _db.getCategories();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _loading = false;
    });
  }

  Future<void> _addCategory() async {
    final controller = TextEditingController();
    String? error;

    final name = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New category'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(hintText: 'e.g. Food, Petrol', errorText: error),
            onSubmitted: (_) => Navigator.of(context).pop(controller.text.trim()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (name == null || name.isEmpty) return;
    try {
      await _db.createCategory(name);
      _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Category "$name" already exists.')),
      );
    }
  }

  Future<void> _deleteCategory(Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text(
          '"${category.name}" will be removed. Transactions labeled with it '
          'become unlabelled — they are not deleted.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _db.deleteCategory(category.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                if (_categories.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 24, bottom: 8),
                    child: Text(
                      'No categories yet. Add one below, or create one inline '
                      'the first time you label a transaction.',
                      style: AppTextStyles.bodySecondary,
                    ),
                  )
                else
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < _categories.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                CategoryAvatar(
                                  categoryId: _categories[i].id,
                                  name: _categories[i].name,
                                  size: 36,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(_categories[i].name, style: AppTextStyles.body),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_outline, color: AppColors.textMuted),
                                  onPressed: () => _deleteCategory(_categories[i]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _addCategory,
                  icon: const Icon(Icons.add),
                  label: const Text('New category'),
                ),
              ],
            ),
    );
  }
}
