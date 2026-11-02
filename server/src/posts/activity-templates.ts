/// Curated activity templates shown on the "hot activities" shelf. Picking
/// one prefills the publish flow (users post a request, hosts post a
/// pitch), which keeps post quality anchored and removes the blank-input
/// friction. Operations-owned content: identifiers stay English, display
/// copy is whatever the market speaks. The budget is not stored here — it
/// is the platform scene fee, resolved from pricing at display time.
export interface ActivityTemplate {
  id: string;
  sceneTag: string;
  title: string;
  description: string;
  imageUrl: string;
  /// Display label for the rough duration, e.g. "约 1.5 小时".
  durationLabel: string;
  /// Display label for the venue type, e.g. "咖啡馆".
  venueLabel: string;
}

export const ACTIVITY_TEMPLATES: ActivityTemplate[] = [
  {
    id: 'template-coffee-tour',
    sceneTag: 'Coffee',
    title: '咖啡探店',
    description: '新开的小众咖啡馆，找个人边喝边聊',
    imageUrl:
      'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=800&h=800&q=80',
    durationLabel: '约 1.5 小时',
    venueLabel: '咖啡馆',
  },
  {
    id: 'template-dinner-popular',
    sceneTag: 'Dinner',
    title: '人气餐厅晚餐',
    description: '一个人吃饭没意思，找人边吃边聊',
    imageUrl:
      'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?auto=format&fit=crop&w=800&h=800&q=80',
    durationLabel: '约 2 小时',
    venueLabel: '餐厅',
  },
  {
    id: 'template-movie-night',
    sceneTag: 'Movie',
    title: '一起看电影',
    description: '新片上映，看完一起聊聊观后感',
    imageUrl:
      'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?auto=format&fit=crop&w=800&h=800&q=80',
    durationLabel: '约 3 小时',
    venueLabel: '影院',
  },
  {
    id: 'template-bar-crawl',
    sceneTag: 'Bar',
    title: '微醺酒吧夜',
    description: '找个懂酒的，带我喝点不一样的',
    imageUrl:
      'https://images.unsplash.com/photo-1514362545857-3bc16c4c7d1b?auto=format&fit=crop&w=800&h=800&q=80',
    durationLabel: '约 2 小时',
    venueLabel: '酒吧',
  },
  {
    id: 'template-tea-afternoon',
    sceneTag: 'Tea',
    title: '慢下午茶',
    description: '甜品配茶，聊聊最近的生活',
    imageUrl:
      'https://images.unsplash.com/photo-1544787219-7f47ccb76574?auto=format&fit=crop&w=800&h=800&q=80',
    durationLabel: '约 1.5 小时',
    venueLabel: '茶室',
  },
];
