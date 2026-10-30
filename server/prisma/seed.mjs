// Idempotent demo seed: pricing config + role-based demo cast.
// USER accounts post activity requests and pay; HOST accounts sign up to
// host them and earn. Run via `npx prisma db seed`.
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const PRICING = {
  platformFeeRateBp: 1000, // 10%
  defaultFeeMinor: 60000, // PHP 600.00
  sceneFeesJson: JSON.stringify({
    Coffee: 60000,
    Dinner: 100000,
    Bar: 140000,
    Movie: 80000,
    Tea: 65000,
  }),
};

const year = new Date().getFullYear();
const born = (age) => new Date(Date.UTC(year - age, 0, 1));

const BASE = {
  country: 'Philippines',
  city: 'Manila',
  verificationStatus: 'VERIFIED',
};

const USERS = [
  // ---- USER side: post activity requests, pay the service fee ----
  {
    ...BASE,
    id: 'user-100',
    phone: '+639170000100',
    name: 'Andrea',
    gender: 'FEMALE',
    role: 'USER',
    birthDate: born(24),
    avatarUrl: 'https://i.pravatar.cc/150?img=47',
    meta: 'Female · 24',
    bio: 'Marketing associate who never plans her own weekends.',
  },
  {
    ...BASE,
    id: 'user-101',
    phone: '+639170000101',
    name: 'Miguel',
    gender: 'MALE',
    role: 'USER',
    birthDate: born(27),
    avatarUrl: 'https://i.pravatar.cc/150?img=11',
    meta: 'Male · 27',
    bio: 'New to Manila, wants to see more than the office and the condo.',
  },
  {
    ...BASE,
    id: 'user-102',
    phone: '+639170000102',
    name: 'Paolo',
    gender: 'MALE',
    role: 'USER',
    birthDate: born(29),
    avatarUrl: 'https://i.pravatar.cc/150?img=59',
    meta: 'Male · 29',
    bio: 'Foodie, always hunting for the next good table.',
  },
  {
    ...BASE,
    id: 'user-103',
    phone: '+639170000103',
    name: 'Marco',
    gender: 'MALE',
    role: 'USER',
    birthDate: born(28),
    avatarUrl: 'https://i.pravatar.cc/150?img=12',
    meta: 'Male · 28',
    bio: 'Weekend cinephile looking for movie company.',
  },
  // ---- HOST side: sign up to host activities, earn the service fee ----
  {
    ...BASE,
    id: 'host-201',
    phone: '+639170000201',
    name: 'Bianca',
    gender: 'FEMALE',
    role: 'HOST',
    birthDate: born(26),
    avatarUrl: 'https://i.pravatar.cc/150?img=44',
    meta: 'Female · 26',
    bio:
      'Cafe-hopping host. I keep a running list of the best quiet cafes ' +
      'in Makati and BGC and I always know where to sit.',
    tagsJson: JSON.stringify(['Coffee', 'Dessert cafes', 'Board games']),
    hostScenesJson: JSON.stringify(['Coffee', 'Tea']),
  },
  {
    ...BASE,
    id: 'host-202',
    phone: '+639170000202',
    name: 'Kat',
    gender: 'FEMALE',
    role: 'HOST',
    birthDate: born(28),
    avatarUrl: 'https://i.pravatar.cc/150?img=31',
    meta: 'Female · 28',
    bio:
      'Food tour host. Ex-restaurant floor manager; I plan dinners people ' +
      'still talk about a month later.',
    tagsJson: JSON.stringify(['Dinner', 'Japanese food', 'Hidden gems']),
    hostScenesJson: JSON.stringify(['Dinner']),
  },
  {
    ...BASE,
    id: 'host-203',
    phone: '+639170000203',
    name: 'Liza',
    gender: 'FEMALE',
    role: 'HOST',
    birthDate: born(25),
    avatarUrl: 'https://i.pravatar.cc/150?img=25',
    meta: 'Female · 25',
    bio:
      'Movies and after-talk. I pick the screening, the seats, and the ' +
      'dessert place for the post-movie debrief.',
    tagsJson: JSON.stringify(['Movies', 'Tea', 'Long walks']),
    hostScenesJson: JSON.stringify(['Movie', 'Tea']),
  },
  {
    ...BASE,
    id: 'host-204',
    phone: '+639170000204',
    name: 'James',
    gender: 'MALE',
    role: 'HOST',
    birthDate: born(28),
    avatarUrl: 'https://i.pravatar.cc/150?img=13',
    meta: 'Male · 28',
    bio:
      'Specialty coffee host and third-wave cafe regular. Great at easy ' +
      'conversation with anyone.',
    tagsJson: JSON.stringify(['Coffee', 'Basketball', 'Vinyl']),
    hostScenesJson: JSON.stringify(['Coffee']),
  },
  {
    ...BASE,
    id: 'host-205',
    phone: '+639170000205',
    name: 'Noel',
    gender: 'MALE',
    role: 'HOST',
    birthDate: born(30),
    avatarUrl: 'https://i.pravatar.cc/150?img=53',
    meta: 'Male · 30',
    bio:
      'Bar crawl host in Poblacion. I know which rooftop is quiet on a ' +
      'Friday and which whiskey list is actually worth it.',
    tagsJson: JSON.stringify(['Bars', 'Whiskey', 'Live music']),
    hostScenesJson: JSON.stringify(['Bar']),
  },
  // ---- Internal ----
  {
    ...BASE,
    id: 'admin-1',
    phone: '+639170000001',
    name: 'Meeto Ops',
    gender: 'FEMALE',
    role: 'ADMIN',
    birthDate: born(30),
  },
];

