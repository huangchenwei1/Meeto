import 'dart:async';

import '../../../core/constants/scene_pricing.dart';
import '../../../core/session/auth_session.dart';
import '../../orders/data/orders_repository.dart';
import '../models/activity_post.dart';
import '../models/post_author.dart';

/// Input payload for publishing a new activity request.
class CreatePostInput {
  const CreatePostInput({
    required this.sceneTag,
    required this.title,
    required this.description,
    required this.timeText,
    required this.place,
    this.scheduledAt,
    this.placeLat,
    this.placeLng,
  });

  final String sceneTag;
  final String title;
  final String description;
  final String timeText;
  final String place;

  /// Structured schedule and venue (optional; timeText/place stay the
  /// human-readable display strings).
  final DateTime? scheduledAt;
  final double? placeLat;
  final double? placeLng;
}

/// Data source contract for community activity posts.
///
/// Pages depend on this abstraction only. To go live, implement it with a
/// real API client (e.g. `ApiCommunityRepository`) and swap the instance
/// injected in the page — no UI change required.
abstract interface class CommunityRepository {
  /// Returns community wall posts (waiting + in-progress + moments),
  /// optionally filtered by [sceneTag].
  Future<List<ActivityPost>> fetchPosts({String? sceneTag});

  /// Returns all posts published by [authorId] (any status), used by the
  /// author's own management view.
  Future<List<ActivityPost>> fetchPostsByAuthor(String authorId);

  /// Returns one post by id (any status), e.g. when opened from a
  /// notification.
  Future<ActivityPost> fetchPostById(String postId);

  /// Returns available scene names, excluding the implicit "For you".
  Future<List<String>> fetchScenes();

  /// Publishes a new post and returns it. The match fee is platform-set
  /// per scene ([ScenePricing]); posters cannot price.
  Future<ActivityPost> createPost(CreatePostInput input);

  /// Author-only delete; allowed while the post is still open (no order).
  Future<void> deletePost(String postId);

  /// Signs the current user up as a CANDIDATE for [postId] (free).
  /// [proposal] is the required one-line plan pitch shown to the poster.
  /// Returns the updated post. The poster still has to pick one candidate.
  Future<ActivityPost> signUp(String postId, String proposal);

  /// Publishes a community recap (photos + text). Open to both roles.
  Future<ActivityPost> createMoment(String text, List<String> images);

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

  static const Map<String, String> _sceneImages = <String, String>{
    'Coffee':
        'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=800&h=800&q=80',
    'Dinner':
        'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?auto=format&fit=crop&w=800&h=800&q=80',
    'Bar':
        'https://images.unsplash.com/photo-1514362545857-3bc16c4c7d1b?auto=format&fit=crop&w=800&h=800&q=80',
    'Movie':
        'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?auto=format&fit=crop&w=800&h=800&q=80',
    'Tea':
        'https://images.unsplash.com/photo-1544787219-7f47ccb76574?auto=format&fit=crop&w=800&h=800&q=80',
  };

