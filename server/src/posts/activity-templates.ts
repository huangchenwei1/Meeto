/// Curated activity templates shown on the "hot activities" shelf — the
/// only publish entry: picking one prefills the composer (users post a
/// request, hosts post a pitch), which keeps post quality anchored and
/// removes the blank-input friction. Operations-owned content: identifiers
/// stay English, display copy is whatever the market speaks. For now this
/// is a hand-picked Wuhan list standing in for the future ops console.
/// The budget is not stored here — it is the platform scene fee, resolved
/// from pricing at display time.
export interface ActivityTemplate {
  id: string;
  sceneTag: string;
  title: string;
  description: string;
  imageUrl: string;
  /// Display label for the rough duration, e.g. "约 2 小时".
  durationLabel: string;
  /// Display label for the venue type, e.g. "咖啡馆".
  venueLabel: string;
  /// Rough city area the activity anchors to (e.g. "黎黄陂路"); matches
  /// the composer's area chips so launching prefills the post location.
  area: string;
}

export const ACTIVITY_TEMPLATES: ActivityTemplate[] = [
  {
    id: 'template-lihuangpi-road-coffee',
    sceneTag: 'Coffee',
    title: '黎黄陂路街角咖啡散步',
    description: '老租界的红砖路，一杯手冲边走边喝，武汉最松弛的两小时',
    imageUrl:
      'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=800&h=800&q=80',
    durationLabel: '约 2 小时',
    venueLabel: '街区漫步',
    area: '黎黄陂路',
  },
  {
    id: 'template-tanhualin-bookshop-cafe',
    sceneTag: 'Coffee',
    title: '昙华林书店里的隐藏咖啡馆',
    description: '藏在书架后面的吧台，豆子好，人少安静',
    imageUrl:
      'https://images.unsplash.com/photo-1481833761820-0509d3217039?auto=format&fit=crop&w=800&h=800&q=80',
    durationLabel: '约 1.5 小时',
    venueLabel: '咖啡馆',
    area: '昙华林',
  },
  {
    id: 'template-wansongyuan-crayfish-dinner',
    sceneTag: 'Dinner',
    title: '万松园油焖大虾宵夜局',
    description: '老牌虾店加生烫牛肉，一个人不敢点满桌，两个人刚好',
    imageUrl:
      'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?auto=format&fit=crop&w=800&h=800&q=80',
    durationLabel: '约 2 小时',
    venueLabel: '大排档',
    area: '万松园',
  },
  {
    id: 'template-jianghan-road-omakase',
    sceneTag: 'Dinner',
    title: '江汉路板前日料',
    description: '12 座的板前，当天最新鲜的交给主厨安排',
    imageUrl:
      'https://images.unsplash.com/photo-1553621042-f6e147245754?auto=format&fit=crop&w=800&h=800&q=80',
    durationLabel: '约 2 小时',
    venueLabel: '日料店',
    area: '江汉路',
  },
  {
    id: 'template-jiangtan-riverside-bars',
    sceneTag: 'Bar',
    title: '江滩夜景酒吧巡礼',
    description: '从精酿到调酒，三家风格不同的小店，看着长江微醺收尾',
    imageUrl:
      'https://images.unsplash.com/photo-1514362545857-3bc16c4c7d1b?auto=format&fit=crop&w=800&h=800&q=80',
    durationLabel: '约 3 小时',
    venueLabel: '酒吧',
    area: '汉口江滩',
  },
  {
    id: 'template-chuhehanjie-movie-dessert',
    sceneTag: 'Movie',
    title: '楚河汉街影院夜 + 散场甜品',
    description: '新片加散场后的甜品店复盘，不用自己做任何决定',
    imageUrl:
      'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?auto=format&fit=crop&w=800&h=800&q=80',
    durationLabel: '约 3 小时',
    venueLabel: '影院',
    area: '楚河汉街',
  },
  {
    id: 'template-donghu-lakeside-tea',
    sceneTag: 'Tea',
    title: '东湖边的下午茶',
    description: '听涛绿道走一圈，末站是湖边安静的茶室',
    imageUrl:
      'https://images.unsplash.com/photo-1544787219-7f47ccb76574?auto=format&fit=crop&w=800&h=800&q=80',
    durationLabel: '约 2.5 小时',
    venueLabel: '茶室',
    area: '东湖',
  },
];