// Demand posts: rough activity intents from the USER side. Time and place
// stay loose on purpose — the selected host proposes the concrete plan.
const hoursAgo = (h) => new Date(Date.now() - h * 3600 * 1000);

const POSTS = [
  {
    id: 'post-001',
    authorId: 'user-101',
    type: 'DEMAND',
    sceneTag: 'Coffee',
    title: 'Show me a cafe worth leaving BGC for',
    description: 'Want a relaxed coffee afternoon, you pick the place',
    detail:
      'I have been in Manila three months and only know the chain cafes ' +
      'near my office. Looking for a host who knows the specialty coffee ' +
      'scene and can plan a relaxed afternoon: the place, the order, the ' +
      'conversation. Time is flexible this week.',
    imageUrl:
      'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=800&h=800&q=80',
    feeMinor: 60000,
    createdAt: hoursAgo(1),
  },
  {
    id: 'post-002',
    authorId: 'user-102',
    type: 'DEMAND',
    sceneTag: 'Dinner',
    title: 'Plan me a Japanese dinner I cannot find on my own',
    description: 'Good sushi, good conversation, you handle the plan',
    detail:
      'I eat out a lot but keep going back to the same two places. Want a ' +
      'host who can plan a proper Japanese dinner — somewhere I would ' +
      'never find alone. Weeknights after 7 work best. Meal is on me.',
    imageUrl:
      'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?auto=format&fit=crop&w=800&h=800&q=80',
    feeMinor: 100000,
    createdAt: hoursAgo(3),
  },
  {
    // Seeded as an in-progress activity: Liza's plan is selected and the
    // escrow order is ACTIVE, so the community wall shows attribution.
    id: 'post-003',
    authorId: 'user-103',
    type: 'DEMAND',
    sceneTag: 'Movie',
    status: 'MATCHED',
    title: 'Movie night with an actual plan',
    description: 'Pick the film, the cinema and the after-talk spot',
    detail:
      'I love movies but hate deciding. Looking for a host to plan the ' +
      'whole evening: which film, which cinema, and where we talk about ' +
      'it after. Saturday afternoon preferred. Tickets and snacks on me.',
    imageUrl:
      'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?auto=format&fit=crop&w=800&h=800&q=80',
    feeMinor: 80000,
    createdAt: hoursAgo(24),
  },
  {
    id: 'post-004',
    authorId: 'user-100',
    type: 'DEMAND',
    sceneTag: 'Tea',
    title: 'Slow Sunday: dessert cafe and no agenda',
    description: 'Need someone to plan a lazy tea afternoon',
    detail:
      'Work ate my whole month. I want one slow Sunday afternoon: good ' +
      'fruit tea, good cake, zero decisions made by me. Host plans ' +
      'everything, I just show up. Desserts are on me.',
    imageUrl:
      'https://images.unsplash.com/photo-1544787219-7f47ccb76574?auto=format&fit=crop&w=800&h=800&q=80',
    feeMinor: 65000,
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
    title: '周五晚 Poblacion 天台酒吧，带你喝懂本地精酿',
    createdAt: hoursAgo(2),
  },
  {
    id: 'proposal-002',
    hostId: 'host-201',
    sceneTag: 'Coffee',
    title: '去 Legazpi 书店里的隐藏咖啡馆，坐一个安静的下午',
    createdAt: hoursAgo(5),
  },
  {
    id: 'proposal-003',
    hostId: 'host-202',
    sceneTag: 'Dinner',
    title: '小东京 12 座板前日料，我知道海胆哪天最新鲜',
    createdAt: hoursAgo(9),
  },
  {
    id: 'proposal-004',
    hostId: 'host-203',
    sceneTag: 'Movie',
    title: '去看一场导演剪辑版，散场后找家甜品店聊到打烊',
    createdAt: hoursAgo(20),
  },
  {
    id: 'proposal-005',
    hostId: 'host-204',
    sceneTag: 'Coffee',
    title: 'Salcedo 周末市集 + 手冲豆单盲品，咖啡入门局',
    createdAt: hoursAgo(30),
  },
  {
    id: 'proposal-006',
    hostId: 'host-203',
    sceneTag: 'Tea',
    title: '下班后的奶茶散步局，沿 Ayala Triangle 走到天黑',
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
    feeMinor: 80000,
    commissionMinor: 8000,
    netMinor: 72000,
  },
];

