import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_avatar.dart';
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          AppStrings.hostsTitle,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          AppStrings.hostsSubtitle,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    key: const ValueKey<String>('postRequestButton'),
                    onTap: _openPublish,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.darkCard,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const <Widget>[
                          Icon(
                            Iconsax.calendar_add,
                            size: 15,
                            color: AppColors.onDarkPrimary,
                          ),
                          SizedBox(width: 6),
                          Text(
                            AppStrings.hostsPostRequestCta,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onDarkPrimary,
                            ),
                          ),
                        ],
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
                            itemCount: _hosts.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (BuildContext context, int index) {
                              return _HostTile(
                                host: _hosts[index],
                                onTap: () => _openHost(_hosts[index]),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AppAvatar(size: 52, imageUrl: host.avatarUrl),
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
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (host.isVerified) ...<Widget>[
                            const SizedBox(width: 5),
                            const Icon(
                              Iconsax.verify5,
                              size: 15,
                              color: AppColors.accent,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        host.city.isEmpty
                            ? host.meta
                            : '${host.meta} \u00b7 ${host.city}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textHint,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Hosting record as the headline stat (activity-led,
                      // never a photo/price catalog).
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
              ],
            ),
            if (host.bio.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
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
            if (host.recentProposals.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(
                    Iconsax.map_1,
                    size: 14,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      host.recentProposals.first,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (host.tags.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: host.tags
                    .take(4)
                    .map(
                      (String tag) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            // Entry to the host's activity price list on the detail page.
            Row(
              children: const <Widget>[
                Expanded(
                  child: Text(
                    AppStrings.hostSeeActivities,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                Icon(
                  Iconsax.arrow_right_3,
                  size: 15,
                  color: AppColors.accent,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
