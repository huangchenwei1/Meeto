import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/time_ago.dart';
import '../../../core/session/auth_session.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/pages/user_profile_page.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/verified_badge.dart';
import '../data/community_repository.dart';
import '../models/activity_post.dart';

/// Full view of one sharing-wall recap (moment), in the discovery-feed
/// style: a swipeable photo pager on top, then the full text, the venue
/// recommendation and the post time. Non-transactional — no price and no
/// CTA. The author row opens their profile; the author can delete their
/// own moment. Pops `true` when the moment was deleted so the wall can
/// refresh.
class MomentDetailPage extends StatefulWidget {
  const MomentDetailPage({
    super.key,
    required this.post,
    required this.communityRepository,
    required this.profileRepository,
  });

  final ActivityPost post;
  final CommunityRepository communityRepository;
  final ProfileRepository profileRepository;

  @override
  State<MomentDetailPage> createState() => _MomentDetailPageState();
}

class _MomentDetailPageState extends State<MomentDetailPage> {
  int _photoIndex = 0;

  bool get _isMine => widget.post.author.id == AuthSession.currentUserId;

  List<String> get _photos => widget.post.images
      .where((String url) => url.isNotEmpty)
      .toList(growable: false);

  void _openAuthor() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UserProfilePage(
          userId: widget.post.author.id,
          profileRepository: widget.profileRepository,
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text(AppStrings.deletePostConfirmTitle),
        content: const Text(AppStrings.deleteMomentConfirmBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.deletePostNo),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              AppStrings.deletePostYes,
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false) || !mounted) {
      return;
    }
    try {
      await widget.communityRepository.deletePost(widget.post.id);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppStrings.deletePostDone)));
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ActivityPost post = widget.post;
    final List<String> photos = _photos;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          key: const ValueKey<String>('momentDetailAuthor'),
          onTap: _openAuthor,
          borderRadius: BorderRadius.circular(999),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AppAvatar(size: 32, imageUrl: post.author.avatarUrl),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  post.author.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (post.author.isVerified) ...<Widget>[
                const SizedBox(width: 5),
                const VerifiedBadge(),
              ],
            ],
          ),
        ),
        actions: <Widget>[
          if (_isMine)
            IconButton(
              key: const ValueKey<String>('momentDeleteButton'),
              onPressed: _confirmDelete,
              icon: const Icon(Iconsax.trash, size: 20),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: <Widget>[
          if (photos.isNotEmpty)
            Stack(
              alignment: Alignment.bottomCenter,
              children: <Widget>[
                AspectRatio(
                  aspectRatio: 3 / 4,
                  child: PageView.builder(
                    itemCount: photos.length,
                    onPageChanged: (int index) =>
                        setState(() => _photoIndex = index),
                    itemBuilder: (BuildContext context, int index) =>
                        AppNetworkImage(url: photos[index]),
                  ),
                ),
                if (photos.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        for (int i = 0; i < photos.length; i++)
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == _photoIndex
                                  ? Colors.white
                                  : Colors.white54,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  post.description,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.55,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (post.venue.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Iconsax.location5,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            post.venue,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  formatTimeAgo(post.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint,
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