  // Reads the live session so it reflects whoever actually signed in.
  static PostAuthor get currentUserAuthor => PostAuthor(
        id: AuthSession.currentUserId,
        name: AuthSession.currentUserName,
        avatarUrl: AuthSession.currentUserAvatarUrl,
        meta: AuthSession.currentUserMeta,
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
  static const PostAuthor _rafael = PostAuthor(
    id: 'user-104',
    name: 'Rafael',
    avatarUrl: 'https://i.pravatar.cc/150?img=33',
    meta: 'Male \u00b7 26',
    isVerified: true,
  );
  static const PostAuthor _daniel = PostAuthor(
    id: 'user-105',
    name: 'Daniel',
    avatarUrl: 'https://i.pravatar.cc/150?img=7',
    meta: 'Male \u00b7 31',
    isVerified: true,
  );

  /// Demo host shown as attribution on the seeded in-progress activity.
  static const PostAuthor _bianca = PostAuthor(
    id: 'host-201',
    name: 'Bianca',
    avatarUrl: 'https://i.pravatar.cc/150?img=44',
    meta: 'Female \u00b7 26',
    isVerified: true,
  );

  /// Simulated candidates who apply to the current user's new posts.
  static const List<PostAuthor> _demoCandidates = <PostAuthor>[
    PostAuthor(
      id: 'user-106',
      name: 'James',
      avatarUrl: 'https://i.pravatar.cc/150?img=13',
      meta: 'Male \u00b7 28',
      isVerified: true,
      proposal: 'Single Origin in Makati, Saturday 3pm \u2014 great beans '
          'and quiet enough to talk',
    ),
    PostAuthor(
      id: 'user-107',
      name: 'Noel',
      avatarUrl: 'https://i.pravatar.cc/150?img=53',
      meta: 'Male \u00b7 30',
      isVerified: true,
      proposal: 'New cafe in BGC with a rooftop, Sunday afternoon',
    ),
  ];

  final List<ActivityPost> _posts = <ActivityPost>[];
  final Map<String, List<PostAuthor>> _candidates =
      <String, List<PostAuthor>>{};
  final Map<String, StreamController<List<PostAuthor>>>
      _candidateControllers = <String, StreamController<List<PostAuthor>>>{};
  int _postSequence = 100;

  static List<ActivityPost> _seedPosts() {
    final DateTime now = DateTime.now();
    return <ActivityPost>[
      ActivityPost(
        id: 'post-001',
        sceneTag: 'Coffee',
        title: 'Coffee date at a new cafe',
        description: 'New specialty cafe, relaxed chat over a good brew',
        detail:
            'Found a newly opened hand-brew cafe \u2014 quiet space and the '
            'beans are supposed to be great. Looking for someone to hang out '
            'with: coffee and easy conversation about work, life, or whatever '
            'you are reading lately. No pressure, and the time is flexible.',
        timeText: 'Today 3:00 PM \u00b7 ~1.5 hours',
        place: 'Makati \u00b7 Single Origin',
        distanceKm: 1.2,
        signedCount: 0,
        imageUrl: _sceneImages['Coffee']!,
        author: _miguel,
        createdAt: now.subtract(const Duration(hours: 1)),
        budgetAmount: 600,
      ),
      ActivityPost(
        id: 'post-002',
        sceneTag: 'Dinner',
        title: 'Japanese dinner date',
        description: 'Eating alone is boring \u2014 join me for sushi',
        detail:
            'My go-to Japanese restaurant, I will book the table. Eating '
            'alone gets lonely, so I am looking for a dinner companion. The '
            'meal is on me, any topic works, and we part ways right after. '
            'Simple and easy.',
        timeText: 'Tonight 7:00 PM \u00b7 ~2 hours',
        place: 'BGC \u00b7 Sushi Nori',
        distanceKm: 2.8,
        signedCount: 0,
        imageUrl: _sceneImages['Dinner']!,
        author: _paolo,
        createdAt: now.subtract(const Duration(hours: 3)),
        budgetAmount: 1000,
      ),
      ActivityPost(
        id: 'post-003',
        sceneTag: 'Bar',
        title: 'Drinks at a quiet bar',
        description: 'Quiet whiskey bar, light drinks and good talk',
        detail:
            'Friday after work I want to unwind at a whiskey bar in '
            'Poblacion. The place is quiet \u2014 perfect for a long '
            'conversation. Looking for company for a glass or two: light '
            'drinks only, no heavy drinking, and drinks are on me. Hope you '
            'enjoy a chill vibe too.',
        timeText: 'Friday 9:00 PM \u00b7 ~2 hours',
        place: 'Poblacion \u00b7 The Spirits Library',
        distanceKm: 3.5,
        signedCount: 1,
        imageUrl: _sceneImages['Bar']!,
        author: _marco,
        createdAt: now.subtract(const Duration(hours: 5)),
        budgetAmount: 1400,
        status: 'MATCHED',
        selectedHost: _bianca,
      ),
      ActivityPost(
        id: 'post-004',
        sceneTag: 'Movie',
        title: 'Movie date for the new release',
        description: 'New film out \u2014 need someone to talk about it after',
        detail:
            'There is a new film I want to catch on Saturday. Watching alone '
            'is sad because there is nobody to discuss it with afterwards. '
            'Tickets are on me, and we can grab a snack after to talk about '
            'the movie. Even if we do not click, the date simply ends after '
            'the film.',
        timeText: 'Saturday 2:00 PM \u00b7 ~3 hours',
        place: 'Ortigas \u00b7 SM Megamall Cinema',
        distanceKm: 4.6,
        signedCount: 0,
        imageUrl: _sceneImages['Movie']!,
        author: _rafael,
        createdAt: now.subtract(const Duration(days: 1)),
        budgetAmount: 800,
      ),
      ActivityPost(
        id: 'post-005',
        sceneTag: 'Tea',
        title: 'Afternoon tea and a catch-up',
        description: 'Popular dessert cafe, sit down and unwind',
        detail:
            'Sunday I want to camp at a dessert cafe \u2014 their cakes and '
            'fruit tea get great reviews. Just looking for someone to chat '
            'and relax with. Work keeps me busy all week, so weekends are for '
            'slow conversations. All desserts and drinks are on me.',
        timeText: 'Sunday 3:30 PM \u00b7 ~2 hours',
        place: 'QC \u00b7 Dulce Patisserie',
        distanceKm: 3.9,
        signedCount: 0,
        imageUrl: _sceneImages['Tea']!,
        author: _daniel,
        createdAt: now.subtract(const Duration(days: 2)),
        budgetAmount: 650,
      ),
    ];
  }

  @override
  Future<List<ActivityPost>> fetchPosts({String? sceneTag}) async {
    // Simulated network latency so loading states stay testable.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return _posts
        .where(
          (ActivityPost post) => sceneTag == null || post.sceneTag == sceneTag,
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

  @override
  Future<ActivityPost> createPost(CreatePostInput input) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final ActivityPost post = ActivityPost(
      id: 'post-${++_postSequence}',
      sceneTag: input.sceneTag,
      title: input.title,
      description: input.description,
      detail: input.description,
      timeText: input.timeText,
      place: input.place,
      distanceKm: 0.5,
      signedCount: 0,
      imageUrl: _sceneImages[input.sceneTag] ?? _sceneImages['Coffee']!,
      author: currentUserAuthor,
      createdAt: DateTime.now(),
      budgetAmount: ScenePricing.feeForScene(input.sceneTag),
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
  Future<ActivityPost> createMoment(String text, List<String> images) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final ActivityPost post = ActivityPost(
      id: 'post-${++_postSequence}',
      type: 'MOMENT',
      sceneTag: '',
      title: text,
      description: text,
      detail: text,
      timeText: '',
      place: '',
      distanceKm: 0,
      signedCount: 0,
      imageUrl: images.isEmpty ? '' : images.first,
      images: images,
      author: currentUserAuthor,
      createdAt: DateTime.now(),
      budgetAmount: 0,
    );
    _posts.insert(0, post);
    return post;
  }

  @override
  Future<ActivityPost> signUp(String postId, String proposal) async {
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
