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

/// Required single-select scene pills for the free-form composer: the
/// activity type is always one of the platform's priced scenes (pricing
/// and default covers hang off the scene tag), so unlike [OptionChips]
/// a selection cannot be cleared, only switched.
class SceneChips extends StatelessWidget {
  const SceneChips({
    super.key,
    required this.scenes,
    required this.selected,
    required this.onSelect,
    this.keyPrefix = 'scene',
  });

  final List<String> scenes;
  final String selected;
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
                AppStrings.sceneLabel(scene),
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

/// Platform-suggested activity durations, in minutes.
const List<int> planDurationOptions = <int>[120, 180, 240, 360];

/// Duration picker for plan cards: how long the activity runs. Same pill
/// style as [BudgetTierChips]; used by the sign-up plan composer and the
/// host's plan sheet.
class DurationChips extends StatelessWidget {
  const DurationChips({
    super.key,
    required this.selected,
    required this.onSelect,
    this.keyPrefix = 'planDuration',
  });

  /// Currently picked duration, in minutes.
  final int selected;

  final ValueChanged<int> onSelect;

  /// ValueKey prefix so each surface's chips stay addressable in tests.
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final int minutes in planDurationOptions)
          InkWell(
            key: ValueKey<String>('$keyPrefix$minutes'),
            onTap: () => onSelect(minutes),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: selected == minutes
                    ? AppColors.darkCard
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                AppStrings.durationLabel(minutes),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: selected == minutes
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

/// Budget tier picker: the platform prices the whole activity in a few
/// tiers per scene and the poster picks one — free pricing never exists.
/// Used by the request composer and the invite sheet.
class BudgetTierChips extends StatelessWidget {
  const BudgetTierChips({
    super.key,
    required this.sceneTag,
    required this.selected,
    required this.onSelect,
    required this.note,
    this.keyPrefix = 'budgetTier',
  });

  /// Scene whose platform tiers are offered (from the launched template).
  final String sceneTag;

  /// Currently picked tier (whole pesos).
  final int selected;

  final ValueChanged<int> onSelect;

  /// Role-specific one-liner explaining what the budget covers.
  final String note;

  /// ValueKey prefix so each surface's chips stay addressable in tests.
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final int tier in ScenePricing.tiersForScene(sceneTag))
              InkWell(
                key: ValueKey<String>('$keyPrefix$tier'),
                onTap: () => onSelect(tier),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: selected == tier
                        ? AppColors.darkCard
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    MoneyFormat.format(tier),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: selected == tier
                          ? AppColors.onDarkPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          note,
          style: const TextStyle(
            fontSize: 12,
            height: 1.4,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
