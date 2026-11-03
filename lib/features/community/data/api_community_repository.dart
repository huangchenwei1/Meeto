import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/constants/scene_images.dart';
import '../../../core/constants/scene_pricing.dart';
import '../../../core/network/api_client.dart';
import '../models/activity_post.dart';
import '../models/activity_template.dart';
import '../models/post_author.dart';
import 'community_repository.dart';

/// [CommunityRepository] backed by the Meeto API.
///
/// Pages are unchanged: they depend on the interface only. Money arrives in
/// minor units and is mapped to whole pesos here. Counterparty actions are
/// performed by real users from their own devices; peer-side changes arrive
/// via polling.
class ApiCommunityRepository implements CommunityRepository {
  ApiCommunityRepository(this._client);

  final ApiClient _client;

  /// postId -> applicationId per candidate, filled by candidate polling and
  /// needed to translate "approve this user" into the server's selection.
  final Map<String, Map<String, ({String applicationId, PostAuthor author})>>
      _candidatesByPost =
      <String, Map<String, ({String applicationId, PostAuthor author})>>{};

  @override
  Future<List<ActivityPost>> fetchMoments() async {
    final List<dynamic> json = await _client.get('/posts') as List<dynamic>;
    return json
        .cast<Map<String, dynamic>>()
        .map(_toActivityPost)
        .toList(growable: false);
  }

  @override
  Future<List<ActivityPost>> fetchOpenRequests() async {
    final List<dynamic> json = await _client.get(
      '/posts',
      query: <String, String>{'view': 'requests'},
    ) as List<dynamic>;
    return json
        .cast<Map<String, dynamic>>()
        .map(_toActivityPost)
        .toList(growable: false);
  }

  @override
  Future<List<String>> fetchScenes() async {
    // Scenes are defined by the platform pricing table.
    return ScenePricing.scenes;
  }

  @override
  Future<List<ActivityTemplate>> fetchTemplates() async {
    final List<dynamic> json = await _client.get('/templates') as List<dynamic>;
    return json
        .cast<Map<String, dynamic>>()
        .map(ActivityTemplate.fromJson)
        .toList(growable: false);
  }

  @override
  Future<ActivityPost> createPost(CreatePostInput input) async {
    final Map<String, dynamic> json = await _client.post(
      '/posts',
      body: <String, dynamic>{
        'sceneTag': input.sceneTag,
        'title': input.title,
        'description': input.description,
        'detail': input.description,
        if (input.timeSlot.isNotEmpty) 'timeSlot': input.timeSlot,
        if (input.area.isNotEmpty) 'area': input.area,
        if (input.budget > 0) 'budgetMinor': pesosToMinor(input.budget),
        'imageUrl': input.imageUrl.isNotEmpty
            ? input.imageUrl
            : SceneImages.forScene(input.sceneTag),
      },
    ) as Map<String, dynamic>;
    return _toActivityPost(json);
  }

  @override
  Future<void> deletePost(String postId) async {
    await _client.delete('/posts/$postId');
  }

  @override
  Future<ActivityPost> createMoment(
    String text,
    List<String> images,
    String venue,
  ) async {
    return _toActivityPost(
      await _client.post(
        '/posts/moments',
        body: <String, dynamic>{'text': text, 'images': images, 'venue': venue},
      ) as Map<String, dynamic>,
    );
  }

  @override
  Future<ActivityPost> signUp(String postId, String proposal) async {
    await _client.post(
      '/posts/$postId/applications',
      body: <String, dynamic>{'proposal': proposal},
    );
    return _fetchPost(postId);
  }

  @override
  Stream<List<PostAuthor>> watchCandidates(String postId) {
    return Stream<List<PostAuthor>>.multi(
        (StreamController<List<PostAuthor>> emitter) {
      String lastEmittedKey = '';
      Future<void> poll() async {
        try {
          final List<PostAuthor> candidates =
              await _fetchCandidates(postId);
          final String key =
              candidates.map((PostAuthor c) => c.id).join(',');
          if (key != lastEmittedKey) {
            lastEmittedKey = key;
            emitter.add(candidates);
          }
        } on Exception catch (error) {
          debugPrint('Candidate poll failed for post $postId: $error');
        }
      }

      unawaited(poll());
      final Timer timer =
          Timer.periodic(const Duration(milliseconds: 1200), (_) => poll());
      emitter.onCancel = timer.cancel;
    });
  }

