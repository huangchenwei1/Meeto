/// Curated activity templates shown on the "hot activities" shelf — the
/// only publish entry: picking one prefills the composer (users post a
/// request, hosts post a pitch), which keeps post quality anchored and
/// removes the blank-input friction. Operations-owned content: identifiers
/// stay English, display copy is whatever the market speaks. For now this
/// is a hand-picked Manila list standing in for the future ops console.
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
}

export const ACTIVITY_TEMPLATES: ActivityTemplate[] = [
  {
    id: 'template-salcedo-market-coffee',
    sceneTag: 'Coffee',
    title: 'Salcedo 周末市集咖啡散步',
    description: '市集开档的周六早上，边逛边喝，Makati 最松弛的两小时',
    imageUrl:
      'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=800&h=800&q=80',
    durationLabel: '约 2 小时',
    venueLabel: '周末市集',
  },
  {
    id: 'template-legazpi-bookshop-cafe',
    sceneTag: 'Coffee',
    title: 'Legazpi 书店里的隐藏咖啡馆',
    description: '藏在书架后面的吧台，豆子好，人少安静',
    imageUrl:
      'https://images.unsplash.com/photo-1481833761820-0509d3217039?auto=format&fit=crop&w=800&h=800&q=80',
    durationLabel: '约 1.5 小时',
    venueLabel: '咖啡馆',
  },
  {
    id: 'template-poblacion-filipino-dinner',
    sceneTag: 'Dinner',
    title: 'Poblacion 小巷菲式融合晚餐',
    description: '本地主厨的创意菜，一个人不敢点满桌，两个人刚好',
    imageUrl:
      'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?auto=format&fit=crop&w=800&h=800&q=80',
    durationLabel: '约 2 小时',
    venueLabel: '餐厅',
  },
  {
    id: 'template-little-tokyo-omakase',
    sceneTag: 'Dinner',
    title: '小东京板前日料',
    description: 'Makati 小东京 12 座板前，当天最新鲜的交给主厨',
    imageUrl:
      'https://images.unsplash.com/photo-1553621042-f6e147245754?auto=format&fit=crop&w=800&h=800&q=80',
    durationLabel: '约 2 小时',
    venueLabel: '日料店',
  },
  {
    id: 'template-poblacion-rooftop-bars',
    sceneTag: 'Bar',
    title: 'Poblacion 天台酒吧巡礼',
    description: '从精酿到调酒，三家风格完全不同的天台，微醺收尾',
    imageUrl:
      'https://images.unsplash.com/photo-1514362545857-3bc16c4c7d1b?auto=format&fit=crop&w=800&h=800&q=80',
    durationLabel: '约 3 小时',
    venueLabel: '酒吧',
  },
  {
    id: 'template-bgc-movie-dessert',
    sceneTag: 'Movie',
    title: 'BGC 影院夜 + 散场甜品',
    description: '新片加散场后的甜品店复盘，不用自己做任何决定',
    imageUrl:
      'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?auto=format&fit=crop&w=800&h=800&q=80',
    durationLabel: '约 3 小时',
    venueLabel: '影院',
  },
  {
    id: 'template-intramuros-tea',
    sceneTag: 'Tea',
    title: 'Intramuros 老城下午茶',
    description: '西班牙老城区走一圈，末站是百年建筑里的茶室',
    imageUrl:
      'https://images.unsplash.com/photo-1544787219-7f47ccb76574?auto=format&fit=crop&w=800&h=800&q=80',
    durationLabel: '约 2.5 小时',
    venueLabel: '茶室',
  },
];
