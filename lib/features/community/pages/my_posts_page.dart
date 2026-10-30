import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/session/auth_session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/time_ago.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../orders/data/orders_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../data/community_repository.dart';
import '../models/activity_post.dart';
import 'post_detail_page.dart';

/// The caller's own posts, every status included. This is the management
/// view: matched/cancelled posts leave the public feed, so this page is the
/// only way back into them.
class MyPostsPage extends StatefulWidget {
  const MyPostsPage({
    super.key,
    required this.communityRepository,
    required this.profileRepository,
    required this.ordersRepository,
  });

  final CommunityRepository communityRepository;
  final ProfileRepository profileRepository;
  final OrdersRepository ordersRepository;

  @override
  State<MyPostsPage> createState() => _MyPostsPageState();
}

class _MyPostsPageState extends State<MyPostsPage> {
  List<ActivityPost> _posts = <ActivityPost>[];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final List<ActivityPost> posts = await widget.communityRepository
        .fetchPostsByAuthor(AuthSession.currentUserId);
    if (!mounted) {
      return;
    }
    setState(() {
      _posts = posts;
      _loaded = true;
    });
  }

  Future<void> _openDetail(ActivityPost post) async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => PostDetailPage(
          post: post,
          communityRepository: widget.communityRepository,
          profileRepository: widget.profileRepository,
          ordersRepository: widget.ordersRepository,
        ),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.menuMyPosts)),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _posts.isEmpty
              ? const Center(
                  child: Text(
                    AppStrings.myPostsEmpty,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _posts.length,
                  separatorBuilder: (_, int i) =>
                      const Divider(indent: 84, height: 1),
                  itemBuilder: (BuildContext context, int index) {
                    final ActivityPost post = _posts[index];
                    return _PostRow(
                      post: post,
                      onTap: () => _openDetail(post),
                    );
                  },
                ),
    );
  }
}

class _PostRow extends StatelessWidget {
  const _PostRow({required this.post, required this.onTap});

  final ActivityPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String meta =
        '${post.sceneTag} \u00b7 ${formatTimeAgo(post.createdAt)}';
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AppNetworkImage(url: post.imageUrl, width: 56, height: 56),
      ),
      title: Row(
        children: <Widget>[
          Flexible(
            child: Text(
              post.title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _PostStatusPill(status: post.status),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          meta,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.5,
          ),
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        size: 20,
        color: AppColors.textHint,
      ),
      onTap: onTap,
    );
  }
}

class _PostStatusPill extends StatelessWidget {
  const _PostStatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (String label, Color fg, Color bg) = switch (status) {
      'OPEN' => (
          AppStrings.postStatusOpen,
          AppColors.accent,
          AppColors.accentSoft,
        ),
      'PENDING_PAYMENT' => (
          AppStrings.statusAwaitingPayment,
          const Color(0xFF92400E),
          const Color(0xFFFEF3C7),
        ),
      'MATCHED' => (
          AppStrings.postStatusMatched,
          const Color(0xFF1D4ED8),
          const Color(0xFFDBEAFE),
        ),
      'COMPLETED' => (
          AppStrings.statusCompleted,
          AppColors.textSecondary,
          AppColors.surface,
        ),
      _ => (
          AppStrings.statusCancelled,
          AppColors.textSecondary,
          AppColors.surface,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
