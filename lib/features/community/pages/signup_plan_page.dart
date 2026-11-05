import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/form_widgets.dart';
import '../../../shared/widgets/place_search_field.dart';

/// Full-screen plan composer: the pitch plus the plan card (place, time,
/// duration). Used in two mirrored places — a host signing up on a demand
/// post, and a host locking the plan while selecting an inviter on their
/// own pitch. Either way the plan ships as-is with the deal, so the form
/// is deliberately formal — a proper page, not a casual bottom sheet.
///
/// Pops `(proposal, place, scheduledAt, durationMinutes)`.
class SignUpPlanPage extends StatefulWidget {
  const SignUpPlanPage({
    super.key,
    this.title = AppStrings.proposalSheetTitle,
    this.subtitle = AppStrings.proposalSheetSub,
    this.pitchLabel = AppStrings.proposalPitchLabel,
    this.submitLabel = AppStrings.signUpCta,
    this.pitchRequired = true,
  });

  final String title;
  final String subtitle;
  final String pitchLabel;
  final String submitLabel;

  /// The sign-up pitch is the host's sales argument and is required; the
  /// selection plan's note is optional color.
  final bool pitchRequired;

  @override
  State<SignUpPlanPage> createState() => _SignUpPlanPageState();
}

class _SignUpPlanPageState extends State<SignUpPlanPage> {
  final TextEditingController _pitchController = TextEditingController();
  final TextEditingController _placeController = TextEditingController();
  DateTime? _scheduledAt;
  int _durationMinutes = planDurationOptions[1];

  @override
  void dispose() {
    _pitchController.dispose();
    _placeController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final DateTime now = DateTime.now();
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (date == null || !mounted) {
      return;
    }
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: _scheduledAt != null
          ? TimeOfDay.fromDateTime(_scheduledAt!)
          : const TimeOfDay(hour: 19, minute: 0),
    );
    if (time == null) {
      return;
    }
    setState(() {
      _scheduledAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _submit() {
    final String pitch = _pitchController.text.trim();
    if (widget.pitchRequired && pitch.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.proposalRequiredHint)),
      );
      return;
    }
    final String place = _placeController.text.trim();
    final DateTime? at = _scheduledAt;
    if (place.isEmpty || at == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.planRequiredHint)),
      );
      return;
    }
    Navigator.of(context).pop((pitch, place, at, _durationMinutes));
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  String _formatDateTime(DateTime at) {
    final MaterialLocalizations loc = MaterialLocalizations.of(context);
    final DateTime local = at.toLocal();
    return '${loc.formatShortDate(local)} \u00b7 '
        '${loc.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _sectionLabel(widget.pitchLabel),
                    TextField(
                      key: const ValueKey<String>('proposalField'),
                      controller: _pitchController,
                      maxLength: 200,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        hintText: AppStrings.proposalHint,
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _sectionLabel(AppStrings.proposalPlaceLabel),
                    PlaceSearchField(
                      fieldKey: const ValueKey<String>('proposalPlaceField'),
                      controller: _placeController,
                      maxLength: 120,
                      hintText: AppStrings.planPlaceHint,
                    ),
                    const SizedBox(height: 14),
                    _sectionLabel(AppStrings.proposalTimeLabel),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        key: const ValueKey<String>('proposalTimeButton'),
                        onPressed: _pickTime,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.schedule, size: 18),
                        label: Text(
                          _scheduledAt == null
                              ? AppStrings.publishPickTime
                              : _formatDateTime(_scheduledAt!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _sectionLabel(AppStrings.planDurationLabel),
                    DurationChips(
                      selected: _durationMinutes,
                      onSelect: (int minutes) =>
                          setState(() => _durationMinutes = minutes),
                      keyPrefix: 'proposalDuration',
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey<String>('proposalSubmitButton'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.textPrimary,
                    foregroundColor: AppColors.onDarkPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: _submit,
                  child: Text(widget.submitLabel),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
