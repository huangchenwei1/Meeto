import 'dart:async';

import '../../../core/constants/scene_images.dart';
import '../../../core/constants/scene_pricing.dart';
import '../../../core/session/auth_session.dart';
import '../../orders/data/orders_repository.dart';
import '../models/activity_post.dart';
import '../models/activity_template.dart';
import '../models/post_author.dart';

/// Input payload for publishing a new activity request. Only a fuzzy time
/// window and a rough district: the selected host still proposes the
/// concrete plan (exact time and venue) on the order after matching.
class CreatePostInput {
  const CreatePostInput({
    required this.sceneTag,
    required this.title,
    required this.description,
    this.timeSlot = '',
    this.area = '',
    this.imageUrl = '',
    this.budget = 0,
  });

  final String sceneTag;
  final String title;
  final String description;
  final String timeSlot;
  final String area;

  /// Activity budget tier pick (whole pesos); 0 -> the platform default
  /// (middle) tier for the scene.
  final int budget;

  /// Cover photo; template launches pass the template cover.
  final String imageUrl;
}

/// Data source contract for community activity posts.
///
/// Pages depend on this abstraction only. To go live, implement it with a
/// real API client (e.g. `ApiCommunityRepository`) and swap the instance
/// injected in the page — no UI change required.
abstract interface class CommunityRepository {
  /// Community wall: sharing posts (moments) only. Demand posts live on
  /// the host gig hall ([fetchOpenRequests]) and in the author's own view.
  Future<List<ActivityPost>> fetchMoments();

  /// Host gig hall: OPEN activity requests hosts can still pitch on.
  Future<List<ActivityPost>> fetchOpenRequests();

  /// Still-open demand posts the caller signed up for and is waiting on;
  /// feeds the host's side of the My Activities board.
  Future<List<ActivityPost>> fetchAppliedRequests();

  /// Returns all posts published by [authorId] (any status), used by the
  /// author's own management view.
  Future<List<ActivityPost>> fetchPostsByAuthor(String authorId);

  /// Returns one post by id (any status), e.g. when opened from a
  /// notification.
  Future<ActivityPost> fetchPostById(String postId);

  /// Returns available scene names, excluding the implicit "For you".
  Future<List<String>> fetchScenes();

  /// The curated "hot activities" shelf; picking one prefills the publish
  /// flow for either role.
  Future<List<ActivityTemplate>> fetchTemplates();

  /// Publishes a new post and returns it. The match fee is platform-set
  /// per scene ([ScenePricing]); posters cannot price.
  Future<ActivityPost> createPost(CreatePostInput input);

  /// Author-only delete; allowed while the post is still open (no order).
  Future<void> deletePost(String postId);

  /// Signs the current user up as a CANDIDATE for [postId] (free).
  /// [proposal] is the required one-line plan pitch shown to the poster.
  /// Returns the updated post. The poster still has to pick one candidate.
  /// Signs up as a candidate with the pitch plus the plan card (place +
  /// time): selecting the candidate approves this plan.
  Future<ActivityPost> signUp(
    String postId,
    String proposal, {
    required String place,
    required DateTime scheduledAt,
    required int durationMinutes,
  });

  /// Publishes a community recap (photos + text). Open to both roles.
  Future<ActivityPost> createMoment(
    String text,
    List<String> images,
    String venue,
  );

  /// Emits the current candidate pool of the caller's own post, then again
  /// whenever it changes. In production this arrives via server push.
  Stream<List<PostAuthor>> watchCandidates(String postId);

  /// The poster approves one candidate; returns that candidate. Payment and
  /// order creation happen next (server-side in production).
  Future<PostAuthor> selectCandidate(String postId, String candidateId);
}

/// In-memory mock used for the demo build.
class MockCommunityRepository implements CommunityRepository {
  MockCommunityRepository({this.orders}) {
    _posts.addAll(_seedPosts());
  }

