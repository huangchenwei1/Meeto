import { PrismaClient } from '@prisma/client';

// E2E-only hall fixtures: demo demand posts, host pitches, candidate
// applications and the in-progress escrow order. The dev database stays
// clean (seed.mjs seeds only pricing, the user cast and community
// moments); the e2e suite layers these on top of a fresh test.db.
const prisma = new PrismaClient();

// Demand posts: rough activity intents from the USER side. Only a fuzzy
// time slot and a rough district at publish time — the selected host
// still proposes the concrete plan (exact time and venue) after matching.
const hoursAgo = (h) => new Date(Date.now() - h * 3600 * 1000);

const POSTS = [
  {
    id: 'post-001',
    authorId: 'user-101',
    type: 'DEMAND',
    sceneTag: 'Coffee',
    timeSlot: 'WEEKEND',
    area: 'Makati',
    title: 'Show me a cafe worth leaving BGC for',
    description: 'Want a relaxed coffee afternoon, you pick the place',
    detail:
      'I have been in Manila three months and only know the chain cafes ' +
      'near my office. Looking for a host who knows the specialty coffee ' +
      'scene and can plan a relaxed afternoon: the place, the order, the ' +
      'conversation. Time is flexible this week.',
    imageUrl:
      'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=800&h=800&q=80',
    feeMinor: 150000,
    createdAt: hoursAgo(1),
  },
  {
    id: 'post-002',
    authorId: 'user-102',
    type: 'DEMAND',
    sceneTag: 'Dinner',
    timeSlot: 'TONIGHT',
    area: 'BGC',
    title: 'Plan me a Japanese dinner I cannot find on my own',
    description: 'Good sushi, good conversation, you handle the plan',
    detail:
      'I eat out a lot but keep going back to the same two places. Want a ' +
      'host who can plan a proper Japanese dinner — somewhere I would ' +
      'never find alone. Weeknights after 7 work best. Meal is on me.',
    imageUrl:
      'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?auto=format&fit=crop&w=800&h=800&q=80',
    feeMinor: 400000,
    createdAt: hoursAgo(3),
  },
  {
    // Seeded as an in-progress activity: Liza's plan is selected and the
    // escrow order is ACTIVE, so the community wall shows attribution.
    id: 'post-003',
    authorId: 'user-103',
    type: 'DEMAND',
    sceneTag: 'Movie',
    timeSlot: 'WEEKEND',
    area: 'Ortigas',
    status: 'MATCHED',
    title: 'Movie night with an actual plan',
    description: 'Pick the film, the cinema and the after-talk spot',
    detail:
      'I love movies but hate deciding. Looking for a host to plan the ' +
      'whole evening: which film, which cinema, and where we talk about ' +
      'it after. Saturday afternoon preferred. Tickets and snacks on me.',
    imageUrl:
      'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?auto=format&fit=crop&w=800&h=800&q=80',
    feeMinor: 250000,
    createdAt: hoursAgo(24),
  },
  {
    id: 'post-004',
    authorId: 'user-100',
    type: 'DEMAND',
    sceneTag: 'Tea',
    timeSlot: 'TODAY_AFTERNOON',
    area: 'Salcedo Village',
    title: 'Slow Sunday: dessert cafe and no agenda',
    description: 'Need someone to plan a lazy tea afternoon',
    detail:
      'Work ate my whole month. I want one slow Sunday afternoon: good ' +
      'fruit tea, good cake, zero decisions made by me. Host plans ' +
      'everything, I just show up. Desserts are on me.',
    imageUrl:
      'https://images.unsplash.com/photo-1544787219-7f47ccb76574?auto=format&fit=crop&w=800&h=800&q=80',
    feeMinor: 180000,
    createdAt: hoursAgo(48),
  },
];

// Hosts already pitching on the open posts, so candidate pools and the
// host directory's recent-proposal lines have real content.
const APPLICATIONS = [
  {
    id: 'app-001',
    postId: 'post-001',
    applicantId: 'host-204',
    proposal:
      'Single Origin in Salcedo, Saturday 3pm — quiet upstairs seats and ' +
      'the best hand brew flight in Makati',
  },
  {
    id: 'app-002',
    postId: 'post-001',
    applicantId: 'host-201',
    proposal:
      'Hidden cafe inside a Legazpi bookshop, Sunday 2pm — great beans, ' +
      'even better people-watching',
  },
  {
    id: 'app-003',
    postId: 'post-002',
    applicantId: 'host-202',
    proposal:
      'Omakase counter in Little Tokyo, Thursday 7:30pm — 12 seats, I ' +
      'know when the uni arrives fresh',
  },
  {
    id: 'app-004',
    postId: 'post-003',
    applicantId: 'host-203',
    status: 'SELECTED',
    proposal:
      'Director\u2019s cut screening at Power Plant, Saturday 4pm, then ' +
      'milk tea next door for the debrief',
  },
];

