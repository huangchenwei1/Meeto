import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/constants/scene_pricing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';

/// Section label inside the publish forms, shared by the demand composer
/// (post a request) and the supply composer (pitch an activity) so the
/// two sides of the board read identically.
class FormFieldLabel extends StatelessWidget {
  const FormFieldLabel(this.label, {super.key, this.hint});

  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 9),
      child: Row(
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (hint != null) ...<Widget>[
            const SizedBox(width: 6),
            Text(
              hint!,
              style: const TextStyle(fontSize: 11, color: AppColors.textHint),
            ),
          ],
        ],
      ),
    );
  }
}

/// Scene selector with the platform fee inline on each chip — the single
/// place either composer surfaces pricing (fees are platform-set, so the
/// chip is informational, not an input).
class ScenePriceChips extends StatelessWidget {
  const ScenePriceChips({
    super.key,
    required this.scenes,
    required this.selected,
    required this.onSelect,
    this.keyPrefix = 'scene',
  });

  final List<String> scenes;
  final String? selected;
  final ValueChanged<String> onSelect;

  /// ValueKey prefix so each composer's chips stay addressable in tests.
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final String scene in scenes)
          InkWell(
            key: ValueKey<String>('$keyPrefix$scene'),
            onTap: () => onSelect(scene),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: selected == scene
                    ? AppColors.darkCard
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${AppStrings.sceneLabel(scene)} \u00b7 '
                '${MoneyFormat.format(ScenePricing.feeForScene(scene))}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected == scene
                      ? AppColors.onDarkPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Single-select chip row for optional fields (fuzzy time window, rough
/// area): tapping the selected chip again clears it. [labelOf] maps the
/// stored identifier to its display label.
class OptionChips extends StatelessWidget {
  const OptionChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.keyPrefix,
    this.labelOf,
  });

  final List<String> options;
  final String selected;

  /// Receives the new value, or an empty string when cleared.
  final ValueChanged<String> onChanged;
  final String keyPrefix;
  final String Function(String value)? labelOf;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final String option in options)
          InkWell(
            key: ValueKey<String>('$keyPrefix$option'),
            onTap: () => onChanged(selected == option ? '' : option),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: selected == option
                    ? AppColors.darkCard
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                labelOf?.call(option) ?? option,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected == option
                      ? AppColors.onDarkPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