  /// When present, approving a candidate also creates the local demo order
  /// (mirrors the server, where selection creates the escrow order).
  final MockOrdersRepository? orders;

  static const List<String> _scenes = <String>[
    'Coffee',
    'Dinner',
    'Bar',
    'Movie',
    'Tea',
  ];

  // Reads the live session so it reflects whoever actually signed in.
  static PostAuthor get currentUserAuthor => PostAuthor(
        id: AuthSession.currentUserId,
        name: AuthSession.currentUserName,
        avatarUrl: AuthSession.currentUserAvatarUrl,
        meta: AuthSession.currentUserMeta,
        isVerified: true,
      );

  // Demo cast mirroring server/prisma/seed.mjs: USER accounts post
  // activity requests, HOST accounts apply to run them.
  static const PostAuthor _andrea = PostAuthor(
    id: 'user-100',
    name: 'Andrea',
    avatarUrl: 'https://i.pravatar.cc/150?img=47',
    meta: 'Female \u00b7 24',
    isVerified: true,
  );
  static const PostAuthor _miguel = PostAuthor(
    id: 'user-101',
    name: 'Miguel',
    avatarUrl: 'https://i.pravatar.cc/150?img=11',
    meta: 'Male \u00b7 27',
    isVerified: true,
  );
  static const PostAuthor _paolo = PostAuthor(
    id: 'user-102',
    name: 'Paolo',
    avatarUrl: 'https://i.pravatar.cc/150?img=59',
    meta: 'Male \u00b7 29',
    isVerified: true,
  );
  static const PostAuthor _marco = PostAuthor(
    id: 'user-103',
    name: 'Marco',
    avatarUrl: 'https://i.pravatar.cc/150?img=12',
    meta: 'Male \u00b7 28',
    isVerified: true,
  );

  /// Demo host shown as attribution on the seeded in-progress activity.
  static const PostAuthor _liza = PostAuthor(
    id: 'host-203',
    name: 'Liza',
    avatarUrl: 'https://i.pravatar.cc/150?img=25',
    meta: 'Female \u00b7 25',
    isVerified: true,
  );

  /// Simulated host candidates who pitch on the current user's new posts
  /// (same hosts as app-001/app-002-style applications in the server seed).
  static final List<PostAuthor> _demoCandidates = <PostAuthor>[
    PostAuthor(
      id: 'host-204',
      name: 'James',
      avatarUrl: 'https://i.pravatar.cc/150?img=13',
      meta: 'Male \u00b7 28',
      isVerified: true,
      proposal: 'Single Origin in Salcedo, Saturday 3pm \u2014 quiet '
          'upstairs seats and the best hand brew flight in Makati',
      planPlace: 'Single Origin, Salcedo Village',
      planAt: DateTime.now().add(const Duration(days: 3)),
      planDurationMinutes: 180,
    ),
    PostAuthor(
      id: 'host-205',
      name: 'Noel',
      avatarUrl: 'https://i.pravatar.cc/150?img=53',
      meta: 'Male \u00b7 30',
      isVerified: true,
      proposal: 'Rooftop bar in Poblacion that stays quiet on Fridays, '
          'then the best whiskey list in the block',
      planPlace: 'Apotheka, Poblacion',
      planAt: DateTime.now().add(const Duration(days: 4)),
      planDurationMinutes: 240,
    ),
  ];

  final List<ActivityPost> _posts = <ActivityPost>[];
  final Map<String, List<PostAuthor>> _candidates =
      <String, List<PostAuthor>>{};
  final Map<String, StreamController<List<PostAuthor>>>
      _candidateControllers = <String, StreamController<List<PostAuthor>>>{};
  int _postSequence = 100;

