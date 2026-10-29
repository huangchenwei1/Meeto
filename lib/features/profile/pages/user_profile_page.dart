import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/verified_badge.dart';
import '../data/profile_repository.dart';
import '../models/profile_parts.dart';
import '../models/user_detail.dart';

/// Public profile of another user: bio, tags, photos, info, stats and
/// reviews.
class UserProfilePage extends StatefulWidget {
  const UserProfilePage({
    super.key,
    required this.userId,
    required this.profileRepository,
  });

  final String userId;
  final ProfileRepository profileRepository;

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  UserDetail? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final UserDetail? user =
        await widget.profileRepository.fetchUserDetail(widget.userId);
    if (!mounted) {
      return;
    }
    setState(() {
      _user = user;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final UserDetail? user = _user;
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.profileTitle)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : user == null
              ? const SizedBox.shrink()
              : ListView(
                  padding: const EdgeInsets.only(bottom: 30),
                  children: <Widget>[
                    _Hero(user: user),
                    if (user.photos.isNotEmpty) _PhotoStrip(user: user),
                    if (user.info.isNotEmpty) _InfoCard(info: user.info),
                    _StatsCard(stats: user.stats),
                    if (user.reviews.isNotEmpty) ...<Widget>[
                      const _SectionTitle(AppStrings.profileReviews),
                      ...user.reviews
                          .map((UserReview r) => _ReviewTile(review: r)),
                    ],
                  ],
                ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.user});

  final UserDetail user;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 0),
      child: Column(
        children: <Widget>[
          AppAvatar(size: 86, imageUrl: user.avatarUrl),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                user.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 7),
              if (user.isVerified) const VerifiedBadge(),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            <String>[user.meta, user.city, user.joinedText]
                .where((String part) => part.isNotEmpty)
                .join(' \u00b7 '),
            style: const TextStyle(fontSize: 12, color: AppColors.textHint),
          ),
          if (user.bio.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              user.bio,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.7,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: user.tags
                .map(
                  (String tag) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.user});

  final UserDetail user;

  @override
  Widget build(BuildContext context) {
    final List<String> photos = <String>[
      if (user.avatarUrl.isNotEmpty) user.avatarUrl,
      ...user.photos,
    ];
    return SizedBox(
      height: 152,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
        itemCount: photos.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (BuildContext context, int index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AppNetworkImage(url: photos[index], width: 104, height: 134),
          );
        },
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.info});

  final List<ProfileInfoItem> info;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < info.length; i++) ...<Widget>[
            if (i > 0) const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 92,
                    child: Text(
                      info[i].label,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      info[i].value,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});

  final List<ProfileStat> stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: stats
            .map(
              (ProfileStat s) => Expanded(
                child: Column(
                  children: <Widget>[
                    Text(
                      s.value,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.label,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final UserReview review;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              AppAvatar(size: 24, imageUrl: review.avatarUrl),
              const SizedBox(width: 8),
              Text(
                review.fromName,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              const Icon(Iconsax.star1, size: 14, color: AppColors.accent),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            review.text,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

