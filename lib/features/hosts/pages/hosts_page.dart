import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/guidelines_banner.dart';
import '../../community/data/community_repository.dart';
import '../../community/pages/publish_page.dart';
import '../data/hosts_repository.dart';
import '../models/host_card.dart';
import 'host_detail_page.dart';

/// Host directory (user side, first tab). Deliberately activity-led:
/// hosting record and plan pitches headline each card, not photos. Also
/// carries the "post a request" entry — the other way to get hosted when
/// no listed host fits.
class HostsPage extends StatefulWidget {
  const HostsPage({
    super.key,
    required this.repository,
    required this.communityRepository,
  });

  final HostsRepository repository;
  final CommunityRepository communityRepository;

  @override
  State<HostsPage> createState() => HostsPageState();
}

class HostsPageState extends State<HostsPage> {
  List<HostCard> _hosts = <HostCard>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    try {
      final List<HostCard> hosts = await widget.repository.fetchHosts();
      if (mounted) {
        setState(() {
          _hosts = hosts;
          _loading = false;
        });
      }
    } on Exception {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
              child: Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      AppStrings.hostsTitle,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  // Post-a-request entry, kept as a quiet icon so the
                  // host list stays the hero of the page.
                  InkWell(
                    key: const ValueKey<String>('postRequestButton'),
                    onTap: _openPublish,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: AppColors.darkCard,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Iconsax.add,
                        size: 20,
                        color: AppColors.onDarkPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _hosts.isEmpty
                      ? const Center(
                          child: Text(
                            AppStrings.hostsEmpty,
                            style: TextStyle(color: AppColors.textHint),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: reload,
                          child: ListView.separated(
                            padding:
                                const EdgeInsets.fromLTRB(16, 10, 16, 24),
                            // +1: the shared guidelines banner leads the
                            // list, same as on the community tab.
                            itemCount: _hosts.length + 1,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (BuildContext context, int index) {
                              if (index == 0) {
                                return const GuidelinesBanner();
                              }
                              final HostCard host = _hosts[index - 1];
                              return _HostTile(
                                host: host,
                                onTap: () => _openHost(host),
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

  Future<void> _openHost(HostCard host) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HostDetailPage(
          repository: widget.repository,
          hostId: host.id,
          initial: host,
        ),
      ),
    );
    reload();
  }

  /// The complementary path to direct invitations: post a request and let
  /// hosts pitch their plans (tracked afterwards in My Posts).
  Future<void> _openPublish() async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => PublishPage(repository: widget.communityRepository),
      ),
    );
  }
}

/// One host, identity-first like a contact card: a three-line header
/// (name + verified mark, demographics, hosting record as the accent
/// stat) with an invite pill on the trailing edge, a short bio, then the
/// scenes they can host. The whole card opens the detail page, where the
/// invite is actually priced per scene. Deliberately activity-led: no
/// photo walls, no raw pitch quotes, and no made-up stats — only fields
/// we actually have.
class _HostTile extends StatelessWidget {
  const _HostTile({required this.host, required this.onTap});

  final HostCard host;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                AppAvatar(size: 56, imageUrl: host.avatarUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              host.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (host.isVerified) ...<Widget>[
                            const SizedBox(width: 6),
                            const Icon(
                              Iconsax.verify5,
                              size: 14,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: 3),
                            const Text(
                              AppStrings.verifiedLabel,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        host.city.isEmpty
                            ? host.meta
                            : '${host.meta} \u00b7 ${host.city}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textHint,
                        ),
                      ),
                      const SizedBox(height: 3),
                      // Hosting record as the accent stat: the one trust
                      // signal we can actually back with data.
                      Text(
                        host.completedActivities > 0
                            ? AppStrings.hostCompletedLabel(
                                host.completedActivities,
                              )
                            : AppStrings.hostNewLabel,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Invite entry: lands on the detail page where the
                // scene price list turns the intent into an order.
                InkWell(
                  key: ValueKey<String>('inviteHost${host.id}'),
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.darkCard,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      AppStrings.hostInviteCta,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onDarkPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (host.bio.isNotEmpty) ...<Widget>[
              const SizedBox(height: 11),
              Text(
                host.bio,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            // The scenes this host offers (picked at registration) — the
            // same list the detail page prices up. Never interest tags.
            if (host.hostScenes.isNotEmpty) ...<Widget>[
              const SizedBox(height: 11),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: host.hostScenes
                    .take(4)
                    .map(
                      (String scene) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4.5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          AppStrings.sceneLabel(scene),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
