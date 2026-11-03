/// Platform default cover images per scene tag.
///
/// Used wherever a demand post or host pitch is published without a photo,
/// so feed cards never render without a cover.
abstract final class SceneImages {
  static const Map<String, String> _bySceneTag = <String, String>{
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

  /// Curated cover gallery per scene for the free-form composer: users
  /// pick one instead of uploading their own (no moderation pipeline yet).
  /// The first entry doubles as the scene's default cover.
  static const Map<String, List<String>> _galleryBySceneTag =
      <String, List<String>>{
    'Coffee': <String>[
      'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=800&h=800&q=80',
      'https://images.unsplash.com/photo-1481833761820-0509d3217039?auto=format&fit=crop&w=800&h=800&q=80',
      'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=800&h=800&q=80',
    ],
    'Dinner': <String>[
      'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?auto=format&fit=crop&w=800&h=800&q=80',
      'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?auto=format&fit=crop&w=800&h=800&q=80',
      'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=800&h=800&q=80',
    ],
    'Bar': <String>[
      'https://images.unsplash.com/photo-1514362545857-3bc16c4c7d1b?auto=format&fit=crop&w=800&h=800&q=80',
      'https://images.unsplash.com/photo-1514933651103-005eec06c04b?auto=format&fit=crop&w=800&h=800&q=80',
      'https://images.unsplash.com/photo-1470337458703-46ad1756a187?auto=format&fit=crop&w=800&h=800&q=80',
    ],
    'Movie': <String>[
      'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?auto=format&fit=crop&w=800&h=800&q=80',
      'https://images.unsplash.com/photo-1536440136628-849c177e76a1?auto=format&fit=crop&w=800&h=800&q=80',
      'https://images.unsplash.com/photo-1517604931442-7e0c8ed2963c?auto=format&fit=crop&w=800&h=800&q=80',
    ],
    'Tea': <String>[
      'https://images.unsplash.com/photo-1544787219-7f47ccb76574?auto=format&fit=crop&w=800&h=800&q=80',
      'https://images.unsplash.com/photo-1576092768241-dec231879fc3?auto=format&fit=crop&w=800&h=800&q=80',
      'https://images.unsplash.com/photo-1563822249366-3efb23b8e0c9?auto=format&fit=crop&w=800&h=800&q=80',
    ],
  };

  /// Default cover for [sceneTag]; unknown scenes fall back to Coffee.
  static String forScene(String sceneTag) =>
      _bySceneTag[sceneTag] ?? _bySceneTag['Coffee']!;

  /// Curated cover choices for [sceneTag]; unknown scenes fall back to
  /// Coffee.
  static List<String> galleryForScene(String sceneTag) =>
      _galleryBySceneTag[sceneTag] ?? _galleryBySceneTag['Coffee']!;
}
