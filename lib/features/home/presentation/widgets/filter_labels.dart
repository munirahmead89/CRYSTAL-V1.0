import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

/// One selectable WhatsApp-style label chip ("All", "Read", "Unread" ...).
class FilterOption<T> {
  const FilterOption(this.value, this.label, {this.count});

  final T value;
  final String label;

  /// Optional trailing count shown inside the pill when selected.
  final int? count;
}

/// WhatsApp-style filter pills: unselected labels are plain grey text;
/// the active one gets a solid green pill background with black bold text —
/// identical to WhatsApp's "All / Unread / Favourites" filter row.
class FilterLabels<T> extends StatelessWidget {
  const FilterLabels({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<FilterOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < options.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              _Label(
                label: options[i].label,
                count: options[i].count,
                selected: selected == options[i].value,
                onTap: () => onChanged(options[i].value),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        // Green filled pill when selected — matches WhatsApp behaviour.
        color: selected ? CrystalColors.green : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: selected
            ? null
            : Border.all(color: scheme.outlineVariant, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          // Natural padding lets each chip auto-size to fit its text.
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              // Black text on the green pill; grey for unselected.
              color: selected ? CrystalColors.black : scheme.onSurfaceVariant,
            ),
            // One line only - never wrap ("Nonview ed"), clip anything wider.
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.clip,
          ),
        ),
      ),
    );
  }
}
