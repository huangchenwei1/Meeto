import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/session/auth_session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../hosts/data/hosts_repository.dart';
import '../../hosts/pages/proposal_composer_page.dart';
import '../../profile/data/profile_repository.dart';
import '../data/community_repository.dart';
import '../models/activity_template.dart';
import 'feed_page.dart';
import 'publish_page.dart';

/// Tab 1, identical for both roles: the activity community. "Hot
/// activities" is the curated template shelf — picking one prefills the
/// publish flow (users post a request, hosts post a pitch), so posting is
/// "choose and confirm" instead of composing from scratch. "Activity
/// shares" is the sharing wall (moments). Everything published here lands
/// on the dating hall (tab 2).
class ActivityCommunityPage extends StatefulWidget {
  const ActivityCommunityPage({
    super.key,
    required this.communityRepository,
    required this.profileRepository,
    required this.hostsRepository,
    this.onPosted,
  });

  final CommunityRepository communityRepository;
  final ProfileRepository profileRepository;
  final HostsRepository hostsRepository;

  /// Called after a successful launch so the shell can refresh the hall.
  final VoidCallback? onPosted;

  @override
  State<ActivityCommunityPage> createState() => ActivityCommunityPageState();
}

class ActivityCommunityPageState extends State<ActivityCommunityPage> {
  final GlobalKey<FeedPageState> _feedKey = GlobalKey<FeedPageState>();

  List<ActivityTemplate> _templates = <ActivityTemplate>[];
  bool _loading = true;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final List<ActivityTemplate> templates =
          await widget.communityRepository.fetchTemplates();
      if (mounted) {
        setState(() {
          _templates = templates;
          _loading = false;
        });
      }
    } on Exception {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// Called by the shell when the tab comes back into view.
  void reload() {
    _load();
    _feedKey.currentState?.reload();
  }

  /// Launching from a template prefills the role-appropriate composer:
  /// users publish an activity request, hosts publish a pitch.
  Future<void> _launch(ActivityTemplate template) async {
    final bool? posted;
    if (AuthSession.isHost) {
      posted = await Navigator.of(context).push(
        MaterialPageRoute<bool>(
          fullscreenDialog: true,
          builder: (_) => ProposalComposerPage(
            repository: widget.hostsRepository,
            template: template,
          ),
        ),
      );
    } else {
      posted = await Navigator.of(context).push(
        MaterialPageRoute<bool>(
          fullscreenDialog: true,
          builder: (_) => PublishPage(
            repository: widget.communityRepository,
            template: template,
          ),
        ),
      );
    }
    if ((posted ?? false) && mounted) {
      widget.onPosted?.call();
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
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
              child: Row(
                children: <Widget>[
                  _HeaderTab(
                    key: const ValueKey<String>('communityTabTemplates'),
                    label: AppStrings.hotActivitiesTab,
                    selected: _tab == 0,
                    onTap: () => setState(() => _tab = 0),
                  ),
                  const SizedBox(width: 16),
                  _HeaderTab(
                    key: const ValueKey<String>('communityTabShares'),
                    label: AppStrings.activitySharesTab,
                    selected: _tab == 1,
                    onTap: () => setState(() => _tab = 1),
                  ),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: <Widget>[
                  _loading
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: _templates.isEmpty
                              ? ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  children: const <Widget>[
                                    Padding(
                                      padding: EdgeInsets.only(top: 120),
                                      child: Center(
                                        child: Text(
                                          AppStrings.templatesEmpty,
                                          style: TextStyle(
                                            color: AppColors.textHint,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.separated(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    6,
                                    16,
                                    24,
                                  ),
                                  itemCount: _templates.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 14),
                                  itemBuilder:
                                      (BuildContext context, int index) {
                                    final ActivityTemplate template =
                                        _templates[index];
                                    return _TemplateCard(
                                      template: template,
                                      onLaunch: () => _launch(template),
                                    );
                                  },
                                ),
                        ),
                  FeedPage(
                    key: _feedKey,
                    communityRepository: widget.communityRepository,
                    profileRepository: widget.profileRepository,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderTab extends StatelessWidget {
  const _HeaderTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: selected ? AppColors.textPrimary : AppColors.textHint,
        ),
      ),
    );
  }
}

/// One curated activity on the shelf: cover left; scene chip, title,
/// pitch line, duration + venue type, and the budget-from + launch pill
/// right. The budget is the platform scene fee.
class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template, required this.onLaunch});

  final ActivityTemplate template;
  final VoidCallback onLaunch;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        color: Colors.white,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (template.imageUrl.isNotEmpty)
                SizedBox(
                  width: 110,
                  child: AppNetworkImage(url: template.imageUrl),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentSoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          AppStrings.sceneLabel(template.sceneTag),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        template.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        template.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (template.metaLine.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            const Icon(
                              Iconsax.clock,
                              size: 13,
                              color: AppColors.textHint,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                template.metaLine,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      // No money on the shelf: the budget tiers show up in
                      // the composer after launching.
                      Row(
                        children: <Widget>[
                          const Spacer(),
                          InkWell(
                            key: ValueKey<String>(
                              'templateLaunch${template.id}',
                            ),
                            onTap: onLaunch,
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.darkCard,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                AppStrings.templateLaunchCta,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onDarkPrimary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
