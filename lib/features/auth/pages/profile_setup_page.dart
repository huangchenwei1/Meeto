import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/session/auth_session.dart';
import '../../../core/theme/app_colors.dart';
import '../../home/home_shell.dart';
import '../data/auth_repository.dart';

/// Profile setup (API mode).
///
/// Registration runs as a Tinder-style wizard — gender, name, birth month,
/// height & weight, city, work & education, interests, photos — one light
/// topic per screen, everything picked from fixed options (only the name is
/// typed). The account is created right after the name step; later steps
/// are saved in one PATCH at the end.
///
/// From the Me tab it runs as a single-page edit form ([isEditing]) reusing
/// the same selection widgets (gender and name are not editable there).
class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({
    super.key,
    required this.client,
    this.isEditing = false,
    this.authRepository,
    this.registrationToken,
  });

  final ApiClient client;
  final bool isEditing;

  /// Required in registration mode: the wizard itself creates the account
  /// after the gender + name steps.
  final AuthRepository? authRepository;
  final String? registrationToken;

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  static const int _maxWallPhotos = 3;

  /// Hosts get one extra step at the end: the activities they can host.
  int get _stepCount => 10;
  static const List<String> _monthNames = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const int _minHeight = 140;
  static const int _maxHeight = 210;
  static const int _minWeight = 35;
  static const int _maxWeight = 120;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final PageController _pageController = PageController();

  late final List<int> _years;
  late final FixedExtentScrollController _yearWheel;
  late final FixedExtentScrollController _monthWheel;
  late final FixedExtentScrollController _heightWheel;
  late final FixedExtentScrollController _weightWheel;

  /// 'USER' | 'HOST', chosen on the first step and fixed after sign-up.
  String? _role;
  String? _gender;
  int? _birthYear;
  int? _birthMonth;
  int? _heightCm;
  int? _weightKg;
  String? _country;
  String? _city;
  String? _education;
  String? _job;
  final Set<String> _tags = <String>{};

  String? _avatarUrl; // root-relative, as stored server-side
  final List<String> _photoUrls = <String>[];
  bool _busy = false;

  /// While an edit bottom sheet is open, rebuilds its content alongside the
  /// page (chips and wheels mutate page state from inside the sheet).
  StateSetter? _sheetSetState;
  bool _registered = false;
  int _step = 0;

  bool get _isLastStep => _step == _stepCount - 1;

  @override
  void initState() {
    super.initState();
    final int maxYear = DateTime.now().year - 18;
    _years = List<int>.generate(63, (int i) => maxYear - i); // 18..80 years
    _yearWheel = FixedExtentScrollController(initialItem: 7); // ~25 years old
    _monthWheel = FixedExtentScrollController();
    _heightWheel = FixedExtentScrollController(initialItem: 165 - _minHeight);
    _weightWheel = FixedExtentScrollController(initialItem: 55 - _minWeight);
    if (widget.isEditing) {
      _registered = true;
      _prefill();
    }
  }

  Future<void> _prefill() async {
    try {
      final Map<String, dynamic> user =
          await widget.client.get('/users/me') as Map<String, dynamic>;
      if (!mounted) {
        return;
      }
      setState(() {
        _role = user['role'] as String?;
        final String avatar = user['avatarUrl'] as String? ?? '';
        _avatarUrl = avatar.isEmpty ? null : avatar;
        _nameController.text = user['name'] as String? ?? '';
        _bioController.text = user['bio'] as String? ?? '';
        _heightCm = user['heightCm'] as int?;
        _weightKg = user['weightKg'] as int?;
        final String country = user['country'] as String? ?? '';
        _country = country.isEmpty ? null : country;
        final String city = user['city'] as String? ?? '';
        _city = city.isEmpty ? null : city;
        final String education = user['education'] as String? ?? '';
        _education = education.isEmpty ? null : education;
        final String job = user['job'] as String? ?? '';
        _job = job.isEmpty ? null : job;
        _tags
          ..clear()
          ..addAll(
            (user['tags'] as List<dynamic>? ?? <dynamic>[]).cast<String>(),
          );
        _photoUrls
          ..clear()
          ..addAll(
            (user['photos'] as List<dynamic>? ?? <dynamic>[]).cast<String>(),
          );
      });
    } on Exception {
      // Keep the empty form; the user can still fill and save.
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _pageController.dispose();
    _yearWheel.dispose();
    _monthWheel.dispose();
    _heightWheel.dispose();
    _weightWheel.dispose();
    super.dispose();
  }

  Future<String?> _pickAndUpload() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1440,
      imageQuality: 85,
    );
    if (picked == null) {
      return null;
    }
    try {
      return await widget.client.uploadImage(
        await picked.readAsBytes(),
        picked.name,
      );
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.setupUploadFailed)),
        );
      }
      return null;
    }
  }

  Future<void> _pickAvatar() async {
    final String? url = await _pickAndUpload();
    if (url != null && mounted) {
      setState(() => _avatarUrl = url);
    }
  }

  Future<void> _addWallPhoto() async {
    if (_photoUrls.length >= _maxWallPhotos) {
      return;
    }
    final String? url = await _pickAndUpload();
    if (url != null && mounted) {
      setState(() => _photoUrls.add(url));
    }
  }

  /// The avatar is mandatory: it is the reference photo real-person
  /// verification matches the liveness selfie against.
  bool _requireAvatar() {
    if (_avatarUrl != null) {
      return true;
    }
    _hint(AppStrings.setupAvatarRequired);
    return false;
  }

  void _hint(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (!_requireAvatar()) {
      return;
    }
    setState(() => _busy = true);
    try {
      final Map<String, dynamic> body = <String, dynamic>{
        'avatarUrl': ?_avatarUrl,
        // The birth date is locked after registration (18+ gate); the edit
        // form never sends it and the server rejects changes anyway.
        if (!widget.isEditing && _birthYear != null)
          'birthDate': DateTime.utc(_birthYear!, _birthMonth ?? 1)
              .toIso8601String(),
        'heightCm': ?_heightCm,
        'weightKg': ?_weightKg,
        'country': ?_country,
        'city': ?_city,
        'education': ?_education,
        'job': ?_job,
        if (_tags.isNotEmpty || widget.isEditing)
          'tags': _tags.toList(growable: false),
        if (_bioController.text.trim().isNotEmpty)
          'bio': _bioController.text.trim(),
        if (_photoUrls.isNotEmpty || widget.isEditing) 'photos': _photoUrls,
      };
      final Map<String, dynamic> user = await widget.client
          .patch('/users/me', body: body) as Map<String, dynamic>;
      AuthSession.setUser(
        id: user['id'] as String,
        name: user['name'] as String,
        avatarUrl: user['avatarUrl'] as String? ?? '',
        meta: user['meta'] as String? ?? '',
        gender: user['gender'] as String? ?? AuthSession.currentUserGender,
      );
      _finish();
    } on ApiException catch (e) {
      _hint(e.message);
    } on Exception {
      _hint(AppStrings.errorNetwork);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _finish() {
    if (widget.isEditing) {
      Navigator.of(context).pop(true);
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const HomeShell()),
      (_) => false,
    );
  }

  void _goTo(int step) {
    setState(() => _step = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _register() async {
    setState(() => _busy = true);
    try {
      await widget.authRepository!.register(
        registrationToken: widget.registrationToken!,
        name: _nameController.text.trim(),
        gender: _gender!,
        role: _role!,
      );
      _registered = true;
    } on Exception catch (e) {
      _hint(e is AuthException ? e.message : AppStrings.errorNetwork);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _next() async {
    switch (_step) {
      case 0:
        if (_role == null) {
          _hint(AppStrings.roleRequiredHint);
          return;
        }
      case 1:
        if (_gender == null) {
          _hint(AppStrings.genderRequiredHint);
          return;
        }
      case 2:
        if (_nameController.text.trim().isEmpty) {
          _hint(AppStrings.nameRequiredHint);
          return;
        }
        if (!_registered) {
          await _register();
          if (!_registered) {
            return; // registration failed, stay on this step
          }
        }
      case 3:
        // Passing the birth step confirms the values shown on the wheels.
        _birthYear ??= _years[_yearWheel.selectedItem];
        _birthMonth ??= _monthWheel.selectedItem + 1;
      case 4:
        _heightCm ??= _minHeight + _heightWheel.selectedItem;
        _weightKg ??= _minWeight + _weightWheel.selectedItem;
    }
    if (_isLastStep) {
      await _save();
    } else {
      _goTo(_step + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.isEditing ? _buildEditPage() : _buildWizard();
  }

  // ---------------------------------------------------------------- wizard

  /// Height/weight, location, work, interests and bio are skippable;
  /// role, gender, name, birth date (18+ gate) and the main photo are not.
  bool get _canSkipStep => _step >= 4 && _step <= 8;

  bool get _canGoBack => _step > 0 && !(_registered && _step <= 3);

  Widget _buildWizard() {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 64,
                    child: _canGoBack
                        ? IconButton(
                            onPressed: _busy ? null : () => _goTo(_step - 1),
                            icon: const Icon(
                              Icons.arrow_back_ios_new,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                          )
                        : null,
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: (_step + 1) / _stepCount,
                        minHeight: 4,
                        backgroundColor: AppColors.surface,
                        color: AppColors.darkCard,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: _canSkipStep
                        ? TextButton(
                            key: const ValueKey<String>('setupSkipButton'),
                            onPressed: _busy ? null : () => _goTo(_step + 1),
                            child: const Text(
                              AppStrings.setupStepSkip,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: <Widget>[
                  _stepPage(
                    title: AppStrings.setupStepRoleTitle,
                    sub: AppStrings.setupStepRoleSub,
                    fields: <Widget>[_roleCards()],
                  ),
                  _stepPage(
                    title: AppStrings.setupStepGenderTitle,
                    sub: AppStrings.setupStepGenderSub,
                    fields: <Widget>[_genderCards()],
                  ),
                  _stepPage(
                    title: AppStrings.setupStepNameTitle,
                    sub: AppStrings.setupStepNameSub,
                    fields: <Widget>[_nameField()],
                  ),
                  _stepPage(
                    title: AppStrings.setupStepBirthTitle,
                    sub: AppStrings.setupStepBirthSub,
                    fields: <Widget>[_birthWheels()],
                  ),
                  _stepPage(
                    title: AppStrings.setupStepBodyTitle,
                    sub: AppStrings.setupStepBodySub,
                    fields: <Widget>[_bodyWheels()],
                  ),
                  _stepPage(
                    title: AppStrings.setupStepLocationTitle,
                    sub: AppStrings.setupStepLocationSub,
                    fields: _locationFields(),
                  ),
                  _stepPage(
                    title: AppStrings.setupStepWorkTitle,
                    sub: AppStrings.setupStepWorkSub,
                    fields: _workFields(),
                  ),
                  _stepPage(
                    title: AppStrings.setupStepTagsTitle,
                    sub: AppStrings.setupStepTagsSub,
                    fields: <Widget>[_tagsChips()],
                  ),
                  _stepPage(
                    title: AppStrings.setupStepBioTitle,
                    sub: AppStrings.setupStepBioSub,
                    fields: <Widget>[_bioField()],
                  ),
                  _stepPage(
                    title: AppStrings.setupStepPhotosTitle,
                    sub: AppStrings.setupStepPhotosSub,
                    fields: <Widget>[_photoGrid()],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey<String>('setupNextButton'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.darkCard,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _busy ? null : _next,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onDarkPrimary,
                          ),
                        )
                      : Text(
                          _isLastStep
                              ? AppStrings.setupFinish
                              : AppStrings.setupNext,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepPage({
    required String title,
    required String sub,
    required List<Widget> fields,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          sub,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 28),
        ...fields,
      ],
    );
  }

  // ------------------------------------------------------------- edit page

  /// Compact form: photos on a single row, then the pick-from-options
  /// fields as tappable list rows opening bottom sheets. The birth date is
  /// intentionally absent — it is locked after registration.
  Widget _buildEditPage() {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.menuEditProfile)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          children: <Widget>[
            _LabeledField(
              label: AppStrings.editPhotosLabel,
              child: _photoRow(),
            ),
            const SizedBox(height: 24),
            _editList(),
            const SizedBox(height: 24),
            _LabeledField(
              label: AppStrings.setupBioLabel,
              child: _bioField(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey<String>('setupSaveButton'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.darkCard,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onDarkPrimary,
                        ),
                      )
                    : const Text(
                        AppStrings.setupSave,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// setState plus a rebuild of the open bottom sheet, if any.
  void _refresh(VoidCallback fn) {
    setState(fn);
    _sheetSetState?.call(() {});
  }

  /// Main photo plus the photo wall on a single compact row.
  Widget _photoRow() {
    return Row(
      children: <Widget>[
        Expanded(
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: _photoTile(
              key: const ValueKey<String>('setupAvatarPicker'),
              url: _avatarUrl,
              badge: AppStrings.setupMainPhotoBadge,
              onTap: _pickAvatar,
            ),
          ),
        ),
        for (int i = 0; i < _maxWallPhotos; i++) ...<Widget>[
          const SizedBox(width: 10),
          Expanded(
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: _photoTile(
                url: i < _photoUrls.length ? _photoUrls[i] : null,
                onTap: i <= _photoUrls.length ? _addWallPhoto : null,
                onRemove: i < _photoUrls.length
                    ? () => setState(() => _photoUrls.removeAt(i))
                    : null,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _editList() {
    final List<Widget> rows = <Widget>[
      _editRow(
        label: AppStrings.setupStepBodyTitle,
        value: _heightCm == null && _weightKg == null
            ? AppStrings.editNotSet
            : '${_heightCm ?? '-'} cm \u00b7 ${_weightKg ?? '-'} kg',
        onTap: _openBodySheet,
      ),
      _editRow(
        label: AppStrings.editLocationLabel,
        value: <String>[?_country, ?_city].isEmpty
            ? AppStrings.editNotSet
            : <String>[?_country, ?_city].join(' \u00b7 '),
        onTap: () => _openSheet(
          title: AppStrings.setupStepLocationTitle,
          fieldsOf: _locationFields,
        ),
      ),
      _editRow(
        label: AppStrings.setupEducationLabel,
        value: _education ?? AppStrings.editNotSet,
        onTap: () => _openSheet(
          title: AppStrings.setupEducationLabel,
          fieldsOf: () => <Widget>[_educationChips()],
        ),
      ),
      _editRow(
        label: AppStrings.setupJobLabel,
        value: _job ?? AppStrings.editNotSet,
        onTap: () => _openSheet(
          title: AppStrings.setupJobLabel,
          fieldsOf: () => <Widget>[_jobChips()],
        ),
      ),
      _editRow(
        label: AppStrings.setupTagsLabel,
        value: _tags.isEmpty ? AppStrings.editNotSet : _tags.join(', '),
        onTap: () => _openSheet(
          title: AppStrings.setupTagsLabel,
          fieldsOf: () => <Widget>[_tagsChips()],
        ),
      ),
    ];
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          for (int i = 0; i < rows.length; i++) ...<Widget>[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1,
                indent: 16,
                endIndent: 16,
                color: AppColors.border,
              ),
            rows[i],
          ],
        ],
      ),
    );
  }

  Widget _editRow({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final bool isSet = value != AppStrings.editNotSet;
    return InkWell(
      onTap: _busy ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color:
                      isSet ? AppColors.textSecondary : AppColors.textHint,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }

  /// Bottom sheet hosting the same selection widgets the wizard uses;
  /// [fieldsOf] is re-run on every rebuild so dependent fields (e.g. the
  /// city list after a country change) stay in sync.
  Future<void> _openSheet({
    required String title,
    required List<Widget> Function() fieldsOf,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            _sheetSetState = setSheetState;
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: fieldsOf(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.darkCard,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: const Text(
                          AppStrings.sheetDone,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    _sheetSetState = null;
  }

  /// Height & weight picker sheet with its own wheel controllers positioned
  /// at the current values (the wizard wheels live on other pages).
  Future<void> _openBodySheet() async {
    setState(() {
      _heightCm ??= 165;
      _weightKg ??= 55;
    });
    final FixedExtentScrollController heightWheel =
        FixedExtentScrollController(initialItem: _heightCm! - _minHeight);
    final FixedExtentScrollController weightWheel =
        FixedExtentScrollController(initialItem: _weightKg! - _minWeight);
    await _openSheet(
      title: AppStrings.setupStepBodyTitle,
      fieldsOf: () => <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _wheel(
                label: AppStrings.setupHeightLabel,
                controller: heightWheel,
                count: _maxHeight - _minHeight + 1,
                textOf: (int i) => '${_minHeight + i} cm',
                onChanged: (int i) =>
                    _refresh(() => _heightCm = _minHeight + i),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _wheel(
                label: AppStrings.setupWeightLabel,
                controller: weightWheel,
                count: _maxWeight - _minWeight + 1,
                textOf: (int i) => '${_minWeight + i} kg',
                onChanged: (int i) =>
                    _refresh(() => _weightKg = _minWeight + i),
              ),
            ),
          ],
        ),
      ],
    );
    heightWheel.dispose();
    weightWheel.dispose();
  }

  // -------------------------------------------------------- shared fields

  Widget _genderCards() {
    return Column(
      children: <Widget>[
        _genderCard('FEMALE', AppStrings.genderFemaleLabel, Icons.female),
        const SizedBox(height: 14),
        _genderCard('MALE', AppStrings.genderMaleLabel, Icons.male),
      ],
    );
  }

  Widget _roleCards() {
    return Column(
      children: <Widget>[
        _roleCard(
          'USER',
          AppStrings.roleUserLabel,
          AppStrings.roleUserSub,
          Icons.explore_outlined,
        ),
        const SizedBox(height: 14),
        _roleCard(
          'HOST',
          AppStrings.roleHostLabel,
          AppStrings.roleHostSub,
          Icons.emoji_people_outlined,
        ),
      ],
    );
  }

  Widget _roleCard(String value, String label, String sub, IconData icon) {
    final bool selected = _role == value;
    return GestureDetector(
      key: ValueKey<String>('roleCard$value'),
      onTap: _busy ? null : () => setState(() => _role = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        decoration: BoxDecoration(
          color: selected ? AppColors.darkCard : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.darkCard : AppColors.border,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              icon,
              size: 28,
              color: selected ? AppColors.onDarkPrimary : AppColors.textHint,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? AppColors.onDarkPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: selected
                          ? AppColors.onDarkPrimary.withValues(alpha: 0.75)
                          : AppColors.textSecondary,
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

  Widget _genderCard(String value, String label, IconData icon) {
    final bool selected = _gender == value;
    return GestureDetector(
      key: ValueKey<String>('genderCard$value'),
      onTap: _busy ? null : () => setState(() => _gender = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
        decoration: BoxDecoration(
          color: selected ? AppColors.darkCard : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.darkCard : AppColors.border,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              icon,
              size: 28,
              color: selected ? AppColors.onDarkPrimary : AppColors.textHint,
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: selected
                    ? AppColors.onDarkPrimary
                    : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nameField() {
    return TextField(
      key: const ValueKey<String>('setupNameField'),
      controller: _nameController,
      textCapitalization: TextCapitalization.words,
      maxLength: 40,
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      decoration: const InputDecoration(
        hintText: AppStrings.setupNameHint,
        counterText: '',
      ),
    );
  }

  Widget _birthWheels() {
    return Row(
      children: <Widget>[
        Expanded(
          child: _wheel(
            label: AppStrings.setupBirthYearLabel,
            controller: _yearWheel,
            count: _years.length,
            textOf: (int i) => '${_years[i]}',
            onChanged: (int i) => _birthYear = _years[i],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _wheel(
            label: AppStrings.setupBirthMonthLabel,
            controller: _monthWheel,
            count: 12,
            textOf: (int i) => _monthNames[i],
            onChanged: (int i) => _birthMonth = i + 1,
          ),
        ),
      ],
    );
  }

  Widget _bodyWheels() {
    return Row(
      children: <Widget>[
        Expanded(
          child: _wheel(
            label: AppStrings.setupHeightLabel,
            controller: _heightWheel,
            count: _maxHeight - _minHeight + 1,
            textOf: (int i) => '${_minHeight + i} cm',
            onChanged: (int i) => _heightCm = _minHeight + i,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _wheel(
            label: AppStrings.setupWeightLabel,
            controller: _weightWheel,
            count: _maxWeight - _minWeight + 1,
            textOf: (int i) => '${_minWeight + i} kg',
            onChanged: (int i) => _weightKg = _minWeight + i,
          ),
        ),
      ],
    );
  }

  Widget _wheel({
    required String label,
    required FixedExtentScrollController controller,
    required int count,
    required String Function(int index) textOf,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 160,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: CupertinoPicker.builder(
            scrollController: controller,
            itemExtent: 38,
            childCount: count,
            onSelectedItemChanged: onChanged,
            selectionOverlay: const CupertinoPickerDefaultSelectionOverlay(
              background: Color(0x11000000),
            ),
            itemBuilder: (BuildContext context, int index) => Center(
              child: Text(
                textOf(index),
                style: const TextStyle(
                  fontSize: 17,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _locationFields() {
    final List<String> cities = <String>[
      for (final (String, List<String>) entry in AppStrings.countryCities)
        if (entry.$1 == _country) ...entry.$2,
    ];
    return <Widget>[
      _LabeledField(
        label: AppStrings.setupCountryLabel,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final (String, List<String>) entry in AppStrings.countryCities)
              _choiceChip(
                label: entry.$1,
                selected: _country == entry.$1,
                onTap: () => _refresh(() {
                  if (_country != entry.$1) {
                    _country = entry.$1;
                    _city = null;
                  }
                }),
              ),
          ],
        ),
      ),
      if (cities.isNotEmpty) ...<Widget>[
        const SizedBox(height: 16),
        _LabeledField(
          label: AppStrings.setupCityLabel,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final String city in cities)
                _choiceChip(
                  label: city,
                  selected: _city == city,
                  onTap: () => _refresh(() => _city = city),
                ),
            ],
          ),
        ),
      ],
    ];
  }

  List<Widget> _workFields() {
    return <Widget>[
      _LabeledField(
        label: AppStrings.setupEducationLabel,
        child: _educationChips(),
      ),
      const SizedBox(height: 16),
      _LabeledField(
        label: AppStrings.setupJobLabel,
        child: _jobChips(),
      ),
    ];
  }

  Widget _educationChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final String option in AppStrings.educationOptions)
          _choiceChip(
            label: option,
            selected: _education == option,
            onTap: () => _refresh(
              () => _education = _education == option ? null : option,
            ),
          ),
      ],
    );
  }

  Widget _jobChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final String option in AppStrings.jobOptions)
          _choiceChip(
            label: option,
            selected: _job == option,
            onTap: () => _refresh(
              () => _job = _job == option ? null : option,
            ),
          ),
      ],
    );
  }

  Widget _choiceChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      labelStyle: TextStyle(
        fontSize: 13,
        color: selected ? AppColors.onDarkPrimary : AppColors.textSecondary,
      ),
      selectedColor: AppColors.darkCard,
      backgroundColor: AppColors.background,
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      onSelected: _busy ? null : (_) => onTap(),
    );
  }

  Widget _bioField() {
    return TextField(
      key: const ValueKey<String>('setupBioField'),
      controller: _bioController,
      maxLines: 5,
      maxLength: 600,
      decoration: const InputDecoration(
        hintText: AppStrings.setupBioHint,
      ),
    );
  }

  Widget _tagsChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final String tag in AppStrings.setupTagOptions)
          _choiceChip(
            label: tag,
            selected: _tags.contains(tag),
            onTap: () => _refresh(() {
              if (!_tags.add(tag)) {
                _tags.remove(tag);
              }
            }),
          ),
      ],
    );
  }

  // 2x2 photo grid: slot 0 is the mandatory main photo (avatar), the rest
  // is the photo wall.
  Widget _photoGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.92,
      children: <Widget>[
        _photoTile(
          key: const ValueKey<String>('setupAvatarPicker'),
          url: _avatarUrl,
          badge: AppStrings.setupMainPhotoBadge,
          onTap: _pickAvatar,
        ),
        for (int i = 0; i < _maxWallPhotos; i++)
          _photoTile(
            url: i < _photoUrls.length ? _photoUrls[i] : null,
            onTap: i <= _photoUrls.length ? _addWallPhoto : null,
            onRemove: i < _photoUrls.length
                ? () => setState(() => _photoUrls.removeAt(i))
                : null,
          ),
      ],
    );
  }

  Widget _photoTile({
    Key? key,
    required String? url,
    String? badge,
    VoidCallback? onTap,
    VoidCallback? onRemove,
  }) {
    return GestureDetector(
      key: key,
      onTap: _busy || onTap == null ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (url == null)
              const Center(
                child: Icon(Icons.add, size: 28, color: AppColors.textHint),
              )
            else
              Image.network(resolveMediaUrl(url), fit: BoxFit.cover),
            if (badge != null)
              Positioned(
                left: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.darkCard,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onDarkPrimary,
                    ),
                  ),
                ),
              ),
            if (url != null && onRemove != null)
              Positioned(
                right: 6,
                top: 6,
                child: GestureDetector(
                  onTap: _busy ? null : onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