  @override
  Future<PostAuthor> selectCandidate(String postId, String candidateId) async {
    Map<String, ({String applicationId, PostAuthor author})>? pool =
        _candidatesByPost[postId];
    if (pool == null || !pool.containsKey(candidateId)) {
      await _fetchCandidates(postId);
      pool = _candidatesByPost[postId];
    }
    final ({String applicationId, PostAuthor author}) candidate =
        pool![candidateId]!;

    // Creates the order server-side (AWAITING_PAYMENT); the paying user settles
    // from their own device via the order room.
    await _client.post(
      '/posts/$postId/selection',
      body: <String, dynamic>{'applicationId': candidate.applicationId},
    );
    return candidate.author;
  }

  @override
  Future<List<ActivityPost>> fetchPostsByAuthor(String authorId) async {
    final List<dynamic> json = await _client.get(
      '/posts',
      query: <String, String>{'authorId': authorId},
    ) as List<dynamic>;
    return json
        .cast<Map<String, dynamic>>()
        .map(_toActivityPost)
        .toList(growable: false);
  }

  @override
  Future<ActivityPost> fetchPostById(String postId) => _fetchPost(postId);

  Future<ActivityPost> _fetchPost(String postId) async {
    final Map<String, dynamic> json =
        await _client.get('/posts/$postId') as Map<String, dynamic>;
    return _toActivityPost(json);
  }

  Future<List<PostAuthor>> _fetchCandidates(String postId) async {
    final List<dynamic> json = await _client
        .get('/posts/$postId/applications') as List<dynamic>;
    final Map<String, ({String applicationId, PostAuthor author})> pool =
        <String, ({String applicationId, PostAuthor author})>{};
    for (final Map<String, dynamic> application
        in json.cast<Map<String, dynamic>>()) {
      final PostAuthor author =
          _toAuthor(application['applicant'] as Map<String, dynamic>)
              .withProposal(application['proposal'] as String? ?? '');
      pool[author.id] = (
        applicationId: application['id'] as String,
        author: author,
      );
    }
    _candidatesByPost[postId] = pool;
    return pool.values
        .map((({String applicationId, PostAuthor author}) c) => c.author)
        .toList(growable: false);
  }

  ActivityPost _toActivityPost(Map<String, dynamic> json) {
    final String sceneTag = json['sceneTag'] as String;
    final String imageUrl = json['imageUrl'] as String;
    final String type = json['type'] as String? ?? 'DEMAND';
    return ActivityPost(
      id: json['id'] as String,
      type: type,
      sceneTag: sceneTag,
      title: json['title'] as String,
      description: json['description'] as String,
      detail: (json['detail'] as String).isEmpty
          ? json['description'] as String
          : json['detail'] as String,
      timeSlot: json['timeSlot'] as String? ?? '',
      area: json['area'] as String? ?? '',
      venue: json['venue'] as String? ?? '',
      signedCount: json['applicantCount'] as int? ?? 0,
      // Demand cards fall back to the scene image; moments keep whatever
      // photos the author attached (possibly none).
      imageUrl: imageUrl.isEmpty && type == 'DEMAND'
          ? SceneImages.forScene(sceneTag)
          : resolveMediaUrl(imageUrl),
      images: (json['images'] as List<dynamic>? ?? <dynamic>[])
          .cast<String>()
          .map(resolveMediaUrl)
          .toList(growable: false),
      author: _toAuthor(json['author'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['createdAt'] as String),
      budgetAmount: minorToPesos(json['feeMinor'] as int),
      hasApplied: json['hasApplied'] as bool? ?? false,
      status: json['status'] as String? ?? 'OPEN',
      selectedHost: json['selectedHost'] == null
          ? null
          : _toAuthor(json['selectedHost'] as Map<String, dynamic>),
    );
  }

  PostAuthor _toAuthor(Map<String, dynamic> json) {
    return PostAuthor(
      id: json['id'] as String,
      name: json['name'] as String,
      avatarUrl: resolveMediaUrl(json['avatarUrl'] as String? ?? ''),
      meta: json['meta'] as String,
      isVerified: json['isVerified'] as bool,
    );
  }
}
