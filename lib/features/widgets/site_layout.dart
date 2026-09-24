import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../providers/catalog_providers.dart';

// Building blocks shared by the main list pages so they read like the
// website on a phone: a title row, a white filter card of compact selects,
// and two-per-row card grids.

/// Page title and subtitle on the left with an optional button on the right —
/// the site's `.section-head` at the top of a list page.
class PageHead extends StatelessWidget {
  const PageHead({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.padding = const EdgeInsets.fromLTRB(16, 20, 16, 16),
  });

  final Widget title;
  final String? subtitle;
  final Widget? action;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DefaultTextStyle.merge(
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                  child: title,
                ),
                if ((subtitle ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: 10), action!],
        ],
      ),
    );
  }
}

/// The site's small filled (`.btn .btn-sm`) or outlined (`.btn-outline`)
/// button.
class SiteButton extends StatelessWidget {
  const SiteButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.outlined = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool outlined;

  static const _padding = EdgeInsets.symmetric(horizontal: 14, vertical: 9);
  static const _text = TextStyle(fontSize: 13, fontWeight: FontWeight.w700);
  static final _shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.forest,
          side: const BorderSide(color: AppColors.forest),
          padding: _padding,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: _text,
          shape: _shape,
        ),
        child: Text(label),
      );
    }
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.forest,
        padding: _padding,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: _text,
        shape: _shape,
      ),
      child: Text(label),
    );
  }
}

/// White rounded card holding a page's filters (`.admin-card
/// .donor-filter-form`).
class FilterCard extends StatelessWidget {
  const FilterCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

/// One option of a [FilterSelect]; a null [value] is the "All …" choice.
class FilterOption {
  const FilterOption(this.value, this.label);

  final String? value;
  final String label;
}

/// A compact select box like the site's `.marketplace-filter-select`: shows
/// the current choice with a chevron and opens a list to pick from.
class FilterSelect extends StatelessWidget {
  const FilterSelect({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.title = 'Select',
    this.enabled = true,
  });

  final String? value;
  final List<FilterOption> options;
  final ValueChanged<String?> onChanged;
  final String title;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final current = options.where((o) => o.value == value).firstOrNull ?? options.firstOrNull;

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled && options.isNotEmpty ? () => _pick(context) : null,
        child: Container(
          height: 42,
          padding: const EdgeInsets.only(left: 12, right: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  current?.label ?? title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: enabled ? AppColors.text : AppColors.textSecondary,
                  ),
                ),
              ),
              const Icon(Icons.expand_more_rounded, size: 20, color: AppColors.text),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final picked = await showModalBottomSheet<FilterOption>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (context) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options[index];
                  final selected = option.value == value;
                  return ListTile(
                    title: Text(
                      option.label,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? AppColors.forestDark : AppColors.text,
                      ),
                    ),
                    trailing: selected
                        ? const Icon(Icons.check_rounded, color: AppColors.forest)
                        : null,
                    onTap: () => Navigator.of(context).pop(option),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (picked != null && picked.value != value) onChanged(picked.value);
  }
}

/// District select, listing the Bengali names the site shows.
class DistrictFilterSelect extends ConsumerWidget {
  const DistrictFilterSelect({super.key, required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final districts = ref.watch(districtsProvider).valueOrNull ?? const [];
    return FilterSelect(
      title: 'District',
      value: value,
      onChanged: onChanged,
      options: [
        const FilterOption(null, 'All Districts'),
        for (final d in districts) FilterOption(d.filterValue, d.bnName ?? d.name),
      ],
    );
  }
}

/// Thana select for [districtName]; only "All thanas" until a district is set.
class AreaFilterSelect extends ConsumerWidget {
  const AreaFilterSelect({
    super.key,
    required this.districtName,
    required this.value,
    required this.onChanged,
  });

  final String? districtName;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final areas = ref.watch(upazilasByDistrictNameProvider(districtName)).valueOrNull ?? const [];
    return FilterSelect(
      title: 'Thana',
      value: value,
      onChanged: onChanged,
      options: [
        const FilterOption(null, 'All thanas'),
        for (final a in areas) FilterOption(a.filterValue, a.bnName ?? a.name),
      ],
    );
  }
}

/// Square 🔍 button that shows or hides a page's search box
/// (`.marketplace-search-toggle`).
class SearchToggleButton extends StatelessWidget {
  const SearchToggleButton({super.key, required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.forestLight : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: active ? AppColors.forest : AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: const SizedBox(
          width: 42,
          height: 42,
          child: Center(child: Text('🔍', style: TextStyle(fontSize: 16))),
        ),
      ),
    );
  }
}

/// Lazily built grid of cards two to a row, for long result lists.
class SliverCardGrid extends StatelessWidget {
  const SliverCardGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.spacing = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final double spacing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final rows = (itemCount + 1) ~/ 2;
    return SliverPadding(
      padding: padding,
      sliver: SliverList.separated(
        itemCount: rows,
        separatorBuilder: (_, __) => SizedBox(height: spacing),
        itemBuilder: (context, row) {
          final first = row * 2;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: itemBuilder(context, first)),
              SizedBox(width: spacing),
              Expanded(
                child: first + 1 < itemCount
                    ? itemBuilder(context, first + 1)
                    : const SizedBox.shrink(),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Grey one-line "nothing here" note (`.empty-note`).
class EmptyNote extends StatelessWidget {
  const EmptyNote(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Text(
        message,
        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
      ),
    );
  }
}