// Community recaps (moments): photos + a line about a completed activity.
const MOMENTS = [
  {
    id: 'moment-001',
    authorId: 'user-100',
    type: 'MOMENT',
    sceneTag: '',
    title:
      'Bianca took me to a cafe hidden inside a bookshop. Best Sunday in ' +
      'months — I did not make a single decision all afternoon.',
    description:
      'Bianca took me to a cafe hidden inside a bookshop. Best Sunday in ' +
      'months — I did not make a single decision all afternoon.',
    imageUrl:
      'https://images.unsplash.com/photo-1554118811-1e0d58224f24?auto=format&fit=crop&w=800&h=800&q=80',
    imagesJson: JSON.stringify([
      'https://images.unsplash.com/photo-1554118811-1e0d58224f24?auto=format&fit=crop&w=800&h=800&q=80',
      'https://images.unsplash.com/photo-1481833761820-0509d3217039?auto=format&fit=crop&w=800&h=800&q=80',
    ]),
    feeMinor: 0,
    createdAt: hoursAgo(6),
  },
  {
    id: 'moment-002',
    authorId: 'user-102',
    type: 'MOMENT',
    sceneTag: '',
    title:
      'Kat planned a dinner at a 12-seat omakase counter I never knew ' +
      'existed. Worth every peso of the service fee.',
    description:
      'Kat planned a dinner at a 12-seat omakase counter I never knew ' +
      'existed. Worth every peso of the service fee.',
    imageUrl:
      'https://images.unsplash.com/photo-1553621042-f6e147245754?auto=format&fit=crop&w=800&h=800&q=80',
    imagesJson: JSON.stringify([
      'https://images.unsplash.com/photo-1553621042-f6e147245754?auto=format&fit=crop&w=800&h=800&q=80',
    ]),
    feeMinor: 0,
    createdAt: hoursAgo(12),
  },
];

async function main() {
  await prisma.pricingConfig.upsert({
    where: { id: 1 },
    update: {},
    create: { id: 1, ...PRICING },
  });
  for (const user of USERS) {
    await prisma.user.upsert({
      where: { id: user.id },
      // Existing rows get the offered-scenes backfill on reseed.
      update: user.hostScenesJson
        ? { hostScenesJson: user.hostScenesJson }
        : {},
      create: user,
    });
  }
  for (const post of [...POSTS, ...MOMENTS]) {
    await prisma.post.upsert({
      where: { id: post.id },
      update: {},
      create: post,
    });
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
    await prisma.order.upsert({
      where: { id: order.id },
      update: {},
      create: order,
    });
  }
  console.log('Seed complete');
}

await main().finally(() => prisma.$disconnect());
