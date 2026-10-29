import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/scene_pricing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/geo.dart';
import '../../../core/utils/money.dart';
import '../data/community_repository.dart';
import '../data/place_search.dart';
import '../../../core/network/api_client.dart';
import '../../auth/pages/verification_page.dart';

/// Full-screen form to publish a new activity post.
///
/// Pops with `true` when a post was published.
class PublishPage extends StatefulWidget {
  const PublishPage({super.key, required this.repository});

  final CommunityRepository repository;

  @override
  State<PublishPage> createState() => _PublishPageState();
}

class _PublishPageState extends State<PublishPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  DateTime? _scheduledAt;
  PlaceResult? _place;

  List<String> _scenes = <String>[];
  String? _selectedScene;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadScenes();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadScenes() async {
    final List<String> scenes = await widget.repository.fetchScenes();
    if (!mounted) {
      return;
    }
    setState(() {
      _scenes = scenes;
      _selectedScene = scenes.first;
    });
  }

  static const List<String> _weekdays = <String>[
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];
  static const List<String> _months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatSchedule(DateTime dt) {
    final int hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final String minute = dt.minute.toString().padLeft(2, '0');
    final String ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '${_weekdays[dt.weekday - 1]}, ${_months[dt.month - 1]} ${dt.day}'
        ' \u00b7 $hour12:$minute $ampm';
  }

  Future<void> _pickDateTime() async {
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
    if (time == null || !mounted) {
      return;
    }
    setState(() {
      _scheduledAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _pickPlace() async {
    final PlaceResult? picked = await showModalBottomSheet<PlaceResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) => const _PlaceSearchSheet(),
    );
    if (picked != null && mounted) {
      setState(() => _place = picked);
    }
  }

  Future<void> _submit() async {
    final String scene = _selectedScene ?? _scenes.first;
    setState(() => _submitting = true);
    try {
      await widget.repository.createPost(
        CreatePostInput(
          sceneTag: scene,
          title: _titleController.text.trim().isEmpty
              ? scene
              : _titleController.text.trim(),
          description: _descController.text.trim().isEmpty
              ? AppStrings.publishDefaultDesc
              : _descController.text.trim(),
          timeText: _scheduledAt == null
              ? AppStrings.publishDefaultTime
              : _formatSchedule(_scheduledAt!),
          place: _place?.name ?? AppStrings.publishDefaultPlace,
          scheduledAt: _scheduledAt,
          placeLat: _place?.lat,
          placeLng: _place?.lng,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _submitting = false);
      if (e.verificationRequired) {
        final bool verified = await promptVerification(context);
        if (verified && mounted) {
          return _submit();
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(AppStrings.publishSuccess)));
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.publishTitle),
        leading: IconButton(
          icon: const Icon(Iconsax.close_circle, size: 22),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: <Widget>[
          const _FieldLabel(AppStrings.publishScene),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _scenes.map((String scene) {
              final bool selected = scene == _selectedScene;
              return InkWell(
                onTap: () => setState(() => _selectedScene = scene),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.textPrimary
                        : AppColors.background,
                    border: Border.all(
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.border,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    scene,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: selected
                          ? AppColors.background
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          _MatchFeeCard(
            fee: ScenePricing.feeForScene(_selectedScene ?? 'Coffee'),
          ),
          const _FieldLabel(AppStrings.publishFieldTitle),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              hintText: AppStrings.publishPhTitle,
            ),
          ),
          const _FieldLabel(
            AppStrings.publishFieldDesc,
            hint: AppStrings.publishFieldDescHint,
          ),
          TextField(
            controller: _descController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: AppStrings.publishPhDesc,
            ),
          ),
          const _FieldLabel(
            AppStrings.publishFieldTime,
            hint: AppStrings.publishOptionalHint,
          ),
          _PickerField(
            key: const ValueKey<String>('timePicker'),
            icon: Iconsax.clock,
            value: _scheduledAt == null ? '' : _formatSchedule(_scheduledAt!),
            placeholder: AppStrings.publishPickTime,
            onTap: _pickDateTime,
          ),
          const _FieldLabel(
            AppStrings.publishFieldPlace,
            hint: AppStrings.publishOptionalHint,
          ),
          _PickerField(
            key: const ValueKey<String>('placePicker'),
            icon: Iconsax.location,
            value: _place?.name ?? '',
            placeholder: AppStrings.publishPickPlace,
            onTap: _pickPlace,
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          18,
          12,
          18,
          12 + MediaQuery.paddingOf(context).bottom,
        ),
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: FilledButton(
          onPressed: _submitting ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.textPrimary,
            foregroundColor: AppColors.onDarkPrimary,
            padding: const EdgeInsets.symmetric(vertical: 15),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: Text(
            _submitting ? AppStrings.publishSuccess : AppStrings.publishSubmit,
          ),
        ),
      ),
    );
  }
}

/// Input-styled tappable row for the structured pickers (time, place).
class _PickerField extends StatelessWidget {
  const _PickerField({
    super.key,
    required this.icon,
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  final IconData icon;
  final String value;
  final String placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool hasValue = value.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 17, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasValue ? value : placeholder,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: hasValue
                      ? AppColors.textPrimary
                      : AppColors.textHint,
                ),
              ),
            ),
            const Icon(
              Iconsax.arrow_right_3,
              size: 15,
              color: AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet: type-ahead venue search (OpenStreetMap Nominatim). Falls
/// back to using the typed text as a free-form place so publishing never
/// blocks on the search service.
class _PlaceSearchSheet extends StatefulWidget {
  const _PlaceSearchSheet();

  @override
  State<_PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends State<_PlaceSearchSheet> {
  final PlaceSearch _search = PlaceSearch();
  final TextEditingController _queryController = TextEditingController();
  Timer? _debounce;
  List<PlaceResult> _results = <PlaceResult>[];
  bool _loading = false;
  Position? _myPosition;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  /// Best-effort fix so suggestions are biased to the caller's current city;
  /// search still works nationwide when location is unavailable.
  Future<void> _locate() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final Position position =
          await Geolocator.getLastKnownPosition() ??
              await Geolocator.getCurrentPosition();
      if (mounted) {
        _myPosition = position;
      }
    } on Exception {
      // Keep nationwide search.
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() => _results = <PlaceResult>[]);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      setState(() => _loading = true);
      List<PlaceResult> results;
      try {
        results = await _search.search(
          query.trim(),
          nearLat: _myPosition?.latitude,
          nearLng: _myPosition?.longitude,
        );
      } on Exception {
        results = <PlaceResult>[];
      }
      if (mounted) {
        setState(() {
          _results = _sortedByDistance(results);
          _loading = false;
        });
      }
    });
  }

  /// Nearest first when the caller's location is known.
  List<PlaceResult> _sortedByDistance(List<PlaceResult> results) {
    final Position? position = _myPosition;
    if (position == null) {
      return results;
    }
    final List<PlaceResult> sorted = List<PlaceResult>.of(results);
    sorted.sort(
      (PlaceResult a, PlaceResult b) =>
          _distanceTo(a)!.compareTo(_distanceTo(b)!),
    );
    return sorted;
  }

  double? _distanceTo(PlaceResult place) {
    final Position? position = _myPosition;
    if (position == null) {
      return null;
    }
    return distanceKmBetween(
      position.latitude,
      position.longitude,
      place.lat,
      place.lng,
    );
  }

  @override
  Widget build(BuildContext context) {
    final String query = _queryController.text.trim();
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 18, 18, 10),
              child: Text(
                AppStrings.placeSearchTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: TextField(
                controller: _queryController,
                autofocus: true,
                onChanged: _onQueryChanged,
                decoration: InputDecoration(
                  hintText: AppStrings.placeSearchHint,
                  prefixIcon: const Icon(Iconsax.search_normal, size: 18),
                  suffixIcon: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 20),
                children: <Widget>[
                  if (query.isNotEmpty)
                    ListTile(
                      leading: const Icon(Iconsax.edit_2, size: 18),
                      title: Text(
                        AppStrings.placeSearchUseTyped(query),
                        style: const TextStyle(fontSize: 14),
                      ),
                      onTap: () => Navigator.of(context).pop(
                        PlaceResult(
                          name: query,
                          address: query,
                          lat: 0,
                          lng: 0,
                        ),
                      ),
                    ),
                  if (query.length >= 2 && !_loading && _results.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(18),
                      child: Text(
                        AppStrings.placeSearchEmpty,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textHint,
                        ),
                      ),
                    ),
                  ..._results.map(
                    (PlaceResult place) => ListTile(
                      leading: const Icon(Iconsax.location, size: 18),
                      title: Text(
                        place.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        place.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: _distanceTo(place) == null
                          ? null
                          : Text(
                              AppStrings.distanceAway(
                                _distanceTo(place)!.toStringAsFixed(1),
                              ),
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textHint,
                              ),
                            ),
                      onTap: () => Navigator.of(context).pop(place),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Read-only service fee preview: pricing is platform-set per scene, so the
/// poster cannot edit it. The poster always pays the full fee.
class _MatchFeeCard extends StatelessWidget {
  const _MatchFeeCard({required this.fee});

  final int fee;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Iconsax.shield_tick, size: 17, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Text(
                      AppStrings.tipLabel,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      MoneyFormat.format(fee),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  AppStrings.publishTipPayNote,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label, {this.hint});

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

