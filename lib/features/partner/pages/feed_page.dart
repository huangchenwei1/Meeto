import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/env/app_env.dart';
import '../../../core/session/auth_session.dart';
import '../../../core/theme/app_colors.dart';
import '../../community/pages/community_guidelines_page.dart';
import '../../orders/data/orders_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/pages/user_profile_page.dart';
import '../data/partner_repository.dart';
import '../models/date_post.dart';
import '../widgets/moment_card.dart';
import '../widgets/post_card.dart';
import 'moment_composer_page.dart';
import 'post_detail_page.dart';
import 'publish_page.dart';

/// Home tab: scene filter chips, promo banner and the date post feed.
class FeedPage extends StatefulWidget {
  const FeedPage({
    super.key,
    required this.partnerRepository,
    required this.profileRepository,
    required this.ordersRepository,
  });

  final PartnerRepository partnerRepository;
  final ProfileRepository profileRepository;
  final OrdersRepository ordersRepository;

  @override
  State<FeedPage> createState() => FeedPageState();
}

class FeedPageState extends State<FeedPage> {
  List<DatePost> _posts = <DatePost>[];
  List<String> _scenes = <String>[];
  String? _selectedScene;
  bool _isLoading = true;
  Timer? _pollTimer;
  Position? _viewerPosition;

  @override
  void initState() {
    super.initState();
    _loadScenes();
    _loadPosts();
    _locateViewer();
    if (AppEnv.useRemoteApi) {
      // API mode: other users publish in real time; poll quietly so new
      // posts appear without a manual refresh.
      _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _loadPosts(silent: true);
      });
    }
  }

  /// Best-effort fix so cards can show the real distance to each venue;
  /// cards simply hide the distance when location is unavailable.
  Future<void> _locateViewer() async {
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
        setState(() => _viewerPosition = position);
      }
    } on Exception {
      // Distance stays hidden.
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  /// Re-fetches the feed; called by the shell when this tab is reselected.
  void reload() {
    _loadPosts(silent: true);
  }

  Future<void> _loadScenes() async {
    final List<String> scenes = await widget.partnerRepository.fetchScenes();
    if (!mounted) {
      return;
    }
    setState(() => _scenes = scenes);
  }

  Future<void> _loadPosts({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }
    final List<DatePost> posts;
    try {
      posts = await widget.partnerRepository.fetchPosts(
        sceneTag: _selectedScene,
      );
    } on Exception {
      // Transient failure (e.g. a poll while offline); keep the last list.
      if (!silent && mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _posts = posts;
      _isLoading = false;
    });
  }

  Future<void> _openDetail(DatePost post) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PostDetailPage(
          post: post,
          partnerRepository: widget.partnerRepository,
          profileRepository: widget.profileRepository,
          ordersRepository: widget.ordersRepository,
        ),
      ),
    );
    _loadPosts();
  }

  void _openAuthor(DatePost post) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UserProfilePage(
          userId: post.author.id,
          profileRepository: widget.profileRepository,
        ),
      ),
    );
  }

  Future<void> _openPublish() async {
    final bool? published = await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => PublishPage(repository: widget.partnerRepository),
      ),
    );
    if (published ?? false) {
      setState(() => _selectedScene = null);
      _loadPosts();
    }
  }

  Future<void> _openMomentComposer() async {
    final bool? posted = await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) =>
            MomentComposerPage(repository: widget.partnerRepository),
      ),
    );
    if (posted ?? false) {
      setState(() => _selectedScene = null);
      _loadPosts();
    }
  }

  /// Compose entry: hosts only share moments; users pick between an
  /// activity request and a moment.
  Future<void> _openCompose() async {
    if (AuthSession.isHost) {
      return _openMomentComposer();
    }
    final String? choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                key: const ValueKey<String>('composeDemandOption'),
                leading: const Icon(Iconsax.calendar_add),
                title: const Text(AppStrings.composeDemandOption),
                subtitle: const Text(
                  AppStrings.composeDemandSub,
                  style: TextStyle(fontSize: 12.5),
                ),
                onTap: () => Navigator.of(sheetContext).pop('demand'),
              ),
              ListTile(
                key: const ValueKey<String>('composeMomentOption'),
                leading: const Icon(Iconsax.gallery),
                title: const Text(AppStrings.composeMomentOption),
                subtitle: const Text(
                  AppStrings.composeMomentSub,
                  style: TextStyle(fontSize: 12.5),
                ),
                onTap: () => Navigator.of(sheetContext).pop('moment'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (!mounted) {
      return;
    }
    if (choice == 'demand') {
      await _openPublish();
    } else if (choice == 'moment') {
      await _openMomentComposer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _openCompose,
        backgroundColor: AppColors.textPrimary,
        foregroundColor: AppColors.onDarkPrimary,
        shape: const CircleBorder(),
        child: const Icon(Iconsax.add, size: 26),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: _SceneFilterBar(
                scenes: _scenes,
                selected: _selectedScene,
                onSelected: (String? scene) {
                  setState(() => _selectedScene = scene);
                  _loadPosts();
                },
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () => _loadPosts(silent: true),
                      child: _posts.isEmpty
                          ? ListView(
                              physics:
                                  const AlwaysScrollableScrollPhysics(),
                              children: const <Widget>[
                                SizedBox(height: 160),
                                Center(
                                  child: Text(
                                    AppStrings.emptyFeed,
                                    style: TextStyle(
                                      color: AppColors.textHint,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              physics:
                                  const AlwaysScrollableScrollPhysics(),
                              padding:
                                  const EdgeInsets.fromLTRB(16, 4, 16, 96),
                              itemCount: _posts.length + 1,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 20),
                              itemBuilder:
                                  (BuildContext context, int index) {
                                if (index == 0) {
                                  return _GuidelinesBanner(
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            const CommunityGuidelinesPage(),
                                      ),
                                    ),
                                  );
                                }
                                final DatePost post = _posts[index - 1];
                                if (post.isMoment) {
                                  return MomentCard(
                                    post: post,
                                    onAuthorTap: () => _openAuthor(post),
                                  );
                                }
                                return PostCard(
                                  post: post,
                                  onTap: () => _openDetail(post),
                                  onAuthorTap: () => _openAuthor(post),
                                  viewerLat: _viewerPosition?.latitude,
                                  viewerLng: _viewerPosition?.longitude,
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SceneFilterBar extends StatelessWidget {
  const _SceneFilterBar({
    required this.scenes,
    required this.selected,
    required this.onSelected,
  });

  final List<String> scenes;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: scenes.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final bool isAll = index == 0;
          final String label =
              isAll ? AppStrings.filterForYou : scenes[index - 1];
          final bool isSelected = isAll ? selected == null : selected == label;
          return InkWell(
            onTap: () => onSelected(isAll ? null : label),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.textPrimary
                    : AppColors.background,
                border: Border.all(
                  color:
                      isSelected ? AppColors.textPrimary : AppColors.border,
                ),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? AppColors.background
                      : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GuidelinesBanner extends StatelessWidget {
  const _GuidelinesBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: const <Widget>[
                    Icon(Iconsax.star1, size: 13, color: AppColors.accent),
                    SizedBox(width: 5),
                    Text(
                      AppStrings.bannerEyebrow,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                const Text(
                  AppStrings.bannerTitle,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onDarkPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  AppStrings.bannerSub,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.onDarkSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.background,
              foregroundColor: AppColors.textPrimary,
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text(AppStrings.bannerCta),
          ),
        ],
      ),
    );
  }
}
