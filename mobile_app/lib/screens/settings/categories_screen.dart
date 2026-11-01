import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../models/category.dart';
import '../../services/database_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/category_avatar.dart';

/// Manage categories: view, add, rename, delete. Deleting a category
/// un-labels (doesn't delete) any transactions that had it; renaming one
/// leaves every transaction attached to it, since the link is by id.
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

  /// Shared name prompt for both adding and renaming.
  ///
  /// [onSubmit] only writes; the list is reloaded here, once the dialog
  /// has closed. Refreshing from inside the dialog rebuilds this screen
  /// while the dialog route is still mounted on top of it, which trips an
  /// InheritedElement assertion as the tree is torn down.
  Future<void> _promptForName({
    required String title,
    required String actionLabel,
    String? initialValue,
    required Future<void> Function(String name) onSubmit,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _NamePromptDialog(
        title: title,
        actionLabel: actionLabel,
        initialValue: initialValue,
        onSubmit: onSubmit,
      ),
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _addCategory() => _promptForName(
        title: 'New category',
        actionLabel: 'Add',
        onSubmit: (name) => _db.createCategory(name),
      );

  Future<void> _renameCategory(Category category) => _promptForName(
        title: 'Rename category',
        actionLabel: 'Save',
        initialValue: category.name,
        onSubmit: (name) => _db.renameCategory(category.id, name),
      );

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
                                  tooltip: 'Rename',
                                  icon: Icon(PhosphorIconsRegular.pencilSimple,
                                      color: AppColors.textMuted),
                                  onPressed: () => _renameCategory(_categories[i]),
                                ),
                                IconButton(
                                  tooltip: 'Delete',
                                  icon: Icon(PhosphorIconsRegular.trashSimple, color: AppColors.textMuted),
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
                  icon: const Icon(PhosphorIconsBold.plus),
                  label: const Text('New category'),
                ),
              ],
            ),
    );
  }
}

/// The add/rename dialog.
///
/// A StatefulWidget so it owns its TextEditingController and disposes it
/// in its own dispose(). Creating the controller outside and disposing it
/// once showDialog() returns looks equivalent but isn't: the route is
/// still animating out with the TextField attached, and disposing a
/// controller that still has listeners trips an assertion.
class _NamePromptDialog extends StatefulWidget {
  final String title;
  final String actionLabel;
  final String? initialValue;
  final Future<void> Function(String name) onSubmit;

  const _NamePromptDialog({
    required this.title,
    required this.actionLabel,
    required this.initialValue,
    required this.onSubmit,
  });

  @override
  State<_NamePromptDialog> createState() => _NamePromptDialogState();
}

class _NamePromptDialogState extends State<_NamePromptDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give it a name');
      return;
    }
    // Saving an unchanged name shouldn't be reported as a clash with
    // itself.
    if (name == widget.initialValue) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit(name);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      // Reported in the dialog rather than a snackbar: closing first
      // would throw away what was typed, which is exactly what the user
      // needs back in order to change it.
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '"\$name" already exists';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: 'e.g. Food, Petrol',
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(widget.actionLabel),
        ),
      ],
    );
  }
}
