import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/category.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/category_colors.dart';
import '../widgets/app_card.dart';
import '../widgets/category_avatar.dart';

/// Fast, dedicated labeling screen — a 3-column category grid rather than a
/// dropdown, so picking (or creating) a category is a single tap.
class LabelTransactionScreen extends StatefulWidget {
  final UpiTransaction transaction;

  const LabelTransactionScreen({super.key, required this.transaction});

  @override
  State<LabelTransactionScreen> createState() => _LabelTransactionScreenState();
}

class _LabelTransactionScreenState extends State<LabelTransactionScreen> {
  final _db = DatabaseService.instance;
  final _notesController = TextEditingController();

  List<Category> _categories = [];
  int? _selectedCategoryId;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.transaction.categoryId;
    _notesController.text = widget.transaction.notes ?? '';
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
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Food, Petrol'),
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
    );
    if (name == null || name.isEmpty) return;
    try {
      final category = await _db.createCategory(name);
      setState(() {
        _categories = [..._categories, category];
        _selectedCategoryId = category.id;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Category "$name" already exists.')),
      );
    }
  }

  Future<void> _save() async {
    final id = widget.transaction.id;
    if (id == null || _selectedCategoryId == null) return;
    setState(() => _saving = true);
    await _db.assignCategory(id, _selectedCategoryId);
    await _db.updateNotes(id, _notesController.text.trim());
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.transaction;
    final amountStr = t.amount != null ? '₹${t.amount!.toStringAsFixed(2)}' : '—';
    final timeStr = t.date != null ? DateFormat('h:mm a').format(t.date!) : '';

    return Scaffold(
      appBar: AppBar(title: const Text('Label transaction')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    children: [
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(amountStr, style: AppTextStyles.amountLarge),
                            const SizedBox(height: 4),
                            Text(t.displayName, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                              [if (t.bankName != null) t.bankName!, timeStr].where((s) => s.isNotEmpty).join(' · '),
                              style: AppTextStyles.supporting,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('Select a category', style: AppTextStyles.sectionTitle),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.92,
                        children: [
                          for (final category in _categories)
                            _CategoryTile(
                              category: category,
                              selected: category.id == _selectedCategoryId,
                              onTap: () => setState(() => _selectedCategoryId = category.id),
                            ),
                          _AddCategoryTile(onTap: _addCategory),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text('Notes', style: AppTextStyles.sectionTitle),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: const InputDecoration(hintText: 'Add a note (optional)'),
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: FilledButton(
                    onPressed: (_selectedCategoryId == null || _saving) ? null : _save,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final Category category;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryTile({required this.category, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = CategoryColors.forId(category.id);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.1) : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.primary : Colors.transparent, width: 1.5),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CategoryAvatar(categoryId: category.id, name: category.name, size: 40),
                const SizedBox(height: 8),
                Text(
                  category.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySecondary.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
            if (selected)
              const Positioned(
                top: 0,
                right: 0,
                child: Icon(Icons.check_circle, color: AppColors.primary, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}

class _AddCategoryTile extends StatelessWidget {
  final VoidCallback onTap;

  const _AddCategoryTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, style: BorderStyle.solid),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(color: AppColors.card, shape: BoxShape.circle),
              child: const Icon(Icons.add, color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            Text(
              'New',
              style: AppTextStyles.bodySecondary.copyWith(fontWeight: FontWeight.w600, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}
