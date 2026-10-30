import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/form_widgets.dart';
import '../../auth/pages/verification_page.dart';
import '../data/community_repository.dart';

/// Full-screen form to publish a new activity request: scene, title and
/// description only — the same field set as the hosts' pitch composer, so
/// both sides of the board read identically. Time and place are
/// deliberately absent: the selected host proposes the concrete plan after
/// the match (the plan flow). The platform fee rides on the scene chips.
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
          const FormFieldLabel(AppStrings.publishScene),
          ScenePriceChips(
            scenes: _scenes,
            selected: _selectedScene,
            onSelect: (String scene) =>
                setState(() => _selectedScene = scene),
            keyPrefix: 'publishScene',
          ),
          const FormFieldLabel(AppStrings.publishFieldTitle),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              hintText: AppStrings.publishPhTitle,
            ),
          ),
          const FormFieldLabel(
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

