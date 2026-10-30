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

/// One host, in three clean layers: identity (avatar, name, hosting
/// record badge), a two-line bio, and the scenes they can host, with the
/// price-list entry as the card's single call to action. Deliberately
/// activity-led: no photo walls, no raw pitch quotes.
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
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                AppAvatar(size: 48, imageUrl: host.avatarUrl),
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
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _RecordBadge(count: host.completedActivities),
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
            if (host.tags.isNotEmpty) ...<Widget>[
              const SizedBox(height: 11),
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
            const SizedBox(height: 9),
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

/// Hosting record as a compact badge: the one trust signal on the card.
class _RecordBadge extends StatelessWidget {
  const _RecordBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final bool proven = count > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: proven ? AppColors.accentSoft : AppColors.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        proven ? AppStrings.hostHostedBadge(count) : AppStrings.hostNewLabel,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: proven ? AppColors.accent : AppColors.textSecondary,
        ),
      ),
    );
  }
}