  // Same scripts as server/prisma/seed.mjs: loose activity intents from
  // the USER side; the selected host proposes the concrete plan.
  static List<ActivityPost> _seedPosts() {
    final DateTime now = DateTime.now();
    return <ActivityPost>[
      ActivityPost(
        id: 'post-001',
        sceneTag: 'Coffee',
        timeSlot: 'WEEKEND',
        area: 'Makati',
        title: 'Show me a cafe worth leaving BGC for',
        description: 'Want a relaxed coffee afternoon, you pick the place',
        detail:
            'I have been in Manila three months and only know the chain '
            'cafes near my office. Looking for a host who knows the '
            'specialty coffee scene and can plan a relaxed afternoon: the '
            'place, the order, the conversation. Time is flexible this week.',
        signedCount: 2,
        applicantAvatars: const <String>[
          'https://i.pravatar.cc/150?img=11',
          'https://i.pravatar.cc/150?img=59',
        ],
        applicantPreviews: const <ApplicantPreview>[
          ApplicantPreview(
            avatarUrl: 'https://i.pravatar.cc/150?img=11',
            proposalTeaser: '从黎黄陂路的咖啡开场，再带你\u2026',
          ),
          ApplicantPreview(
            avatarUrl: 'https://i.pravatar.cc/150?img=59',
            proposalTeaser: '江滩夜景走起，我熟三家小店\u2026',
          ),
        ],
        imageUrl: SceneImages.forScene('Coffee'),
        author: _miguel,
        createdAt: now.subtract(const Duration(hours: 1)),
        budgetAmount: 1500,
      ),
      ActivityPost(
        id: 'post-002',
        sceneTag: 'Dinner',
        timeSlot: 'TONIGHT',
        area: 'BGC',
        title: 'Plan me a Japanese dinner I cannot find on my own',
        description: 'Good sushi, good conversation, you handle the plan',
        detail:
            'I eat out a lot but keep going back to the same two places. '
            'Want a host who can plan a proper Japanese dinner \u2014 '
            'somewhere I would never find alone. Weeknights after 7 work '
            'best. Meal is on me.',
        signedCount: 1,
        imageUrl: SceneImages.forScene('Dinner'),
        author: _paolo,
        createdAt: now.subtract(const Duration(hours: 3)),
        budgetAmount: 4000,
      ),
      ActivityPost(
        // In progress: Liza's plan is selected, mirroring the seeded
        // ACTIVE escrow order on the server.
        id: 'post-003',
        sceneTag: 'Movie',
        timeSlot: 'WEEKEND',
        area: 'Ortigas',
        title: 'Movie night with an actual plan',
        description: 'Pick the film, the cinema and the after-talk spot',
        detail:
            'I love movies but hate deciding. Looking for a host to plan '
            'the whole evening: which film, which cinema, and where we talk '
            'about it after. Saturday afternoon preferred. Tickets and '
            'snacks on me.',
        signedCount: 1,
        imageUrl: SceneImages.forScene('Movie'),
        author: _marco,
        createdAt: now.subtract(const Duration(hours: 24)),
        budgetAmount: 2500,
        status: 'MATCHED',
        selectedHost: _liza,
      ),
      ActivityPost(
        id: 'post-004',
        sceneTag: 'Tea',
        timeSlot: 'TODAY_AFTERNOON',
        area: 'Salcedo Village',
        title: 'Slow Sunday: dessert cafe and no agenda',
        description: 'Need someone to plan a lazy tea afternoon',
        detail:
            'Work ate my whole month. I want one slow Sunday afternoon: '
            'good fruit tea, good cake, zero decisions made by me. Host '
            'plans everything, I just show up. Desserts are on me.',
        signedCount: 0,
        imageUrl: SceneImages.forScene('Tea'),
        author: _andrea,
        createdAt: now.subtract(const Duration(hours: 48)),
        budgetAmount: 1800,
      ),
      ActivityPost(
        id: 'moment-001',
        type: 'MOMENT',
        sceneTag: '',
        title: 'Bianca took me to a cafe hidden inside a bookshop. Best '
            'Sunday in months \u2014 I did not make a single decision all '
            'afternoon.',
        description: 'Bianca took me to a cafe hidden inside a bookshop. '
            'Best Sunday in months \u2014 I did not make a single decision '
            'all afternoon.',
        detail: '',
        signedCount: 0,
        imageUrl:
            'https://images.unsplash.com/photo-1554118811-1e0d58224f24?auto=format&fit=crop&w=800&h=800&q=80',
        images: <String>[
          'https://images.unsplash.com/photo-1554118811-1e0d58224f24?auto=format&fit=crop&w=800&h=800&q=80',
          'https://images.unsplash.com/photo-1481833761820-0509d3217039?auto=format&fit=crop&w=800&h=800&q=80',
        ],
        venue: 'Hidden cafe at Solidaridad Bookshop, Legazpi Village',
        author: _andrea,
        createdAt: now.subtract(const Duration(hours: 6)),
        budgetAmount: 0,
      ),
      ActivityPost(
        id: 'moment-002',
        type: 'MOMENT',
        sceneTag: '',
        title: 'Kat planned a dinner at a 12-seat omakase counter I never '
            'knew existed. Worth every peso of the service fee.',
        description: 'Kat planned a dinner at a 12-seat omakase counter I '
            'never knew existed. Worth every peso of the service fee.',
        detail: '',
        signedCount: 0,
        imageUrl:
            'https://images.unsplash.com/photo-1553621042-f6e147245754?auto=format&fit=crop&w=800&h=800&q=80',
        images: <String>[
          'https://images.unsplash.com/photo-1553621042-f6e147245754?auto=format&fit=crop&w=800&h=800&q=80',
        ],
        venue: 'Tsukiji omakase counter, Little Tokyo',
        author: _paolo,
        createdAt: now.subtract(const Duration(hours: 12)),
        budgetAmount: 0,
      ),
    ];
  }

