import { PrismaClient } from '@prisma/client';

// E2E-only hall fixtures: demo demand posts, host pitches, candidate
// applications and the in-progress escrow order. The dev database stays
// clean (seed.mjs seeds only pricing and the user cast); the e2e suite
// layers these on top of a fresh test.db.
//
// Template-only world: every post/pitch launches from one of the curated
// Manila templates (see src/posts/activity-templates.ts). The template
// fixes scene, cover, district and meeting point; the publisher brings
// words and a concrete meeting time. Budgets must be valid platform
// tiers for the template's scene.
const prisma = new PrismaClient();

const hoursAgo = (h) => new Date(Date.now() - h * 3600 * 1000);
const daysAhead = (d) => new Date(Date.now() + d * 24 * 3600 * 1000);

// Mirror of the curated templates (id -> envelope snapshot used below).
// Every template is a Dinner-scene date; budgets below are Dinner tiers.
const TEMPLATES = {
  japanese: {
    templateId: 'template-japanese-dinner-date',
    sceneTag: 'Dinner',
    area: 'Makati',
    imageUrl:
      'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?auto=format&fit=crop&w=800&h=800&q=80',
  },
  koreanBbq: {
    templateId: 'template-korean-bbq-date',
    sceneTag: 'Dinner',
    area: 'BGC, Taguig',
    imageUrl:
      'https://images.unsplash.com/photo-1590301157890-4810ed352733?auto=format&fit=crop&w=800&h=800&q=80',
  },
  hotpot: {
    templateId: 'template-chinese-hotpot-date',
    sceneTag: 'Dinner',
    area: 'Pasay',
    imageUrl:
      'https://images.unsplash.com/photo-1541529086526-db283c563270?auto=format&fit=crop&w=800&h=800&q=80',
  },
  steak: {
    templateId: 'template-western-steak-date',
    sceneTag: 'Dinner',
    area: 'Makati',
    imageUrl:
      'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=800&h=800&q=80',
  },
};

const POSTS = [
  {
    id: 'post-001',
    authorId: 'user-101',
    type: 'DEMAND',
    ...TEMPLATES.koreanBbq,
    scheduledAt: daysAhead(2),
    title: 'KBBQ night with zero decisions by me',
    description: 'You handle the grill and the conversation pacing',
    detail:
      'I have been in Manila three months and only know the chain places ' +
      'near my office. Looking for a host who can make a High Street ' +
      'KBBQ evening feel effortless. Weekend works best.',
    feeMinor: 100000,
    createdAt: hoursAgo(1),
  },
  {
    id: 'post-002',
    authorId: 'user-102',
    type: 'DEMAND',
    ...TEMPLATES.steak,
    scheduledAt: daysAhead(3),
    title: 'Steak dinner then a lazy mall walk',
    description: 'Good food, good conversation, you handle the pacing',
    detail:
      'I eat out a lot but keep going back to the same two places. Want a ' +
      'host who makes the evening easy: dinner first, then a slow walk ' +
      'through the mall. Weeknights after 7 work best.',
    feeMinor: 150000,
    createdAt: hoursAgo(3),
  },
  {
    // Seeded as an in-progress activity: Liza is selected and the escrow
    // order is ACTIVE, so attribution lines have real content.
    id: 'post-003',
    authorId: 'user-103',
    type: 'DEMAND',
    ...TEMPLATES.hotpot,
    scheduledAt: daysAhead(1),
    status: 'MATCHED',
    title: 'Hotpot night with an actual plan',
    description: 'You order, I just show up and talk',
    detail:
      'I love hotpot but hate deciding. Looking for a host to make the ' +
      'whole evening effortless: the broth, the sides, the pacing. ' +
      'Saturday evening preferred.',
    feeMinor: 250000,
    createdAt: hoursAgo(24),
  },
  {
    id: 'post-004',
    authorId: 'user-100',
    type: 'DEMAND',
    ...TEMPLATES.japanese,
    scheduledAt: daysAhead(5),
    title: 'Slow Sunday: sushi and no agenda',
    description: 'Need someone to make a lazy evening feel planned',
    detail:
      'Work ate my whole month. I want one easy Japanese dinner: good ' +
      'sushi, easy conversation, zero decisions made by me. Host handles ' +
      'the vibe, I just show up.',
    feeMinor: 100000,
    createdAt: hoursAgo(48),
  },
];

// Hosts already signed up on the open posts, so candidate pools have real
// content. Applications carry nothing: the activity is fixed by the
// template and the post; selection is purely about the person.
const APPLICATIONS = [
  { id: 'app-001', postId: 'post-001', applicantId: 'host-204' },
  { id: 'app-002', postId: 'post-001', applicantId: 'host-201' },
  { id: 'app-003', postId: 'post-002', applicantId: 'host-202' },
  {
    id: 'app-004',
    postId: 'post-003',
    applicantId: 'host-203',
    status: 'SELECTED',
  },
];

// Supply-side activity pitches from hosts: the user home feed. A pitch is
// a service shelf listing — template + the host's rough availability
// window; inviters bring the concrete time and the price tier.
const PROPOSALS = [
  {
    id: 'proposal-001',
    hostId: 'host-205',
    ...TEMPLATES.steak,
    timeSlot: 'EVENING',
    title: 'Steak night sa Glorietta, ako ang pipili ng resto',
    description: 'Masarap na hapunan muna, tapos chill na pasyal — ako ang bahala',
    createdAt: hoursAgo(2),
  },
  {
    id: 'proposal-002',
    hostId: 'host-201',
    ...TEMPLATES.koreanBbq,
    timeSlot: 'ANYTIME',
    title: 'KBBQ sa High Street, ako ang mag-iihaw',
    description: 'Ako ang mag-iihaw, kain ka lang; lakad sa strip pagkatapos',
    createdAt: hoursAgo(5),
  },
  {
    id: 'proposal-003',
    hostId: 'host-202',
    ...TEMPLATES.japanese,
    timeSlot: 'NOON',
    title: 'Dadalhin kita sa paborito kong Japanese sa Little Tokyo',
    description: 'Ako ang oorder, kuwento ka lang; ikot sa paligid pagkatapos',
    createdAt: hoursAgo(9),
  },
  {
    id: 'proposal-004',
    hostId: 'host-203',
    ...TEMPLATES.hotpot,
    timeSlot: 'EVENING',
    title: 'Hotpot sa Haidilao, ako ang bahala sa sawsawan',
    description: 'Ako ang oorder, kain at kuwento ka lang',
    createdAt: hoursAgo(20),
  },
  {
    id: 'proposal-005',
    hostId: 'host-204',
    ...TEMPLATES.koreanBbq,
    timeSlot: 'ANYTIME',
    title: 'Weekend KBBQ sa BGC, ililibot kita sa High Street',
    description: 'Mula sa ihawan hanggang sa strip — makikita mo kung bakit sikat ito',
    createdAt: hoursAgo(30),
  },
  {
    id: 'proposal-006',
    hostId: 'host-203',
    ...TEMPLATES.japanese,
    timeSlot: 'EVENING',
    title: 'Maliit na Japanese resto pagkatapos ng trabaho',
    description: 'Tahimik at hindi matao, bagay sa dahan-dahang kain at kuwentuhan',
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
    planPlace: 'Mall of Asia Haidilao entrance',
    planAt: daysAhead(1),
    planDurationMinutes: 120,
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
