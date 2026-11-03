import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../data/hosts_repository.dart';
import '../models/host_card.dart';

/// Host profile, read-only. The product trades concrete activities, not
/// people: invitations start from a pitch on the wall (price locked
/// there), never from the profile.
class HostDetailPage extends StatefulWidget {
  const HostDetailPage({
    super.key,
    required this.repository,
    required this.hostId,
    this.initial,
  });

  final HostsRepository repository;
  final String hostId;
  final HostCard? initial;

  @override
  State<HostDetailPage> createState() => _HostDetailPageState();
}

class _HostDetailPageState extends State<HostDetailPage> {
  HostCard? _host;

  @override
  void initState() {
    super.initState();
    _host = widget.initial;
    _load();
  }

  Future<void> _load() async {
    try {
      final HostCard host = await widget.repository.fetchHost(widget.hostId);
      if (mounted) {
        setState(() => _host = host);
      }
    } on Exception {
      // Keep the initial card if the refresh fails.
    }
  }

  @override
  Widget build(BuildContext context) {
    final HostCard? host = _host;
    if (host == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: <Widget>[
          Row(
            children: <Widget>[
              AppAvatar(size: 72, imageUrl: host.avatarUrl),
              const SizedBox(width: 16),
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
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (host.isVerified) ...<Widget>[
                          const SizedBox(width: 6),
                          const Icon(
                            Iconsax.verify5,
                            size: 18,
                            color: AppColors.accent,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      host.city.isEmpty
                          ? host.meta
                          : '${host.meta} \u00b7 ${host.city}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      host.completedActivities > 0
                          ? AppStrings.hostCompletedLabel(
                              host.completedActivities,
                            )
                          : AppStrings.hostNewLabel,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (host.bio.isNotEmpty) ...<Widget>[
            const SizedBox(height: 18),
            Text(
              host.bio,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textPrimary,
              ),
            ),
          ],
          if (host.tags.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: host.tags
                  .map(
                    (String tag) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          if (host.recentProposals.isNotEmpty) ...<Widget>[
            const SizedBox(height: 20),
            const Text(
              AppStrings.hostRecentPlanLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            for (final String proposal in host.recentProposals)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '\u201c$proposal\u201d',
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