// Supply-side activity pitches from hosts: the user home feed. Loose on
// purpose (no time/place) — the concrete plan comes after matching.
const PROPOSALS = [
  {
    id: 'proposal-001',
    hostId: 'host-205',
    sceneTag: 'Bar',
    budgetMinor: 350000,
    area: 'Poblacion',
    imageUrl:
      'https://images.unsplash.com/photo-1514933651103-005eec06c04b?auto=format&fit=crop&w=800&h=800&q=80',
    title: '周五晚 Poblacion 天台酒吧，带你喝懂本地精酿',
    description: '认识几家本地精酿厂牌，从酒单讲到酿法，微醺收尾',
    createdAt: hoursAgo(2),
  },
  {
    id: 'proposal-002',
    hostId: 'host-201',
    sceneTag: 'Coffee',
    budgetMinor: 150000,
    area: 'Legazpi Village',
    imageUrl:
      'https://images.unsplash.com/photo-1481833761820-0509d3217039?auto=format&fit=crop&w=800&h=800&q=80',
    title: '去 Legazpi 书店里的隐藏咖啡馆，坐一个安静的下午',
    description: '书店里的隐藏咖啡吧台，豆子好，人少安静，适合聊天',
    createdAt: hoursAgo(5),
  },
  {
    id: 'proposal-003',
    hostId: 'host-202',
    sceneTag: 'Dinner',
    budgetMinor: 400000,
    area: 'Little Tokyo',
    imageUrl:
      'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?auto=format&fit=crop&w=800&h=800&q=80',
    title: '小东京 12 座板前日料，我知道海胆哪天最新鲜',
    description: '板前只有 12 个座位，主厨是老朋友，当天最新鲜的交给他',
    createdAt: hoursAgo(9),
  },
  {
    id: 'proposal-004',
    hostId: 'host-203',
    sceneTag: 'Movie',
    budgetMinor: 250000,
    area: 'Rockwell',
    imageUrl:
      'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?auto=format&fit=crop&w=800&h=800&q=80',
    title: '去看一场导演剪辑版，散场后找家甜品店聊到打烊',
    description: '选片选座我来，散场后的甜品店也订好，只管来',
    createdAt: hoursAgo(20),
  },
  {
    id: 'proposal-005',
    hostId: 'host-204',
    sceneTag: 'Coffee',
    budgetMinor: 150000,
    area: 'Salcedo Village',
    imageUrl:
      'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=800&h=800&q=80',
    title: 'Salcedo 周末市集 + 手冲豆单盲品，咖啡入门局',
    description: '从浅烘到深烘盲品四支豆子，喝完你就有自己的答案了',
    createdAt: hoursAgo(30),
  },
  {
    id: 'proposal-006',
    hostId: 'host-203',
    sceneTag: 'Tea',
    budgetMinor: 180000,
    area: 'Ayala Triangle',
    imageUrl:
      'https://images.unsplash.com/photo-1544787219-7f47ccb76574?auto=format&fit=crop&w=800&h=800&q=80',
    title: '下班后的奶茶散步局，沿 Ayala Triangle 走到天黑',
    description: '一杯奶茶的时间，沿着绿道慢慢走，把一周的班味散掉',
    createdAt: hoursAgo(44),
  },
];

// The escrow order backing the in-progress seeded activity (post-003).
const ORDERS = [
  {
    id: 'order-001',
    postId: 'post-003',
    payerId: 'user-103',
    earnerId: 'host-203',
    status: 'ACTIVE',
    feeMinor: 250000,
    commissionMinor: 25000,
    netMinor: 225000,
  },
];

async function main() {
  for (const post of POSTS) {
    await prisma.post.upsert({ where: { id: post.id }, update: {}, create: post });
  }
  for (const application of APPLICATIONS) {
    await prisma.application.upsert({
      where: { id: application.id },
      update: {},
      create: application,
    });
  }
  for (const proposal of PROPOSALS) {
    await prisma.proposal.upsert({
      where: { id: proposal.id },
      update: {},
      create: proposal,
    });
  }
  for (const order of ORDERS) {
    await prisma.order.upsert({ where: { id: order.id }, update: {}, create: order });
  }
  console.log('E2E hall fixtures loaded');
}

await main().finally(() => prisma.$disconnect());
