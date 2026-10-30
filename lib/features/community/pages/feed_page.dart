import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/env/app_env.dart';
import '../../../core/theme/app_colors.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/pages/user_profile_page.dart';
import '../data/community_repository.dart';
import '../models/activity_post.dart';
import '../widgets/moment_card.dart';
import 'community_guidelines_page.dart';
import 'moment_composer_page.dart';

/// Community tab, identical for both roles: the sharing wall. Members post
/// photo/text recaps of completed activities (moments). Demand posts never
/// show here — users manage theirs in My Posts, hosts take work from the
/// gig hall.
class FeedPage extends StatefulWidget {
  const FeedPage({
    super.key,
    required this.communityRepository,
    required this.profileRepository,
  });

  final CommunityRepository communityRepository;
  final ProfileRepository profileRepository;

  @override
  State<FeedPage> createState() => FeedPageState();
}

class FeedPageState extends State<FeedPage> {
  List<ActivityPost> _moments = <ActivityPost>[];
  bool _isLoading = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
    if (AppEnv.useRemoteApi) {
      // API mode: others publish in real time; poll quietly so new moments
      // appear without a manual refresh.
      _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _load(silent: true);
      });
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  /// Re-fetches the wall; called by the shell when this tab is reselected.
  void reload() {
    _load(silent: true);
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }
    final List<ActivityPost> moments;
    try {
      moments = await widget.communityRepository.fetchMoments();
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
      _moments = moments;
      _isLoading = false;
    });
  }

  void _openAuthor(ActivityPost post) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UserProfilePage(
          userId: post.author.id,
          profileRepository: widget.profileRepository,
        ),
      ),
    );
  }

  Future<void> _openMomentComposer() async {
    final bool? posted = await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) =>
            MomentComposerPage(repository: widget.communityRepository),
      ),
    );
    if (posted ?? false) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _openMomentComposer,
        backgroundColor: AppColors.textPrimary,
        foregroundColor: AppColors.onDarkPrimary,
        shape: const CircleBorder(),
        child: const Icon(Iconsax.add, size: 26),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () => _load(silent: true),
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: _moments.length + (_moments.isEmpty ? 2 : 1),
                  separatorBuilder: (_, _) => const SizedBox(height: 20),
                  itemBuilder: (BuildContext context, int index) {
                    if (index == 0) {
                      return _GuidelinesBanner(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const CommunityGuidelinesPage(),
                          ),
                        ),
                      );
                    }
                    if (_moments.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 120),
                        child: Center(
                          child: Text(
                            AppStrings.emptyFeed,
                            style: TextStyle(color: AppColors.textHint),
                          ),
                        ),
                      );
                    }
                    final ActivityPost post = _moments[index - 1];
                    return MomentCard(
                      post: post,
                      onAuthorTap: () => _openAuthor(post),
                    );
                  },
                ),
              ),
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
