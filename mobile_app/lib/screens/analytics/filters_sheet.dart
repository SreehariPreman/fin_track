import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/analytics_filter.dart';
import '../../models/category.dart';
import '../../services/bank_profiles.dart';
import '../../services/database_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Analytics' Filters sheet: Date Range preset, Bank, Category, and
/// Transaction Type. Returns the new AnalyticsFilter on Apply, or null if
/// dismissed without applying.
class FiltersSheet extends StatefulWidget {
  final AnalyticsFilter initial;

  const FiltersSheet({super.key, required this.initial});

  static Future<AnalyticsFilter?> show(BuildContext context, AnalyticsFilter current) {
    return showModalBottomSheet<AnalyticsFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => FiltersSheet(initial: current),
    );
  }

  @override
  State<FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<FiltersSheet> {
  final _db = DatabaseService.instance;

  DateRangePreset? _preset;
  DateRange? _customRange;
  late Set<String> _bankCodes;
  late Set<int> _categoryIds;
  late Set<String> _transactionTypes;

  List<String> _availableBanks = [];
  List<Category> _availableCategories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _preset = widget.initial.dateRangePreset;
    _customRange = widget.initial.customRange;
    _bankCodes = {...widget.initial.bankCodes};
    _categoryIds = {...widget.initial.categoryIds};
    _transactionTypes = {...widget.initial.transactionTypes};
    _load();
  }

  Future<void> _load() async {
    try {
      final banks = await _db.getDistinctBankCodes();
      final categories = await _db.getCategories();
      if (!mounted) return;
      setState(() {
        _availableBanks = banks;
        _availableCategories = categories;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _reset() {
    setState(() {
      _preset = null;
      _customRange = null;
      _bankCodes = {};
      _categoryIds = {};
      _transactionTypes = {};
    });
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: _customRange != null
          ? DateTimeRange(start: _customRange!.start, end: _customRange!.end.subtract(const Duration(days: 1)))
          : null,
    );
    if (picked == null) return;
    setState(() {
      _preset = DateRangePreset.custom;
      _customRange = DateRange(start: picked.start, end: picked.end.add(const Duration(days: 1)));
    });
  }

  void _apply() {
    Navigator.of(context).pop(AnalyticsFilter(
      dateRangePreset: _preset,
      customRange: _customRange,
      bankCodes: _bankCodes,
      categoryIds: _categoryIds,
      transactionTypes: _transactionTypes,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: _loading
            ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text('Filters', style: AppTextStyles.sectionTitle),
                      const Spacer(),
                      TextButton(onPressed: _reset, child: const Text('Reset')),
                    ],
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionLabel('Date Range'),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final preset in DateRangePreset.values)
                                ChoiceChip(
                                  label: Text(preset.label),
                                  selected: _preset == preset,
                                  showCheckmark: false,
                                  onSelected: (_) {
                                    if (preset == DateRangePreset.custom) {
                                      _pickCustomRange();
                                    } else {
                                      setState(() => _preset = preset);
                                    }
                                  },
                                ),
                            ],
                          ),
                          if (_preset == DateRangePreset.custom && _customRange != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '${DateFormat('dd MMM yyyy').format(_customRange!.start)} – '
                                '${DateFormat('dd MMM yyyy').format(_customRange!.end.subtract(const Duration(days: 1)))}',
                                style: AppTextStyles.bodySecondary,
                              ),
                            ),
                          const SizedBox(height: 20),
                          _SectionLabel('Bank'),
                          if (_availableBanks.isEmpty)
                            Text('No banks in your data yet.', style: AppTextStyles.supporting)
                          else
                            for (final code in _availableBanks)
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                controlAffinity: ListTileControlAffinity.leading,
                                title: Text(bankProfileForCode(code)?.name ?? code),
                                value: _bankCodes.contains(code),
                                onChanged: (checked) => setState(() {
                                  if (checked == true) {
                                    _bankCodes.add(code);
                                  } else {
                                    _bankCodes.remove(code);
                                  }
                                }),
                              ),
                          const SizedBox(height: 12),
                          _SectionLabel('Category'),
                          if (_availableCategories.isEmpty)
                            Text('No categories yet.', style: AppTextStyles.supporting)
                          else
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 220),
                              child: ListView(
                                shrinkWrap: true,
                                children: [
                                  for (final category in _availableCategories)
                                    CheckboxListTile(
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                      controlAffinity: ListTileControlAffinity.leading,
                                      title: Text(category.name),
                                      value: _categoryIds.contains(category.id),
                                      onChanged: (checked) => setState(() {
                                        if (checked == true) {
                                          _categoryIds.add(category.id);
                                        } else {
                                          _categoryIds.remove(category.id);
                                        }
                                      }),
                                    ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 12),
                          _SectionLabel('Transaction Type'),
                          for (final type in const ['UPI', 'Other'])
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(type),
                              value: _transactionTypes.contains(type),
                              onChanged: (checked) => setState(() {
                                if (checked == true) {
                                  _transactionTypes.add(type);
                                } else {
                                  _transactionTypes.remove(type);
                                }
                              }),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _apply,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    child: const Text('Apply Filters'),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: AppTextStyles.sectionTitle.copyWith(fontSize: 14)),
    );
  }
}