  @override
  Future<List<ActivityPost>> fetchMoments() async {
    // Simulated network latency so loading states stay testable.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return _posts.where((ActivityPost post) => post.isMoment).toList()
      ..sort(
        (ActivityPost a, ActivityPost b) => b.createdAt.compareTo(a.createdAt),
      );
  }

  @override
  Future<List<ActivityPost>> fetchOpenRequests() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    // Mirrors the server's role isolation: hosts see every request (their
    // work queue); users see only their own.
    return _posts
        .where(
          (ActivityPost post) =>
              !post.isMoment &&
              post.status != 'CANCELLED' &&
              (AuthSession.isHost ||
                  post.author.id == AuthSession.currentUserId),
        )
        .toList()
      ..sort(
        (ActivityPost a, ActivityPost b) => b.createdAt.compareTo(a.createdAt),
      );
  }

  @override
  Future<List<ActivityPost>> fetchAppliedRequests() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return _posts
        .where(
          (ActivityPost post) =>
              !post.isMoment && post.status == 'OPEN' && post.hasApplied,
        )
        .toList();
  }

  @override
  Future<List<ActivityPost>> fetchPostsByAuthor(String authorId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return _posts
        .where((ActivityPost post) => post.author.id == authorId)
        .toList();
  }

  @override
  Future<ActivityPost> fetchPostById(String postId) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return _posts.firstWhere((ActivityPost post) => post.id == postId);
  }

  @override
  Future<List<String>> fetchScenes() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return _scenes;
  }

  // Mirrors server/src/posts/activity-templates.ts: a hand-picked Wuhan
  // list standing in for the future ops console.
  static const List<ActivityTemplate> _templates = <ActivityTemplate>[
    ActivityTemplate(
      id: 'template-lihuangpi-road-coffee',
      sceneTag: 'Coffee',
      title: '黎黄陂路街角咖啡散步',
      description: '老租界的红砖路，一杯手冲边走边喝，武汉最松弛的两小时',
      imageUrl:
          'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=800&h=800&q=80',
      durationLabel: '约 2 小时',
      venueLabel: '街区漫步',
      area: '黎黄陂路',
    ),
    ActivityTemplate(
      id: 'template-tanhualin-bookshop-cafe',
      sceneTag: 'Coffee',
      title: '昙华林书店里的隐藏咖啡馆',
      description: '藏在书架后面的吧台，豆子好，人少安静',
      imageUrl:
          'https://images.unsplash.com/photo-1481833761820-0509d3217039?auto=format&fit=crop&w=800&h=800&q=80',
      durationLabel: '约 1.5 小时',
      venueLabel: '咖啡馆',
      area: '昙华林',
    ),
    ActivityTemplate(
      id: 'template-wansongyuan-crayfish-dinner',
      sceneTag: 'Dinner',
      title: '万松园油焖大虾宵夜局',
      description: '老牌虾店加生烫牛肉，一个人不敢点满桌，两个人刚好',
      imageUrl:
          'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?auto=format&fit=crop&w=800&h=800&q=80',
      durationLabel: '约 2 小时',
      venueLabel: '大排档',
      area: '万松园',
    ),
    ActivityTemplate(
      id: 'template-jianghan-road-omakase',
      sceneTag: 'Dinner',
      title: '江汉路板前日料',
      description: '12 座的板前，当天最新鲜的交给主厨安排',
      imageUrl:
          'https://images.unsplash.com/photo-1553621042-f6e147245754?auto=format&fit=crop&w=800&h=800&q=80',
      durationLabel: '约 2 小时',
      venueLabel: '日料店',
      area: '江汉路',
    ),
    ActivityTemplate(
      id: 'template-jiangtan-riverside-bars',
      sceneTag: 'Bar',
      title: '江滩夜景酒吧巡礼',
      description: '从精酿到调酒，三家风格不同的小店，看着长江微醺收尾',
      imageUrl:
          'https://images.unsplash.com/photo-1514362545857-3bc16c4c7d1b?auto=format&fit=crop&w=800&h=800&q=80',
      durationLabel: '约 3 小时',
      venueLabel: '酒吧',
      area: '汉口江滩',
    ),
    ActivityTemplate(
      id: 'template-chuhehanjie-movie-dessert',
      sceneTag: 'Movie',
      title: '楚河汉街影院夜 + 散场甜品',
      description: '新片加散场后的甜品店复盘，不用自己做任何决定',
      imageUrl:
          'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?auto=format&fit=crop&w=800&h=800&q=80',
      durationLabel: '约 3 小时',
      venueLabel: '影院',
      area: '楚河汉街',
    ),
    ActivityTemplate(
      id: 'template-donghu-lakeside-tea',
      sceneTag: 'Tea',
      title: '东湖边的下午茶',
      description: '听涛绿道走一圈，末站是湖边安静的茶室',
      imageUrl:
          'https://images.unsplash.com/photo-1544787219-7f47ccb76574?auto=format&fit=crop&w=800&h=800&q=80',
      durationLabel: '约 2.5 小时',
      venueLabel: '茶室',
      area: '东湖',
    ),
  ];

  @override
  Future<List<ActivityTemplate>> fetchTemplates() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return _templates;
  }

  @override
  Future<ActivityPost> createPost(CreatePostInput input) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final ActivityPost post = ActivityPost(
      id: 'post-${++_postSequence}',
      sceneTag: input.sceneTag,
      title: input.title,
      description: input.description,
      detail: input.description,
      timeSlot: input.timeSlot,
      area: input.area,
      signedCount: 0,
      imageUrl: input.imageUrl.isNotEmpty
          ? input.imageUrl
          : SceneImages.forScene(input.sceneTag),
      author: currentUserAuthor,
      createdAt: DateTime.now(),
      budgetAmount: input.budget > 0
          ? input.budget
          : ScenePricing.defaultBudgetForScene(input.sceneTag),
    );
    _posts.insert(0, post);
    _scheduleDemoCandidates(post.id);
    return post;
  }

  @override
  Future<void> deletePost(String postId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _posts.removeWhere((ActivityPost post) => post.id == postId);
  }

  @override
  Future<ActivityPost> createMoment(
    String text,
    List<String> images,
    String venue,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    // Mock mode has no upload endpoint, but the wall's cards are
    // image-led, so stand in with a scene placeholder cover.
    final List<String> covers =
        images.isEmpty ? <String>[SceneImages.forScene('')] : images;
    final ActivityPost post = ActivityPost(
      id: 'post-${++_postSequence}',
      type: 'MOMENT',
      sceneTag: '',
      title: text,
      description: text,
      detail: text,
      venue: venue,
      signedCount: 0,
      imageUrl: covers.first,
      images: covers,
      author: currentUserAuthor,
      createdAt: DateTime.now(),
      budgetAmount: 0,
    );
    _posts.insert(0, post);
    return post;
  }

  @override
  Future<ActivityPost> signUp(
    String postId,
    String proposal, {
    required String place,
    required DateTime scheduledAt,
    required int durationMinutes,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final int index = _posts.indexWhere((ActivityPost p) => p.id == postId);
    final ActivityPost updated = _posts[index].copyWith(
      signedCount: _posts[index].signedCount + 1,
      hasApplied: true,
    );
    _posts[index] = updated;
    return updated;
  }

  @override
  Stream<List<PostAuthor>> watchCandidates(String postId) {
    final StreamController<List<PostAuthor>> controller =
        _candidateControllerFor(postId);
    return Stream<List<PostAuthor>>.multi(
        (StreamController<List<PostAuthor>> emitter) {
      emitter.add(_candidatesOf(postId));
      final StreamSubscription<List<PostAuthor>> sub =
          controller.stream.listen(emitter.add);
      emitter.onCancel = sub.cancel;
    });
  }

  @override
  Future<PostAuthor> selectCandidate(String postId, String candidateId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final PostAuthor candidate = _candidatesOf(postId)
        .firstWhere((PostAuthor c) => c.id == candidateId);
    // The match consumes the slot; remaining candidates are released. The
    // post becomes an in-progress activity attributed to the chosen host.
    _candidates[postId] = <PostAuthor>[candidate];
    final int index = _posts.indexWhere((ActivityPost p) => p.id == postId);
    _posts[index] = _posts[index].copyWith(
      signedCount: 1,
      status: 'MATCHED',
      selectedHost: candidate,
    );
    // Selection creates the escrow order, exactly like the server does.
    orders?.seedFromSelection(_posts[index], candidate);
    _emitCandidates(postId);
    return candidate;
  }

  // DEMO NOTE: fakes men applying to the current user's post shortly after
  // it is published. In production candidates arrive via server push.
  void _scheduleDemoCandidates(String postId) {
    Timer(const Duration(milliseconds: 1200), () {
      _addCandidate(postId, _demoCandidates[0]);
    });
    Timer(const Duration(milliseconds: 2600), () {
      _addCandidate(postId, _demoCandidates[1]);
    });
  }

  void _addCandidate(String postId, PostAuthor candidate) {
    final List<PostAuthor> pool = _candidates.putIfAbsent(
      postId,
      () => <PostAuthor>[],
    );
    if (pool.any((PostAuthor c) => c.id == candidate.id)) {
      return;
    }
    pool.add(candidate);
    final int index = _posts.indexWhere((ActivityPost p) => p.id == postId);
    if (index >= 0) {
      _posts[index] = _posts[index].copyWith(signedCount: pool.length);
    }
    _emitCandidates(postId);
  }

  List<PostAuthor> _candidatesOf(String postId) =>
      List<PostAuthor>.unmodifiable(
          _candidates[postId] ?? const <PostAuthor>[]);

  StreamController<List<PostAuthor>> _candidateControllerFor(String postId) {
    return _candidateControllers.putIfAbsent(
      postId,
      () => StreamController<List<PostAuthor>>.broadcast(),
    );
  }

  void _emitCandidates(String postId) {
    _candidateControllerFor(postId).add(_candidatesOf(postId));
  }
}
