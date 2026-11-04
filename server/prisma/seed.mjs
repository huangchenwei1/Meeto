// Idempotent demo seed: pricing config + role-based demo cast.
// USER accounts post activity requests and pay; HOST accounts sign up to
// host them and earn. Run via `npx prisma db seed`.
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

// Platform-set activity budget tiers: the price buys the whole activity.
// The poster picks one tier per scene (defaulting to the middle one); the
// host covers the activity costs (food, drinks, tickets) out of it and
// keeps the remainder as hosting income, minus the platform commission.
const PRICING = {
  platformFeeRateBp: 1000, // 10%
  defaultFeeMinor: 20000, // RMB 200.00 — scenes without a tier list
  sceneBudgetTiersJson: JSON.stringify({
    Coffee: [10000, 15000, 25000],
    Tea: [12000, 18000, 28000],
    Movie: [18000, 25000, 35000],
    Bar: [25000, 35000, 50000],
    Dinner: [30000, 40000, 60000],
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

const hoursAgo = (h) => new Date(Date.now() - h * 3600 * 1000);

// Community recaps (moments): photos + a line about a completed activity.
const MOMENTS = [
  {
    id: 'moment-001',
    authorId: 'user-100',
    type: 'MOMENT',
    sceneTag: '',
    title:
      'Bianca 带我去了昙华林一家藏在书店里的咖啡馆，几个月来最舒服的周日' +
      '——一下午没做一个决定。',
    description:
      'Bianca 带我去了昙华林一家藏在书店里的咖啡馆，几个月来最舒服的周日' +
      '——一下午没做一个决定。',
    imageUrl:
      'https://images.unsplash.com/photo-1554118811-1e0d58224f24?auto=format&fit=crop&w=800&h=800&q=80',
    imagesJson: JSON.stringify([
      'https://images.unsplash.com/photo-1554118811-1e0d58224f24?auto=format&fit=crop&w=800&h=800&q=80',
      'https://images.unsplash.com/photo-1481833761820-0509d3217039?auto=format&fit=crop&w=800&h=800&q=80',
    ]),
    venue: '昙华林深处的书店咖啡馆',
    feeMinor: 0,
    createdAt: hoursAgo(6),
  },
  {
    id: 'moment-002',
    authorId: 'user-102',
    type: 'MOMENT',
    sceneTag: '',
    title:
      'Kat 订到了江汉路一家我从不知道的 12 座板前日料，' +
      '这顿服务费花得太值了。',
    description:
      'Kat 订到了江汉路一家我从不知道的 12 座板前日料，' +
      '这顿服务费花得太值了。',
    imageUrl:
      'https://images.unsplash.com/photo-1553621042-f6e147245754?auto=format&fit=crop&w=800&h=800&q=80',
    imagesJson: JSON.stringify([
      'https://images.unsplash.com/photo-1553621042-f6e147245754?auto=format&fit=crop&w=800&h=800&q=80',
    ]),
    venue: '江汉路 12 座板前日料',
    feeMinor: 0,
    createdAt: hoursAgo(12),
  },
];

async function main() {
  await prisma.pricingConfig.upsert({
    where: { id: 1 },
    // Reseeding applies the current platform pricing to existing rows.
    update: { ...PRICING },
    create: { id: 1, ...PRICING },
  });
  for (const user of USERS) {
    await prisma.user.upsert({
      where: { id: user.id },
      update: {},
      create: user,
    });
  }
  for (const post of MOMENTS) {
    await prisma.post.upsert({
      where: { id: post.id },
      // Reseeding refreshes the ops-owned copy on existing rows too.
      update: {
        title: post.title,
        description: post.description,
        venue: post.venue,
      },
      create: post,
    });
  }
  console.log('Seed complete');
}

await main().finally(() => prisma.$disconnect());
