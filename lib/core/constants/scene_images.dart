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

  /// Default cover for [sceneTag]; unknown scenes fall back to Coffee.
  static String forScene(String sceneTag) =>
      _bySceneTag[sceneTag] ?? _bySceneTag['Coffee']!;
}
