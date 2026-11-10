import { execSync } from 'node:child_process';
import { rmSync } from 'node:fs';
import { ValidationPipe } from '@nestjs/common';
import type { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import type { App } from 'supertest/types';
import { AppModule } from '../src/app.module.js';
import { PrismaService } from '../src/prisma/prisma.service.js';

// Seeded demo cast (see prisma/seed.mjs). USER accounts post and pay;
// HOST accounts sign up to host and earn.
const ANDREA = 'user-100'; // FEMALE, USER
const MIGUEL = 'user-101'; // MALE, USER
const PAOLO = 'user-102'; // MALE, USER
const BIANCA = 'host-201'; // FEMALE, HOST
const KAT = 'host-202'; // FEMALE, HOST
const LIZA = 'host-203'; // FEMALE, HOST
const JAMES = 'host-204'; // MALE, HOST
const NOEL = 'host-205'; // MALE, HOST
const ADMIN = 'admin-1'; // FEMALE, role ADMIN

const TEST_DB_URL = 'file:./test.db';

// Curated Manila templates (see src/posts/activity-templates.ts): the only
// publish path. The template fixes scene, cover, district and meeting
// point; publishers bring words and a concrete meeting time. All four
// curated dates are Dinner-scene, so Dinner tiers price everything.
const STEAK_TEMPLATE = 'template-western-steak-date';
const BBQ_TEMPLATE = 'template-korean-bbq-date';
const HOTPOT_TEMPLATE = 'template-chinese-hotpot-date';
const STEAK_MEETING_POINT = 'Glorietta Mall 主入口';
const HOTPOT_MEETING_POINT = 'Mall of Asia 海底捞门口';

// Every activity runs the platform-standard duration.
const UNIFORM_DURATION_MINUTES = 120;

// A concrete meeting time a week out at 14:00 Manila (06:00 UTC) — well
// inside the host working window — reused across publishes.
const MEET_AT = (() => {
  const d = new Date(Date.now() + 7 * 24 * 3600 * 1000);
  d.setUTCHours(6, 0, 0, 0);
  return d.toISOString();
})();
// 23:00 Manila (15:00 UTC): past the host closing time of 22:00.
const MEET_AT_LATE_NIGHT = (() => {
  const d = new Date(Date.now() + 7 * 24 * 3600 * 1000);
  d.setUTCHours(15, 0, 0, 0);
  return d.toISOString();
})();
// 21:00 Manila (13:00 UTC): inside working hours, but the 2h activity
// would end at 23:00, after closing — still rejected.
const MEET_AT_TOO_LATE_TO_FINISH = (() => {
  const d = new Date(Date.now() + 7 * 24 * 3600 * 1000);
  d.setUTCHours(13, 0, 0, 0);
  return d.toISOString();
})();

describe('Meeto API (e2e)', () => {
  let app: INestApplication<App>;
  let prisma: PrismaService;

  beforeAll(async () => {
    process.env.DATABASE_URL = TEST_DB_URL;
    const env = { ...process.env, DATABASE_URL: TEST_DB_URL };
    // Fresh throwaway DB per run (SQLite file lives next to schema.prisma).
    rmSync('prisma/test.db', { force: true });
    execSync('npx prisma db push --skip-generate', { env });
    execSync('node prisma/seed.mjs', { env });
    // Hall demo content (posts, pitches, applications, escrow order) is
    // test-only: the dev hall starts empty.
    execSync('node prisma/fixtures.e2e.mjs', { env });

    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = moduleRef.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    await app.init();
    prisma = app.get(PrismaService);
  });

  afterAll(async () => {
    await app.close();
  });

  const api = () => request(app.getHttpServer());

  it('serves the public pricing config without auth', async () => {
    const res = await api().get('/config/pricing').expect(200);
    expect(res.body.platformFeeRateBp).toBe(1000);
    expect(res.body.sceneBudgetTiers.Dinner).toEqual([
      100000, 150000, 250000,
    ]);
  });

  it('rejects unauthenticated requests elsewhere', async () => {
    await api().get('/posts').expect(401);
    await api().get('/posts').set('X-User-Id', 'ghost').expect(401);
  });

  describe('auth: OTP login, registration, JWT access', () => {
    const ANDREA_PHONE = '+639170000100';
    const NEW_PHONE = '+639175550123';

    it('issues a dev OTP and logs an existing user in with tokens', async () => {
      const otpRes = await api()
        .post('/auth/otp/request')
        .send({ phone: ANDREA_PHONE })
        .expect(201);
      expect(otpRes.body.devCode).toBe('123456');

      const verifyRes = await api()
        .post('/auth/otp/verify')
        .send({ phone: ANDREA_PHONE, code: '123456' })
        .expect(201);
      expect(verifyRes.body.status).toBe('LOGGED_IN');
      expect(verifyRes.body.user.id).toBe(ANDREA);

      const meRes = await api()
        .get('/users/me')
        .set('Authorization', `Bearer ${verifyRes.body.accessToken}`)
        .expect(200);
      expect(meRes.body.id).toBe(ANDREA);

      const refreshRes = await api()
        .post('/auth/refresh')
        .send({ refreshToken: verifyRes.body.refreshToken })
        .expect(201);
      expect(refreshRes.body.accessToken).toBeTruthy();
    });

    it('rejects a wrong or reused code', async () => {
      await api()
        .post('/auth/otp/request')
        .send({ phone: ANDREA_PHONE })
        .expect(201);
      await api()
        .post('/auth/otp/verify')
        .send({ phone: ANDREA_PHONE, code: '000000' })
        .expect(401);
      await api()
        .post('/auth/otp/verify')
        .send({ phone: ANDREA_PHONE, code: '123456' })
        .expect(201);
      // single-use: the same code cannot verify twice
      await api()
        .post('/auth/otp/verify')
        .send({ phone: ANDREA_PHONE, code: '123456' })
        .expect(401);
    });

    it('registers a new phone with name, gender and role, then authenticates', async () => {
      await api()
        .post('/auth/otp/request')
        .send({ phone: NEW_PHONE })
        .expect(201);
      const verifyRes = await api()
        .post('/auth/otp/verify')
        .send({ phone: NEW_PHONE, code: '123456' })
        .expect(201);
      expect(verifyRes.body.status).toBe('NEEDS_PROFILE');

      // The account role is required and must be USER or HOST.
      await api()
        .post('/auth/register')
        .send({
          registrationToken: verifyRes.body.registrationToken,
          name: 'Isabel',
          gender: 'FEMALE',
        })
        .expect(400);
      await api()
        .post('/auth/register')
        .send({
          registrationToken: verifyRes.body.registrationToken,
          name: 'Isabel',
          gender: 'FEMALE',
          role: 'ADMIN',
        })
        .expect(400);

      const registerRes = await api()
        .post('/auth/register')
        .send({
          registrationToken: verifyRes.body.registrationToken,
          name: 'Isabel',
          gender: 'FEMALE',
          role: 'HOST',
        })
        .expect(201);
      expect(registerRes.body.user.name).toBe('Isabel');
      expect(registerRes.body.user.role).toBe('HOST');

      const meRes = await api()
        .get('/users/me')
        .set('Authorization', `Bearer ${registerRes.body.accessToken}`)
        .expect(200);
      expect(meRes.body.gender).toBe('FEMALE');
      expect(meRes.body.role).toBe('HOST');

      // a garbage registration token is rejected
      await api()
        .post('/auth/register')
        .send({
          registrationToken: 'not-a-token',
          name: 'Mallory',
          gender: 'MALE',
          role: 'USER',
        })
        .expect(401);
    });

    it('rejects malformed bearer tokens', async () => {
      await api()
        .get('/users/me')
        .set('Authorization', 'Bearer not-a-jwt')
        .expect(401);
    });
  });

  describe('verification: mock KYC gates contact-creating actions', () => {
    const PHONE = '+639175559876';
    let bearer: string;

    it('blocks an unverified new user from posting and applying', async () => {
      await api().post('/auth/otp/request').send({ phone: PHONE }).expect(201);
      const verifyRes = await api()
        .post('/auth/otp/verify')
        .send({ phone: PHONE, code: '123456' })
        .expect(201);
      const registerRes = await api()
        .post('/auth/register')
        .send({
          registrationToken: verifyRes.body.registrationToken,
          name: 'Carlos',
          gender: 'MALE',
          role: 'USER',
        })
        .expect(201);
      bearer = registerRes.body.accessToken as string;
      expect(registerRes.body.user.isVerified).toBe(false);

      const postRes = await api()
        .post('/posts')
        .set('Authorization', `Bearer ${bearer}`)
        .send({
          templateId: BBQ_TEMPLATE,
          title: 'Blocked',
          scheduledAt: MEET_AT,
        })
        .expect(403);
      expect(postRes.body.message).toBe('VERIFICATION_REQUIRED');
    });

    it('requires a profile photo before verification can run', async () => {
      // The liveness selfie is matched against the avatar, so verification
      // without an avatar is rejected.
      const res = await api()
        .post('/verification')
        .set('Authorization', `Bearer ${bearer}`)
        .send({ selfieUrl: '/uploads/selfie.jpg' })
        .expect(409);
      expect(res.body.message).toBe('AVATAR_REQUIRED');
    });

    it('approves instantly via the mock provider, then actions work', async () => {
      await api()
        .patch('/users/me')
        .set('Authorization', `Bearer ${bearer}`)
        .send({ avatarUrl: '/uploads/carlos.jpg' })
        .expect(200);

      const res = await api()
        .post('/verification')
        .set('Authorization', `Bearer ${bearer}`)
        .send({ selfieUrl: '/uploads/selfie.jpg' })
        .expect(201);
      expect(res.body.isVerified).toBe(true);

      await api()
        .post('/posts')
        .set('Authorization', `Bearer ${bearer}`)
        .send({
          templateId: BBQ_TEMPLATE,
          title: 'Now allowed',
          scheduledAt: MEET_AT,
        })
        .expect(201);
    });

    it('seeded demo users are pre-verified', async () => {
      const res = await api()
        .get('/users/me')
        .set('X-User-Id', ANDREA)
        .expect(200);
      expect(res.body.isVerified).toBe(true);
    });
  });

  describe('feed: community wall vs host gig hall', () => {
    it('the default wall carries sharing posts only', async () => {
      // Demand posts never show on the community wall; it is the shared
      // sharing surface for both roles. The wall is pure UGC (nothing is
      // seeded), so post one moment to light it up.
      await api()
        .post('/posts')
        .set('X-User-Id', ANDREA)
        .send({
          templateId: BBQ_TEMPLATE,
          title: 'Cafe hopping in Makati',
          scheduledAt: MEET_AT,
        })
        .expect(201);
      await api()
        .post('/posts/moments')
        .set('X-User-Id', ANDREA)
        .send({
          text: 'Slow sunday recap',
          images: ['/uploads/recap-wall.jpg'],
          venue: 'A quiet bookshop cafe',
        })
        .expect(201);

      const wall = await api()
        .get('/posts')
        .set('X-User-Id', MIGUEL)
        .expect(200);
      expect(wall.body.length).toBeGreaterThan(0);
      for (const post of wall.body) {
        expect(post.type).toBe('MOMENT');
      }
    });

    it('the requests view lists demands in every live status, to every caller', async () => {
      // Seed posts are male- and female-authored; neutrality must be
      // observable in both directions.
      const hostView = await api()
        .get('/posts?view=requests')
        .set('X-User-Id', JAMES)
        .expect(200);
      const genders = new Set(
        hostView.body.map(
          (p: { author: { gender: string } }) => p.author.gender,
        ),
      );
      expect(genders.has('FEMALE')).toBe(true);
      expect(genders.has('MALE')).toBe(true);

      // Demand posts stay listed through selection, payment, and
      // completion; only cancelled posts drop out. Moments stay out.
      for (const post of hostView.body) {
        expect(post.type).toBe('DEMAND');
        expect(post.status).not.toBe('CANCELLED');
      }
      // The seeded MATCHED movie night stays visible with its host.
      const matched = hostView.body.find(
        (p: { id: string }) => p.id === 'post-003',
      );
      expect(matched).toBeDefined();
      expect(matched.status).toBe('MATCHED');
      const open = hostView.body.find(
        (p: { id: string }) => p.id === 'post-001',
      );
      expect(open).toBeDefined();
      expect(open.selectedHost).toBeNull();

      // Cancelled posts leave the requests view.
      const gone = await api()
        .post('/posts')
        .set('X-User-Id', MIGUEL)
        .send({
          templateId: STEAK_TEMPLATE,
          title: 'Cancelled leaves the hall',
          scheduledAt: MEET_AT,
        })
        .expect(201);
      await api()
        .delete(`/posts/${gone.body.id}`)
        .set('X-User-Id', MIGUEL)
        .expect(200);
      const after = await api()
        .get('/posts?view=requests')
        .set('X-User-Id', NOEL)
        .expect(200);
      expect(
        after.body.find((p: { id: string }) => p.id === gone.body.id),
      ).toBeUndefined();
    });

    it('the author view keeps every status with host attribution', async () => {
      // The seeded movie night is MATCHED with Liza's plan selected: it
      // left the public surfaces but the poster still sees it, attributed.
      const own = await api()
        .get('/posts?authorId=user-103')
        .set('X-User-Id', 'user-103')
        .expect(200);
      const matched = own.body.find(
        (p: { id: string }) => p.id === 'post-003',
      );
      expect(matched).toBeDefined();
      expect(matched.status).toBe('MATCHED');
      expect(matched.selectedHost.id).toBe(LIZA);
    });

    it('the author filter still returns own posts regardless of gender', async () => {
      const res = await api()
        .get(`/posts?authorId=${ANDREA}`)
        .set('X-User-Id', ANDREA)
        .expect(200);
      expect(res.body.length).toBeGreaterThan(0);
      for (const post of res.body) {
        expect(post.author.id).toBe(ANDREA);
      }
    });

    it('the poster picks a platform tier; free pricing is rejected', async () => {
      // Low Dinner tier picked explicitly.
      const low = await api()
        .post('/posts')
        .set('X-User-Id', ANDREA)
        .send({
          templateId: STEAK_TEMPLATE,
          title: 'Dinner on the starter tier',
          scheduledAt: MEET_AT,
          budgetMinor: 100000,
        })
        .expect(201);
      expect(low.body.feeMinor).toBe(100000);

      // An amount outside the scene's tier list is rejected: the platform
      // prices, the poster only picks.
      const rejected = await api()
        .post('/posts')
        .set('X-User-Id', ANDREA)
        .send({
          templateId: STEAK_TEMPLATE,
          title: 'Free-priced dinner',
          scheduledAt: MEET_AT,
          budgetMinor: 123456,
        })
        .expect(400);
      expect(rejected.body.message).toBe('INVALID_BUDGET');

      // Clean up so the hall stays predictable for later tests.
      await api()
        .delete(`/posts/${low.body.id}`)
        .set('X-User-Id', ANDREA)
        .expect(200);
    });

    it('the template envelope rides the post into the hall', async () => {
      // Publish from a template: scene, cover, district and meeting point
      // all come from the template; the poster only picks the time.
      const created = await api()
        .post('/posts')
        .set('X-User-Id', ANDREA)
        .send({
          templateId: BBQ_TEMPLATE,
          title: 'KBBQ run with zero decisions by me',
          scheduledAt: MEET_AT,
        })
        .expect(201);
      expect(created.body.templateId).toBe(BBQ_TEMPLATE);
      expect(created.body.scheduledAt).toBe(MEET_AT);
      expect(created.body.sceneTag).toBe('Dinner');
      expect(created.body.area).toBe('BGC, Taguig');
      expect(created.body.venueName).toBe('Bonifacio High Street');
      expect(created.body.meetingPoint).toContain('High Street');
      expect(created.body.durationLabel).toBeTruthy();
      expect(created.body.imageUrl).toContain('https://');

      const hall = await api()
        .get('/posts?view=requests')
        .set('X-User-Id', NOEL)
        .expect(200);
      const seen = hall.body.find(
        (p: { id: string }) => p.id === created.body.id,
      );
      expect(seen.scheduledAt).toBe(MEET_AT);
      expect(seen.area).toBe('BGC, Taguig');

      // Publishing off-template is impossible: an unknown template is a
      // 404 and a missing meeting time a 400.
      await api()
        .post('/posts')
        .set('X-User-Id', ANDREA)
        .send({
          templateId: 'template-free-form',
          title: 'No such template',
          scheduledAt: MEET_AT,
        })
        .expect(404);
      await api()
        .post('/posts')
        .set('X-User-Id', ANDREA)
        .send({ templateId: BBQ_TEMPLATE, title: 'No time picked' })
        .expect(400);
    });

    it('rejects meeting times outside the host working window', async () => {
      // Hosts clock out at 22:00 Manila: a 23:00 meet is plainly out...
      await api()
        .post('/posts')
        .set('X-User-Id', ANDREA)
        .send({
          templateId: BBQ_TEMPLATE,
          title: 'Night owl coffee',
          scheduledAt: MEET_AT_LATE_NIGHT,
        })
        .expect(400);
      // ...and a 21:00 start is too: the standard 2h run would end at
      // 23:00, past closing.
      await api()
        .post('/posts')
        .set('X-User-Id', ANDREA)
        .send({
          templateId: BBQ_TEMPLATE,
          title: 'Too late to finish',
          scheduledAt: MEET_AT_TOO_LATE_TO_FINISH,
        })
        .expect(400);
      // The same guard covers the pitch side, where the INVITER picks the
      // time: out-of-hours invites bounce, and so do invites outside the
      // pitch's declared availability window.
      const pitch = await api()
        .post('/proposals')
        .set('X-User-Id', KAT)
        .send({
          templateId: BBQ_TEMPLATE,
          title: 'Evening BBQ availability',
          timeSlot: 'EVENING',
        })
        .expect(201);
      await api()
        .post(`/proposals/${pitch.body.id}/invitations`)
        .set('X-User-Id', ANDREA)
        .send({ scheduledAt: MEET_AT_LATE_NIGHT, note: 'night owl' })
        .expect(400);
      // MEET_AT is 14:00 Manila: inside working hours but outside the
      // EVENING window (17:00-20:00 starts).
      const outsideSlot = await api()
        .post(`/proposals/${pitch.body.id}/invitations`)
        .set('X-User-Id', ANDREA)
        .send({ scheduledAt: MEET_AT, note: 'noon on an evening pitch' })
        .expect(400);
      expect(outsideSlot.body.message).toBe('MEET_TIME_OUTSIDE_SLOT');
    });
  });

  describe('templates: the curated activity shelf', () => {
    it('serves the operations-curated list to both roles', async () => {
      const asUser = await api()
        .get('/templates')
        .set('X-User-Id', ANDREA)
        .expect(200);
      expect(asUser.body.length).toBeGreaterThanOrEqual(3);
      for (const template of asUser.body) {
        expect(template.id).toContain('template-');
        expect(template.sceneTag).toBeTruthy();
        expect(template.title).toBeTruthy();
        expect(template.imageUrl).toContain('https://');
        expect(template.durationLabel).toBeTruthy();
        expect(template.venueName).toBeTruthy();
        expect(template.meetingPoint).toBeTruthy();
        expect(template.area).toBeTruthy();
      }

      const asHost = await api()
        .get('/templates')
        .set('X-User-Id', NOEL)
        .expect(200);
      expect(asHost.body).toEqual(asUser.body);

      await api().get('/templates').expect(401);
    });
  });

  describe('signup visibility and the select-pay-cancel flow', () => {
    let postId: string;
    let orderId: string;

    it('signups are visible role-trimmed; there is no notification feed', async () => {
      const postRes = await api()
        .post('/posts')
        .set('X-User-Id', ANDREA)
        .send({
          templateId: HOTPOT_TEMPLATE,
          title: 'Signup visibility flow',
          scheduledAt: MEET_AT,
        })
        .expect(201);
      postId = postRes.body.id;

      // One-tap sign-up: no body, the plan is fixed by the template.
      await api()
        .post(`/posts/${postId}/applications`)
        .set('X-User-Id', NOEL)
        .expect(201);

      // Notifications are gone on purpose: every state lives on a surface
      // (post detail, orders, chat), so the feed endpoints no longer exist.
      await api()
        .get('/notifications')
        .set('X-User-Id', ANDREA)
        .expect(404);

      // The applicant finds the pending signup on their activity board
      // (view=applied); hosts who did not sign see nothing there.
      const applied = await api()
        .get('/posts?view=applied')
        .set('X-User-Id', NOEL)
        .expect(200);
      expect(
        applied.body.find((p: { id: string }) => p.id === postId),
      ).toBeDefined();
      const notApplied = await api()
        .get('/posts?view=applied')
        .set('X-User-Id', JAMES)
        .expect(200);
      expect(
        notApplied.body.find((p: { id: string }) => p.id === postId),
      ).toBeUndefined();

      // Non-owners see anonymous interest on the post: a count plus
      // avatar URLs only, never names or ids.
      const asHost = await api()
        .get(`/posts/${postId}`)
        .set('X-User-Id', NOEL)
        .expect(200);
      expect(asHost.body.applicantCount).toBe(1);
      expect(asHost.body.applicantAvatars).toHaveLength(1);
      expect(typeof asHost.body.applicantAvatars[0]).toBe('string');

      const asUser = await api()
        .get(`/posts/${postId}`)
        .set('X-User-Id', MIGUEL)
        .expect(200);
      expect(asUser.body.applicantAvatars).toHaveLength(1);

      // The owner needs no trimmed view: the full pool lives on the
      // owner-only applications endpoint.
      const asOwner = await api()
        .get(`/posts/${postId}`)
        .set('X-User-Id', ANDREA)
        .expect(200);
      expect(asOwner.body.applicantAvatars).toEqual([]);
    });

    it('the pending signup reaches the owner via the notice feed', async () => {
      // Stateless replacement for the dropped notifications table: the
      // owner polls pending sign-ups on everything they published and the
      // client diffs against a local last-seen timestamp.
      const notices = await api()
        .get('/posts/signups/notice')
        .set('X-User-Id', ANDREA)
        .expect(200);
      const mine = notices.body.find(
        (n: { targetId: string }) => n.targetId === postId,
      );
      expect(mine).toBeDefined();
      expect(mine.kind).toBe('APPLICATION');
      expect(mine.actor.id).toBe(NOEL);
      expect(typeof mine.actor.avatarUrl).toBe('string');

      // The candidate themselves has nothing pending on their own posts.
      const quiet = await api()
        .get('/posts/signups/notice')
        .set('X-User-Id', NOEL)
        .expect(200);
      expect(
        quiet.body.find((n: { targetId: string }) => n.targetId === postId),
      ).toBeUndefined();
    });

    it('selection creates an awaiting-payment order for the candidate', async () => {
      const pool = await api()
        .get(`/posts/${postId}/applications`)
        .set('X-User-Id', ANDREA)
        .expect(200);
      const orderRes = await api()
        .post(`/posts/${postId}/selection`)
        .set('X-User-Id', ANDREA)
        .send({ applicationId: pool.body[0].id })
        .expect(201);
      orderId = orderRes.body.id;
      expect(orderRes.body.status).toBe('AWAITING_PAYMENT');
      // Nobody has opened the fresh room yet; the deal-notice bar keys
      // off this flag to nudge the earner into the new chat.
      expect(orderRes.body.viewerEnteredRoom).toBe(false);

      // Selection closes the post, so the sign-up stops being actionable
      // and drops off the notice feed.
      const notices = await api()
        .get('/posts/signups/notice')
        .set('X-User-Id', ANDREA)
        .expect(200);
      expect(
        notices.body.find((n: { targetId: string }) => n.targetId === postId),
      ).toBeUndefined();
    });

    it('payment activates the order', async () => {
      // New rule: the poster (Andrea) pays, the selected host (Noel) earns.
      const paid = await api()
        .post(`/orders/${orderId}/payment`)
        .set('X-User-Id', ANDREA)
        .expect(201);
      expect(paid.body.status).toBe('ACTIVE');
    });

    it('cancelling closes the order', async () => {
      const cancelled = await api()
        .post(`/orders/${orderId}/cancel`)
        .set('X-User-Id', ANDREA)
        .expect(201);
      expect(cancelled.body.status).toBe('CANCELLED');
    });
  });

  describe('profile: update, photo upload, real aggregates', () => {
    it('updates profile fields and derives the display meta', async () => {
      const res = await api()
        .patch('/users/me')
        .set('X-User-Id', ANDREA)
        .send({
          bio: 'Coffee lover, weekend hiker',
          country: 'Philippines',
          city: 'Makati',
          heightCm: 160,
          weightKg: 48,
          photos: ['/uploads/a.jpg', '/uploads/b.jpg'],
        })
        .expect(200);
      // Age is derived from the seeded birth date (24 at seed time).
      expect(res.body.meta).toMatch(/^\u5973 \u00b7 \d{2}$/);
      expect(res.body.country).toBe('Philippines');
      expect(res.body.city).toBe('Makati');
      expect(res.body.heightCm).toBe(160);
      expect(res.body.weightKg).toBe(48);
      expect(res.body.photos).toEqual(['/uploads/a.jpg', '/uploads/b.jpg']);

      const viewed = await api()
        .get(`/users/${ANDREA}`)
        .set('X-User-Id', MIGUEL)
        .expect(200);
      expect(viewed.body.bio).toBe('Coffee lover, weekend hiker');
      expect(typeof viewed.body.activitiesCompleted).toBe('number');
    });

    it('sets a birth date once (18+ only) and locks it afterwards', async () => {
      // Fresh account: no birth date yet.
      const phone = '+639175551212';
      await api().post('/auth/otp/request').send({ phone }).expect(201);
      const verify = await api()
        .post('/auth/otp/verify')
        .send({ phone, code: '123456' })
        .expect(201);
      const register = await api()
        .post('/auth/register')
        .send({
          registrationToken: verify.body.registrationToken,
          name: 'Dana',
          gender: 'FEMALE',
          role: 'USER',
        })
        .expect(201);
      const bearer = register.body.accessToken as string;

      const now = new Date();
      const underage = new Date(Date.UTC(now.getFullYear() - 16, 0, 1));
      const underageRes = await api()
        .patch('/users/me')
        .set('Authorization', `Bearer ${bearer}`)
        .send({ birthDate: underage.toISOString() })
        .expect(400);
      expect(underageRes.body.message).toBe('MUST_BE_18_PLUS');

      const adult = new Date(Date.UTC(now.getFullYear() - 25, 0, 1));
      const ok = await api()
        .patch('/users/me')
        .set('Authorization', `Bearer ${bearer}`)
        .send({ birthDate: adult.toISOString() })
        .expect(200);
      expect(ok.body.age).toBe(25);

      // Locked after the first set.
      const locked = await api()
        .patch('/users/me')
        .set('Authorization', `Bearer ${bearer}`)
        .send({ birthDate: adult.toISOString() })
        .expect(400);
      expect(locked.body.message).toBe('BIRTH_DATE_LOCKED');
    });

    it('accepts an image upload and returns a served URL', async () => {
      const res = await api()
        .post('/uploads')
        .set('X-User-Id', ANDREA)
        .attach('file', Buffer.from([0xff, 0xd8, 0xff, 0xdb, 0x00]), {
          filename: 'avatar.jpg',
          contentType: 'image/jpeg',
        })
        .expect(201);
      expect(res.body.url).toMatch(/^\/uploads\/.+\.jpg$/);
    });

    it('rejects non-image uploads', async () => {
      await api()
        .post('/uploads')
        .set('X-User-Id', ANDREA)
        .attach('file', Buffer.from('plain text'), {
          filename: 'notes.txt',
          contentType: 'text/plain',
        })
        .expect(400);
    });
  });

  describe('happy path: poster pays, selected host earns, settlement', () => {
    let postId: string;
    let jamesApplicationId: string;
    let orderId: string;

    it('Andrea publishes a Dinner post with the platform fee snapshot', async () => {
      const res = await api()
        .post('/posts')
        .set('X-User-Id', ANDREA)
        .send({
          templateId: STEAK_TEMPLATE,
          title: 'Dinner then a mall walk downtown',
          scheduledAt: MEET_AT,
        })
        .expect(201);
      postId = res.body.id;
      // No explicit tier pick -> the middle Dinner tier.
      expect(res.body.feeMinor).toBe(150000);
      expect(res.body.status).toBe('OPEN');
      // The post is fully scheduled at publish: template meeting point
      // plus the picked time.
      expect(res.body.scheduledAt).toBe(MEET_AT);
      expect(res.body.meetingPoint).toBe(STEAK_MEETING_POINT);
    });

    it('candidates of any gender sign up for free; invalid sign-ups are rejected', async () => {
      const jamesRes = await api()
        .post(`/posts/${postId}/applications`)
        .set('X-User-Id', JAMES)
        .expect(201);
      jamesApplicationId = jamesRes.body.id;
      await api()
        .post(`/posts/${postId}/applications`)
        .set('X-User-Id', NOEL)
        .expect(201);
      // Same-gender sign-up is allowed: the marketplace is gender-neutral.
      await api()
        .post(`/posts/${postId}/applications`)
        .set('X-User-Id', BIANCA)
        .expect(201);

      // Only hosts can sign up; users invite hosts instead.
      await api()
        .post(`/posts/${postId}/applications`)
        .set('X-User-Id', MIGUEL)
        .expect(403);
      // Duplicate sign-up rejected.
      await api()
        .post(`/posts/${postId}/applications`)
        .set('X-User-Id', JAMES)
        .expect(409);
    });

    it('only the author sees the candidate pool', async () => {
      await api()
        .get(`/posts/${postId}/applications`)
        .set('X-User-Id', JAMES)
        .expect(403);
      const res = await api()
        .get(`/posts/${postId}/applications`)
        .set('X-User-Id', ANDREA)
        .expect(200);
      expect(res.body).toHaveLength(3);
      // Applications carry only the person: the activity is fixed by the
      // template, so selection is purely about who hosts it.
      expect(res.body[0].applicant.id).toBe(JAMES);
      expect(res.body[0].status).toBe('APPLIED');
    });

    it('selection creates an order where the poster pays the host', async () => {
      const res = await api()
        .post(`/posts/${postId}/selection`)
        .set('X-User-Id', ANDREA)
        .send({ applicationId: jamesApplicationId })
        .expect(201);
      orderId = res.body.id;
      expect(res.body.status).toBe('AWAITING_PAYMENT');
      expect(res.body.payer.id).toBe(ANDREA);
      expect(res.body.earner.id).toBe(JAMES);
      // 10% commission, exact remainder to the earner.
      expect(res.body.feeMinor).toBe(150000);
      expect(res.body.commissionMinor).toBe(15000);
      expect(res.body.netMinor).toBe(135000);

      const post = await api()
        .get(`/posts/${postId}`)
        .set('X-User-Id', ANDREA)
        .expect(200);
      expect(post.body.status).toBe('PENDING_PAYMENT');
    });

    it('only the payer can escrow; payment activates the order', async () => {
      // The paywall: no chat before the fee is escrowed.
      await api()
        .post(`/orders/${orderId}/messages`)
        .set('X-User-Id', JAMES)
        .send({ text: 'hi before paying' })
        .expect(409);

      // The earner (host) cannot pay; only the poster can.
      await api()
        .post(`/orders/${orderId}/payment`)
        .set('X-User-Id', JAMES)
        .expect(403);
      const res = await api()
        .post(`/orders/${orderId}/payment`)
        .set('X-User-Id', ANDREA)
        .expect(201);
      expect(res.body.status).toBe('ACTIVE');

      // Escrowed money is the anti-bypass mechanism: the moment the
      // payment lands, both sides chat freely.
      await api()
        .post(`/orders/${orderId}/messages`)
        .set('X-User-Id', ANDREA)
        .send({ text: 'hi right after paying' })
        .expect(201);
      // Double payment rejected.
      await api()
        .post(`/orders/${orderId}/payment`)
        .set('X-User-Id', ANDREA)
        .expect(409);
      // Escrow holds exactly the fee.
      const escrow = await prisma.ledgerEntry.aggregate({
        where: { account: 'PLATFORM_ESCROW', orderId },
        _sum: { amountMinor: true },
      });
      expect(escrow._sum.amountMinor).toBe(150000);
    });

    it('selection locked the template plan; no plan flow in chat', async () => {
      // The plan is the template meeting point plus the post's time,
      // locked at publish: place and time are already effective.
      const current = await api()
        .get(`/orders/${orderId}`)
        .set('X-User-Id', ANDREA)
        .expect(200);
      expect(current.body.planConfirmedAt).not.toBeNull();
      expect(current.body.place).toBe(STEAK_MEETING_POINT);
      expect(current.body.scheduledAt).toBe(MEET_AT);

      // The locked plan card opened the conversation as a PLAN message
      // carrying the frozen snapshot.
      const opening = await api()
        .get(`/orders/${orderId}/messages`)
        .set('X-User-Id', ANDREA)
        .expect(200);
      expect(opening.body[0].kind).toBe('PLAN');
      expect(JSON.parse(opening.body[0].text)).toEqual({
        place: STEAK_MEETING_POINT,
        scheduledAt: MEET_AT,
        note: '',
        durationMinutes: UNIFORM_DURATION_MINUTES,
      });

      // The in-chat plan machinery is gone: the plan was settled at the
      // deal moment, so these routes no longer exist.
      await api()
        .post(`/orders/${orderId}/plan`)
        .set('X-User-Id', JAMES)
        .send({
          place: 'Single Origin, Makati',
          scheduledAt: '2026-12-24T19:00:00.000Z',
          note: 'Hand brew flight, then a walk in the park',
          durationMinutes: 150,
        })
        .expect(404);
      await api()
        .post(`/orders/${orderId}/plan/confirm`)
        .set('X-User-Id', ANDREA)
        .expect(404);
    });

    it('matched parties exchange order messages; outsiders cannot', async () => {
      const sendRes = await api()
        .post(`/orders/${orderId}/messages`)
        .set('X-User-Id', JAMES)
        .send({ text: 'See you at 7!' })
        .expect(201);
      await api()
        .post(`/orders/${orderId}/messages`)
        .set('X-User-Id', ANDREA)
        .send({ text: 'Looking forward to it' })
        .expect(201);
      // outsider blocked from both directions
      await api()
        .post(`/orders/${orderId}/messages`)
        .set('X-User-Id', NOEL)
        .send({ text: 'hi' })
        .expect(403);
      await api()
        .get(`/orders/${orderId}/messages`)
        .set('X-User-Id', NOEL)
        .expect(403);

      const allRes = await api()
        .get(`/orders/${orderId}/messages`)
        .set('X-User-Id', ANDREA)
        .expect(200);
      // The stream: sign-up plan card, the post-payment hello, then this
      // exchange — exactly one plan card, locked at selection.
      expect(allRes.body.length).toBe(4);
      expect(allRes.body[0].kind).toBe('PLAN');
      expect(allRes.body[1].text).toBe('hi right after paying');
      expect(allRes.body[2].text).toBe('See you at 7!');

      // incremental poll: only messages after the anchor id
      const afterRes = await api()
        .get(`/orders/${orderId}/messages`)
        .query({ afterId: sendRes.body.id })
        .set('X-User-Id', JAMES)
        .expect(200);
      expect(afterRes.body.length).toBe(1);
      expect(afterRes.body[0].text).toBe('Looking forward to it');
    });

    it('phones are disclosed to the participants after escrow', async () => {
      const order = await api()
        .get(`/orders/${orderId}`)
        .set('X-User-Id', JAMES)
        .expect(200);
      expect(order.body.payerPhone).toMatch(/^\+63/);
      expect(order.body.earnerPhone).toMatch(/^\+63/);
    });

    it('the host submits the meet code; the run ends and the escrow settles', async () => {
      // The 4-digit proof-of-meeting code is disclosed only to the payer.
      const mine = await api()
        .get(`/orders/${orderId}`)
        .set('X-User-Id', ANDREA)
        .expect(200);
      expect(mine.body.meetCode).toMatch(/^\d{4}$/);
      const hostView = await api()
        .get(`/orders/${orderId}`)
        .set('X-User-Id', JAMES)
        .expect(200);
      expect(hostView.body.meetCode).toBe('');

      // Only the host submits the code; a wrong code bounces.
      await api()
        .post(`/orders/${orderId}/start`)
        .set('X-User-Id', ANDREA)
        .send({ code: mine.body.meetCode })
        .expect(403);
      const wrongCode = mine.body.meetCode === '0000' ? '0001' : '0000';
      const rejected = await api()
        .post(`/orders/${orderId}/start`)
        .set('X-User-Id', JAMES)
        .send({ code: wrongCode })
        .expect(409);
      expect(rejected.body.message).toBe('WRONG_MEET_CODE');

      const started = await api()
        .post(`/orders/${orderId}/start`)
        .set('X-User-Id', JAMES)
        .send({ code: mine.body.meetCode })
        .expect(201);
      expect(started.body.status).toBe('ACTIVE');
      expect(started.body.startedAt).not.toBeNull();

      // A started service can never be cancelled (even inside the cancel
      // window) and never started twice.
      const locked = await api()
        .post(`/orders/${orderId}/cancel`)
        .set('X-User-Id', ANDREA)
        .expect(409);
      expect(locked.body.message).toBe('ALREADY_STARTED');
      await api()
        .post(`/orders/${orderId}/start`)
        .set('X-User-Id', JAMES)
        .send({ code: mine.body.meetCode })
        .expect(409);

      // The planned duration runs out -> the escrow settles lazily on the
      // next read; nobody taps anything.
      process.env.AUTO_SETTLE_DELAY_MS = '0';
      const done = await api()
        .get(`/orders/${orderId}`)
        .set('X-User-Id', ANDREA)
        .expect(200);
      delete process.env.AUTO_SETTLE_DELAY_MS;
      expect(done.body.status).toBe('COMPLETED');
      expect(done.body.completedAt).not.toBeNull();

      // A completed order can no longer be cancelled or restarted.
      await api()
        .post(`/orders/${orderId}/cancel`)
        .set('X-User-Id', JAMES)
        .expect(409);
      await api()
        .post(`/orders/${orderId}/start`)
        .set('X-User-Id', JAMES)
        .send({ code: mine.body.meetCode })
        .expect(409);

      // The conversation OUTLIVES the activity: people who met keep the
      // channel, so rebooking a known host starts right here.
      await api()
        .post(`/orders/${orderId}/messages`)
        .set('X-User-Id', ANDREA)
        .send({ text: 'that was fun — next time hotpot?' })
        .expect(201);
      const history = await api()
        .get(`/orders/${orderId}/messages`)
        .set('X-User-Id', JAMES)
        .expect(200);
      expect(history.body.length).toBeGreaterThan(0);

      // Balanced books: escrow emptied, earner paid net, platform booked
      // the commission.
      const escrow = await prisma.ledgerEntry.aggregate({
        where: { account: 'PLATFORM_ESCROW', orderId },
        _sum: { amountMinor: true },
      });
      expect(escrow._sum.amountMinor).toBe(0);
      const revenue = await prisma.ledgerEntry.aggregate({
        where: { account: 'PLATFORM_REVENUE', orderId },
        _sum: { amountMinor: true },
      });
      expect(revenue._sum.amountMinor).toBe(15000);
    });

    it('the earner wallet reflects net income and supports withdrawal', async () => {
      const wallet = await api()
        .get('/wallet')
        .set('X-User-Id', JAMES)
        .expect(200);
      expect(wallet.body.balanceMinor).toBe(135000);
      expect(wallet.body.monthIncomeMinor).toBe(135000);

      await api()
        .post('/wallet/withdrawals')
        .set('X-User-Id', JAMES)
        .send({ amountMinor: 5000 })
        .expect(201);
      const after = await api()
        .get('/wallet')
        .set('X-User-Id', JAMES)
        .expect(200);
      expect(after.body.balanceMinor).toBe(130000);

      // Overdraft rejected.
      await api()
        .post('/wallet/withdrawals')
        .set('X-User-Id', JAMES)
        .send({ amountMinor: 140000 })
        .expect(409);
    });

    it('admin sees all orders; regular users do not', async () => {
      await api().get('/admin/orders').set('X-User-Id', ANDREA).expect(403);
      const res = await api()
        .get('/admin/orders')
        .set('X-User-Id', ADMIN)
        .expect(200);
      expect(
        res.body.some(
          (o: { id: string; status: string }) =>
            o.id === orderId && o.status === 'COMPLETED',
        ),
      ).toBe(true);
    });

    it('a settled chat carries a rebooking card that forms a new deal', async () => {
      // Only the payer sends request cards; the host answers them.
      await api()
        .post(`/orders/${orderId}/messages/request`)
        .set('X-User-Id', JAMES)
        .send({ templateId: HOTPOT_TEMPLATE, scheduledAt: MEET_AT })
        .expect(403);
      // The same rails as everywhere else: template-only, host working
      // hours, platform price tiers.
      await api()
        .post(`/orders/${orderId}/messages/request`)
        .set('X-User-Id', ANDREA)
        .send({ templateId: 'template-anything-goes', scheduledAt: MEET_AT })
        .expect(404);
      await api()
        .post(`/orders/${orderId}/messages/request`)
        .set('X-User-Id', ANDREA)
        .send({ templateId: HOTPOT_TEMPLATE, scheduledAt: MEET_AT_LATE_NIGHT })
        .expect(400);
      const freePrice = await api()
        .post(`/orders/${orderId}/messages/request`)
        .set('X-User-Id', ANDREA)
        .send({
          templateId: HOTPOT_TEMPLATE,
          scheduledAt: MEET_AT,
          budgetMinor: 99,
        })
        .expect(400);
      expect(freePrice.body.message).toBe('INVALID_BUDGET');

      const card = await api()
        .post(`/orders/${orderId}/messages/request`)
        .set('X-User-Id', ANDREA)
        .send({
          templateId: HOTPOT_TEMPLATE,
          scheduledAt: MEET_AT,
          budgetMinor: 250000,
          note: 'Same crew, spicier pot',
        })
        .expect(201);
      expect(card.body.kind).toBe('REQUEST');
      const payload = JSON.parse(card.body.text as string) as {
        status: string;
        budgetMinor: number;
        meetingPoint: string;
      };
      expect(payload.status).toBe('PENDING');
      expect(payload.budgetMinor).toBe(250000);
      expect(payload.meetingPoint).toBe(HOTPOT_MEETING_POINT);

      // One open card per conversation.
      const dup = await api()
        .post(`/orders/${orderId}/messages/request`)
        .set('X-User-Id', ANDREA)
        .send({ templateId: HOTPOT_TEMPLATE, scheduledAt: MEET_AT })
        .expect(409);
      expect(dup.body.message).toBe('REQUEST_ALREADY_PENDING');

      // Only the host answers; accepting creates the whole new deal
      // awaiting the requester's payment, plan locked to the card.
      await api()
        .post(`/orders/${orderId}/messages/${card.body.id}/respond`)
        .set('X-User-Id', ANDREA)
        .send({ accept: true })
        .expect(403);
      const accepted = await api()
        .post(`/orders/${orderId}/messages/${card.body.id}/respond`)
        .set('X-User-Id', JAMES)
        .send({ accept: true })
        .expect(201);
      const acceptedPayload = JSON.parse(accepted.body.text as string) as {
        status: string;
        orderId: string;
      };
      expect(acceptedPayload.status).toBe('ACCEPTED');
      expect(acceptedPayload.orderId).not.toBe('');

      // No double answers.
      const again = await api()
        .post(`/orders/${orderId}/messages/${card.body.id}/respond`)
        .set('X-User-Id', JAMES)
        .send({ accept: false })
        .expect(409);
      expect(again.body.message).toBe('REQUEST_NOT_PENDING');

      const newOrder = await api()
        .get(`/orders/${acceptedPayload.orderId}`)
        .set('X-User-Id', ANDREA)
        .expect(200);
      expect(newOrder.body.status).toBe('AWAITING_PAYMENT');
      expect(newOrder.body.feeMinor).toBe(250000);
      expect(newOrder.body.payer.id).toBe(ANDREA);
      expect(newOrder.body.earner.id).toBe(JAMES);
      expect(newOrder.body.planPlace).toBe(HOTPOT_MEETING_POINT);
      expect(newOrder.body.planAt).toBe(MEET_AT);
      expect(newOrder.body.planDurationMinutes).toBe(
        UNIFORM_DURATION_MINUTES,
      );

      // Paying forms the deal exactly like any other order.
      const paid = await api()
        .post(`/orders/${acceptedPayload.orderId}/payment`)
        .set('X-User-Id', ANDREA)
        .expect(201);
      expect(paid.body.status).toBe('ACTIVE');
    });

    it('conversations group by partner, not by order', async () => {
      // Andrea and James now share TWO deals (the settled original and
      // the rebooked live one) — but the contact list shows ONE row for
      // the partner, opening into the live deal's room.
      const mine = await api()
        .get('/orders/conversations')
        .set('X-User-Id', ANDREA)
        .expect(200);
      const rows = mine.body as {
        peer: { id: string };
        roomOrderId: string;
        hasLiveOrder: boolean;
        lastMessageKind: string;
      }[];
      const withJames = rows.filter((r) => r.peer.id === JAMES);
      expect(withJames.length).toBe(1);
      expect(withJames[0].hasLiveOrder).toBe(true);
      // The room is the live rebooked order, not the settled original.
      expect(withJames[0].roomOrderId).not.toBe(orderId);
      expect(withJames[0].lastMessageKind).not.toBe('');

      // The mirror view: James sees one row for Andrea.
      const theirs = await api()
        .get('/orders/conversations')
        .set('X-User-Id', JAMES)
        .expect(200);
      const withAndrea = (theirs.body as { peer: { id: string } }[]).filter(
        (r) => r.peer.id === ANDREA,
      );
      expect(withAndrea.length).toBe(1);
    });

    it('unread counts rise with partner messages and clear on reading', async () => {
      // James texts into the live room; the message lands past Andrea's
      // read cursor, so her conversation row counts it as unread.
      const mineBefore = await api()
        .get('/orders/conversations')
        .set('X-User-Id', ANDREA)
        .expect(200);
      const before = (
        mineBefore.body as { peer: { id: string }; unreadCount: number }[]
      ).find((r) => r.peer.id === JAMES);
      expect(before).toBeDefined();
      const roomId = (
        mineBefore.body as { peer: { id: string }; roomOrderId: string }[]
      ).find((r) => r.peer.id === JAMES)!.roomOrderId;

      await api()
        .post(`/orders/${roomId}/messages`)
        .set('X-User-Id', JAMES)
        .send({ text: 'See you Friday!' })
        .expect(201);

      const mineAfter = await api()
        .get('/orders/conversations')
        .set('X-User-Id', ANDREA)
        .expect(200);
      const after = (
        mineAfter.body as { peer: { id: string }; unreadCount: number }[]
      ).find((r) => r.peer.id === JAMES)!;
      expect(after.unreadCount).toBe(before!.unreadCount + 1);

      // Own messages never count against the sender: once James catches
      // up on both shared rooms, his row stays clear even though the
      // latest message is his.
      await api()
        .get(`/orders/${orderId}/messages`)
        .set('X-User-Id', JAMES)
        .expect(200);
      await api()
        .get(`/orders/${roomId}/messages`)
        .set('X-User-Id', JAMES)
        .expect(200);
      const theirs = await api()
        .get('/orders/conversations')
        .set('X-User-Id', JAMES)
        .expect(200);
      const jamesRow = (
        theirs.body as { peer: { id: string }; unreadCount: number }[]
      ).find((r) => r.peer.id === ANDREA)!;
      expect(jamesRow.unreadCount).toBe(0);

      // Opening the room (reading the messages) clears the badge.
      await api()
        .get(`/orders/${roomId}/messages`)
        .set('X-User-Id', ANDREA)
        .expect(200);
      const cleared = await api()
        .get('/orders/conversations')
        .set('X-User-Id', ANDREA)
        .expect(200);
      const row = (
        cleared.body as { peer: { id: string }; unreadCount: number }[]
      ).find((r) => r.peer.id === JAMES)!;
      expect(row.unreadCount).toBe(0);
    });

    it('declining a rebooking card only marks the card', async () => {
      const card = await api()
        .post(`/orders/${orderId}/messages/request`)
        .set('X-User-Id', ANDREA)
        .send({ templateId: BBQ_TEMPLATE, scheduledAt: MEET_AT })
        .expect(201);
      const declined = await api()
        .post(`/orders/${orderId}/messages/${card.body.id}/respond`)
        .set('X-User-Id', JAMES)
        .send({ accept: false })
        .expect(201);
      const payload = JSON.parse(declined.body.text as string) as {
        status: string;
        orderId: string;
      };
      expect(payload.status).toBe('DECLINED');
      expect(payload.orderId).toBe('');
      // A declined card frees the slot for a new attempt.
      await api()
        .post(`/orders/${orderId}/messages/request`)
        .set('X-User-Id', ANDREA)
        .send({ templateId: BBQ_TEMPLATE, scheduledAt: MEET_AT })
        .expect(201);
    });
  });

  describe('post deletion (author only, open posts only)', () => {
    it('author deletes an open post; it leaves the feed', async () => {
      const post = await api()
        .post('/posts')
        .set('X-User-Id', MIGUEL)
        .send({
          templateId: BBQ_TEMPLATE,
          title: 'Delete me',
          scheduledAt: MEET_AT,
        })
        .expect(201);

      // Someone applied before deletion.
      await api()
        .post(`/posts/${post.body.id}/applications`)
        .set('X-User-Id', BIANCA)
        .expect(201);

      // Only the author may delete.
      await api()
        .delete(`/posts/${post.body.id}`)
        .set('X-User-Id', BIANCA)
        .expect(403);

      const removed = await api()
        .delete(`/posts/${post.body.id}`)
        .set('X-User-Id', MIGUEL)
        .expect(200);
      expect(removed.body.status).toBe('CANCELLED');

      const requests = await api()
        .get('/posts?view=requests')
        .set('X-User-Id', BIANCA)
        .expect(200);
      expect(
        requests.body.find((p: { id: string }) => p.id === post.body.id),
      ).toBeUndefined();

      // Deleting again conflicts (no longer OPEN).
      await api()
        .delete(`/posts/${post.body.id}`)
        .set('X-User-Id', MIGUEL)
        .expect(409);
    });
  });

  describe('meet code gating: wrong code, no started service', () => {
    it('the right code starts the service; the run settles on read', async () => {
      const post = await api()
        .post('/posts')
        .set('X-User-Id', MIGUEL)
        .send({
          templateId: STEAK_TEMPLATE,
          title: 'Meet code flow',
          scheduledAt: MEET_AT,
        })
        .expect(201);
      await api()
        .post(`/posts/${post.body.id}/applications`)
        .set('X-User-Id', KAT)
        .expect(201);
      const pool = await api()
        .get(`/posts/${post.body.id}/applications`)
        .set('X-User-Id', MIGUEL)
        .expect(200);
      const order = await api()
        .post(`/posts/${post.body.id}/selection`)
        .set('X-User-Id', MIGUEL)
        .send({ applicationId: pool.body[0].id })
        .expect(201);
      const orderId = order.body.id;
      // The selection response goes to the payer: the code rides along.
      expect(order.body.meetCode).toMatch(/^\d{4}$/);
      const code = order.body.meetCode as string;

      await api()
        .post(`/orders/${orderId}/payment`)
        .set('X-User-Id', MIGUEL)
        .expect(201);

      // The plan was locked at selection; the only gate left is the code
      // itself.
      const blocked = await api()
        .post(`/orders/${orderId}/start`)
        .set('X-User-Id', KAT)
        .send({ code: code === '0000' ? '1111' : '0000' })
        .expect(409);
      expect(blocked.body.message).toBe('WRONG_MEET_CODE');

      await api()
        .post(`/orders/${orderId}/start`)
        .set('X-User-Id', KAT)
        .send({ code })
        .expect(201);

      // Duration elapsed (test clock: zero) -> settled on the next read.
      process.env.AUTO_SETTLE_DELAY_MS = '0';
      const settled = await api()
        .get(`/orders/${orderId}`)
        .set('X-User-Id', KAT)
        .expect(200);
      delete process.env.AUTO_SETTLE_DELAY_MS;
      expect(settled.body.status).toBe('COMPLETED');
      expect(settled.body.completedAt).not.toBeNull();

      // Escrow emptied into net payout + commission for this order too.
      const escrow = await prisma.ledgerEntry.aggregate({
        where: { account: 'PLATFORM_ESCROW', orderId },
        _sum: { amountMinor: true },
      });
      expect(escrow._sum.amountMinor).toBe(0);
    });
  });

  describe('cancellation: full refund, post reopens', () => {
    let postId: string;
    let orderId: string;

    it('the poster selects a candidate and escrows', async () => {
      const post = await api()
        .post('/posts')
        .set('X-User-Id', MIGUEL)
        .send({
          templateId: BBQ_TEMPLATE,
          title: 'Coffee date',
          scheduledAt: MEET_AT,
        })
        .expect(201);
      postId = post.body.id;

      const application = await api()
        .post(`/posts/${postId}/applications`)
        .set('X-User-Id', BIANCA)
        .expect(201);
      const selection = await api()
        .post(`/posts/${postId}/selection`)
        .set('X-User-Id', MIGUEL)
        .send({ applicationId: application.body.id })
        .expect(201);
      orderId = selection.body.id;
      // The poster always pays.
      expect(selection.body.payer.id).toBe(MIGUEL);
      expect(selection.body.earner.id).toBe(BIANCA);

      await api()
        .post(`/orders/${orderId}/payment`)
        .set('X-User-Id', MIGUEL)
        .expect(201);
    });

    it('cancelling refunds the payer in full and reopens the post', async () => {
      const before = await api()
        .get('/wallet')
        .set('X-User-Id', BIANCA)
        .expect(200);

      const res = await api()
        .post(`/orders/${orderId}/cancel`)
        .set('X-User-Id', BIANCA)
        .expect(201);
      expect(res.body.status).toBe('CANCELLED');

      // Escrow fully unwound; nothing settled to anyone.
      const escrow = await prisma.ledgerEntry.aggregate({
        where: { account: 'PLATFORM_ESCROW', orderId },
        _sum: { amountMinor: true },
      });
      expect(escrow._sum.amountMinor).toBe(0);
      const payment = await prisma.payment.findFirst({ where: { orderId } });
      expect(payment?.status).toBe('REFUNDED');

      const after = await api()
        .get('/wallet')
        .set('X-User-Id', BIANCA)
        .expect(200);
      expect(after.body.balanceMinor).toBe(before.body.balanceMinor);

      const post = await api()
        .get(`/posts/${postId}`)
        .set('X-User-Id', MIGUEL)
        .expect(200);
      expect(post.body.status).toBe('OPEN');
      // The cancelled candidate is released from the pool.
      const pool = await api()
        .get(`/posts/${postId}/applications`)
        .set('X-User-Id', MIGUEL)
        .expect(200);
      expect(pool.body).toHaveLength(0);

      // A completed/cancelled order cannot be cancelled again.
      await api()
        .post(`/orders/${orderId}/cancel`)
        .set('X-User-Id', MIGUEL)
        .expect(409);
    });

    it('the cancel window closes 30 minutes after payment', async () => {
      // Fresh post and order (re-applying to the old post is blocked by
      // the duplicate-application guard).
      const post = await api()
        .post('/posts')
        .set('X-User-Id', MIGUEL)
        .send({
          templateId: BBQ_TEMPLATE,
          title: 'Window test date',
          scheduledAt: MEET_AT,
        })
        .expect(201);
      const application = await api()
        .post(`/posts/${post.body.id}/applications`)
        .set('X-User-Id', BIANCA)
        .expect(201);
      const selection = await api()
        .post(`/posts/${post.body.id}/selection`)
        .set('X-User-Id', MIGUEL)
        .send({ applicationId: application.body.id })
        .expect(201);
      orderId = selection.body.id;
      await api()
        .post(`/orders/${orderId}/payment`)
        .set('X-User-Id', MIGUEL)
        .expect(201);

      // Within the window either side could cancel; pretend the payment
      // happened 31 minutes ago and the door is shut for both.
      await prisma.order.update({
        where: { id: orderId },
        data: { paidAt: new Date(Date.now() - 31 * 60_000) },
      });
      const closedForPayer = await api()
        .post(`/orders/${orderId}/cancel`)
        .set('X-User-Id', MIGUEL)
        .expect(409);
      expect(closedForPayer.body.message).toBe('CANCEL_WINDOW_CLOSED');
      const closedForHost = await api()
        .post(`/orders/${orderId}/cancel`)
        .set('X-User-Id', BIANCA)
        .expect(409);
      expect(closedForHost.body.message).toBe('CANCEL_WINDOW_CLOSED');
    });

    it('a never-started order forfeits: the money goes to neither side', async () => {
      // Same stuck order: nobody ever submitted the meet code and the
      // planned time is long past.
      await prisma.order.update({
        where: { id: orderId },
        data: { planAt: new Date(Date.now() - 1000) },
      });
      process.env.FORFEIT_AFTER_MS = '0';
      const read = await api()
        .get(`/orders/${orderId}`)
        .set('X-User-Id', MIGUEL)
        .expect(200);
      delete process.env.FORFEIT_AFTER_MS;
      expect(read.body.status).toBe('FORFEITED');
      expect(read.body.completedAt).not.toBeNull();

      // No refund, no payout: the escrow moved to platform revenue.
      const payment = await prisma.payment.findFirst({ where: { orderId } });
      expect(payment?.status).toBe('SUCCEEDED');
      const escrow = await prisma.ledgerEntry.aggregate({
        where: { account: 'PLATFORM_ESCROW', orderId },
        _sum: { amountMinor: true },
      });
      expect(escrow._sum.amountMinor).toBe(0);
      const forfeited = await prisma.ledgerEntry.aggregate({
        where: {
          account: 'PLATFORM_REVENUE',
          orderId,
          entryType: 'ESCROW_FORFEIT',
        },
        _sum: { amountMinor: true },
      });
      expect(forfeited._sum.amountMinor).toBeGreaterThan(0);

      // Forfeited orders are closed for good: no cancel, no code, no chat.
      await api()
        .post(`/orders/${orderId}/cancel`)
        .set('X-User-Id', MIGUEL)
        .expect(409);
      const closed = await api()
        .post(`/orders/${orderId}/messages`)
        .set('X-User-Id', MIGUEL)
        .send({ text: 'hello?' })
        .expect(409);
      expect(closed.body.message).toBe('CHAT_CLOSED');
    });
  });

  describe('role rules: users post and pay, hosts sign up and earn', () => {
    it('hosts cannot publish activity requests', async () => {
      await api()
        .post('/posts')
        .set('X-User-Id', JAMES)
        .send({
          templateId: BBQ_TEMPLATE,
          title: 'Host post',
          scheduledAt: MEET_AT,
        })
        .expect(403);
    });

    it('users cannot sign up for posts', async () => {
      const post = await api()
        .post('/posts')
        .set('X-User-Id', PAOLO)
        .send({
          templateId: BBQ_TEMPLATE,
          title: 'Role guard',
          scheduledAt: MEET_AT,
        })
        .expect(201);
      await api()
        .post(`/posts/${post.body.id}/applications`)
        .set('X-User-Id', MIGUEL)
        .expect(403);
    });
  });

  describe('proposal invitations: users queue on a pitch, the host picks one', () => {
    let proposalId: string;
    let andreaInviteId: string;
    let miguelInviteId: string;
    let orderId: string;

    it('lists hosts with activity credentials', async () => {
      const res = await api()
        .get('/hosts')
        .set('X-User-Id', ANDREA)
        .expect(200);
      expect(res.body.length).toBeGreaterThanOrEqual(5);
      const bianca = res.body.find(
        (h: { user: { id: string } }) => h.user.id === BIANCA,
      );
      expect(bianca).toBeDefined();
      expect(bianca.user.role).toBe('HOST');
      expect(typeof bianca.completedActivities).toBe('number');
      // The host's own published pitch titles surface as credentials.
      expect(bianca.recentProposals.length).toBeGreaterThan(0);

      // Gender preference filter.
      const women = await api()
        .get('/hosts?gender=FEMALE')
        .set('X-User-Id', ANDREA)
        .expect(200);
      for (const card of women.body) {
        expect(card.user.gender).toBe('FEMALE');
      }

      // Single host lookup; users are not in the directory.
      await api().get(`/hosts/${BIANCA}`).set('X-User-Id', ANDREA).expect(200);
      await api().get(`/hosts/${MIGUEL}`).set('X-User-Id', ANDREA).expect(404);
    });

    it('several users queue invitations carrying their own deal terms', async () => {
      // A fresh pitch so the seeded feed stays untouched for later tests.
      // A pitch is a shelf listing: template + availability window only.
      const pitch = await api()
        .post('/proposals')
        .set('X-User-Id', NOEL)
        .send({
          templateId: HOTPOT_TEMPLATE,
          title: 'Friday hotpot night, my pick',
          timeSlot: 'ANYTIME',
        })
        .expect(201);
      proposalId = pitch.body.id;
      expect(pitch.body.status).toBe('OPEN');
      expect(pitch.body.inviteCount).toBe(0);
      expect(pitch.body.hasInvited).toBe(false);
      // The template envelope rides the pitch.
      expect(pitch.body.timeSlot).toBe('ANYTIME');
      expect(pitch.body.meetingPoint).toBe(HOTPOT_MEETING_POINT);
      expect(pitch.body.area).toBe('Pasay');

      // Inviting carries the deal terms: the inviter picks the concrete
      // time (inside the window) and the price tier.
      const first = await api()
        .post(`/proposals/${proposalId}/invitations`)
        .set('X-User-Id', ANDREA)
        .send({
          scheduledAt: MEET_AT,
          budgetMinor: 250000,
          note: 'Friday works for me, pick the quiet rooftops',
        })
        .expect(201);
      andreaInviteId = first.body.id;
      expect(first.body.status).toBe('PENDING');
      expect(first.body.from.id).toBe(ANDREA);
      expect(first.body.proposalId).toBe(proposalId);
      expect(first.body.scheduledAt).toBe(MEET_AT);
      expect(first.body.budgetMinor).toBe(250000);

      // Off-tier pricing is rejected: the platform prices, the inviter
      // only picks.
      const offTier = await api()
        .post(`/proposals/${proposalId}/invitations`)
        .set('X-User-Id', MIGUEL)
        .send({ scheduledAt: MEET_AT, budgetMinor: 99, note: 'cheap' })
        .expect(400);
      expect(offTier.body.message).toBe('INVALID_BUDGET');

      // Duplicate pending invitation on the same pitch conflicts...
      const dup = await api()
        .post(`/proposals/${proposalId}/invitations`)
        .set('X-User-Id', ANDREA)
        .send({ scheduledAt: MEET_AT, note: 'Again' })
        .expect(409);
      expect(dup.body.message).toBe('INVITE_ALREADY_PENDING');
      // ...but other users queue freely on the same pitch, each with
      // their own terms (omitted budget lands on the middle tier).
      const second = await api()
        .post(`/proposals/${proposalId}/invitations`)
        .set('X-User-Id', MIGUEL)
        .send({ scheduledAt: MEET_AT, note: 'Any Friday after 9pm' })
        .expect(201);
      miguelInviteId = second.body.id;
      expect(second.body.budgetMinor).toBe(150000);

      // Hosts cannot invite; a dead proposal id is a 404.
      await api()
        .post(`/proposals/${proposalId}/invitations`)
        .set('X-User-Id', JAMES)
        .send({ scheduledAt: MEET_AT, note: 'no' })
        .expect(403);
      await api()
        .post('/proposals/nope/invitations')
        .set('X-User-Id', ANDREA)
        .send({ scheduledAt: MEET_AT, note: 'no' })
        .expect(404);

      // The detail view counts the queue; inviters see their own flag.
      const detail = await api()
        .get(`/proposals/${proposalId}`)
        .set('X-User-Id', ANDREA)
        .expect(200);
      expect(detail.body.inviteCount).toBe(2);
      expect(detail.body.hasInvited).toBe(true);

      // The invite pool itself is host-only, like a post's candidate list.
      await api()
        .get(`/proposals/${proposalId}/invitations`)
        .set('X-User-Id', ANDREA)
        .expect(403);
      const pool = await api()
        .get(`/proposals/${proposalId}/invitations`)
        .set('X-User-Id', NOEL)
        .expect(200);
      expect(pool.body.length).toBe(2);
      expect(pool.body[0].from.id).toBe(ANDREA);
      expect(pool.body[1].from.id).toBe(MIGUEL);
    });

    it('queued invitations reach the host via the notice feed', async () => {
      const notices = await api()
        .get('/posts/signups/notice')
        .set('X-User-Id', NOEL)
        .expect(200);
      const mine = notices.body.filter(
        (n: { targetId: string }) => n.targetId === proposalId,
      );
      expect(mine).toHaveLength(2);
      for (const n of mine) {
        expect(n.kind).toBe('INVITATION');
      }
      expect(new Set(mine.map((n: { actor: { id: string } }) => n.actor.id))).toEqual(
        new Set([ANDREA, MIGUEL]),
      );
    });

    it('only the host selects; selection creates the order and takes the pitch off the market', async () => {
      await api()
        .post(`/proposals/${proposalId}/invitations/${andreaInviteId}/select`)
        .set('X-User-Id', ANDREA)
        .expect(403);

      const res = await api()
        .post(`/proposals/${proposalId}/invitations/${andreaInviteId}/select`)
        .set('X-User-Id', NOEL)
        .expect(201);
      orderId = res.body.id;
      expect(res.body.status).toBe('AWAITING_PAYMENT');
      expect(res.body.payer.id).toBe(ANDREA);
      expect(res.body.earner.id).toBe(NOEL);
      expect(res.body.feeMinor).toBe(250000); // the tier Andrea picked
      // The plan is the template's meeting point plus the time the
      // INVITER picked: the order is born with the plan confirmed,
      // nothing left to negotiate in chat.
      expect(res.body.planConfirmedAt).not.toBeNull();
      expect(res.body.place).toBe(HOTPOT_MEETING_POINT);
      expect(res.body.scheduledAt).toBe(MEET_AT);

      // Selecting twice, or selecting another inviter while the deal is
      // pending, both conflict: the pitch is off the market.
      await api()
        .post(`/proposals/${proposalId}/invitations/${andreaInviteId}/select`)
        .set('X-User-Id', NOEL)
        .expect(409);
      await api()
        .post(`/proposals/${proposalId}/invitations/${miguelInviteId}/select`)
        .set('X-User-Id', NOEL)
        .expect(409);
      // New invitations bounce too, and the pitch left the hall feed.
      const late = await api()
        .post(`/proposals/${proposalId}/invitations`)
        .set('X-User-Id', ANDREA)
        .send({ scheduledAt: MEET_AT, note: 'too late' })
        .expect(409);
      expect(late.body.message).toBe('PROPOSAL_NOT_OPEN');
      const feed = await api()
        .get('/proposals')
        .set('X-User-Id', ANDREA)
        .expect(200);
      expect(
        feed.body.find((p: { id: string }) => p.id === proposalId),
      ).toBeUndefined();

      // The backing direct post never shows on any public surface.
      const order = await api()
        .get(`/orders/${orderId}`)
        .set('X-User-Id', ANDREA)
        .expect(200);
      const requests = await api()
        .get('/posts?view=requests')
        .set('X-User-Id', JAMES)
        .expect(200);
      expect(
        requests.body.find((p: { id: string }) => p.id === order.body.postId),
      ).toBeUndefined();

      // Downstream is the standard flow: the inviter pays into escrow and
      // the proposal mirrors the order into MATCHED.
      const paid = await api()
        .post(`/orders/${orderId}/payment`)
        .set('X-User-Id', ANDREA)
        .expect(201);
      expect(paid.body.status).toBe('ACTIVE');
      const matched = await api()
        .get(`/proposals/${proposalId}`)
        .set('X-User-Id', ANDREA)
        .expect(200);
      expect(matched.body.status).toBe('MATCHED');
    });

    it('a cancelled deal puts the pitch back on the market with its queue intact', async () => {
      // Within the cancel window the payer can still back out.
      const cancelled = await api()
        .post(`/orders/${orderId}/cancel`)
        .set('X-User-Id', ANDREA)
        .expect(201);
      expect(cancelled.body.status).toBe('CANCELLED');

      // The pitch reopens and the untouched queue is selectable again.
      const reopened = await api()
        .get(`/proposals/${proposalId}`)
        .set('X-User-Id', NOEL)
        .expect(200);
      expect(reopened.body.status).toBe('OPEN');
      const pool = await api()
        .get(`/proposals/${proposalId}/invitations`)
        .set('X-User-Id', NOEL)
        .expect(200);
      expect(pool.body.map((i: { id: string }) => i.id)).toEqual([
        miguelInviteId,
      ]);
      const res = await api()
        .post(`/proposals/${proposalId}/invitations/${miguelInviteId}/select`)
        .set('X-User-Id', NOEL)
        .expect(201);
      expect(res.body.payer.id).toBe(MIGUEL);
    });
  });

  describe('proposals: host activity pitches lead the user home feed', () => {
    it('serves the feed newest first with host credentials', async () => {
      const res = await api()
        .get('/proposals')
        .set('X-User-Id', ANDREA)
        .expect(200);
      expect(res.body.length).toBeGreaterThanOrEqual(6);
      // Newest first.
      const times = res.body.map((p: { createdAt: string }) =>
        Date.parse(p.createdAt),
      );
      expect([...times].sort((a: number, b: number) => b - a)).toEqual(times);
      // The card carries the signature line data: host + track record.
      const pitch = res.body.find(
        (p: { host: { id: string } }) => p.host.id === NOEL,
      );
      expect(pitch).toBeDefined();
      expect(pitch.sceneTag).toBe('Dinner');
      expect(pitch.imageUrl).toContain('https://');
      expect(pitch.area).toBe('Makati');
      expect(pitch.host.role).toBe('HOST');
      expect(typeof pitch.hostCompletedActivities).toBe('number');
    });

    it('only hosts publish; templates lock the envelope', async () => {
      await api()
        .post('/proposals')
        .set('X-User-Id', ANDREA)
        .send({
          templateId: BBQ_TEMPLATE,
          title: 'Users cannot pitch',
          timeSlot: 'ANYTIME',
        })
        .expect(403);

      // A pitch carries no price and no concrete time: just the template
      // and an availability window, which must be a known one.
      await api()
        .post('/proposals')
        .set('X-User-Id', BIANCA)
        .send({
          templateId: STEAK_TEMPLATE,
          title: 'Missing window',
        })
        .expect(400);
      await api()
        .post('/proposals')
        .set('X-User-Id', BIANCA)
        .send({
          templateId: STEAK_TEMPLATE,
          title: 'Made-up window',
          timeSlot: 'MIDNIGHT',
        })
        .expect(400);
      await api()
        .post('/proposals')
        .set('X-User-Id', BIANCA)
        .send({
          templateId: 'template-anything-goes',
          title: 'Off-template pitch',
          timeSlot: 'ANYTIME',
        })
        .expect(404);
      const created = await api()
        .post('/proposals')
        .set('X-User-Id', BIANCA)
        .send({
          templateId: BBQ_TEMPLATE,
          title: 'BBQ night on High Street',
          timeSlot: 'EVENING',
        })
        .expect(201);
      expect(created.body.host.id).toBe(BIANCA);
      expect(created.body.timeSlot).toBe('EVENING');

      // The fresh pitch leads the feed.
      const feed = await api()
        .get('/proposals')
        .set('X-User-Id', ANDREA)
        .expect(200);
      expect(feed.body[0].id).toBe(created.body.id);
      expect(feed.body[0].title).toBe('BBQ night on High Street');
    });
  });

  describe('community moments: non-transactional recaps', () => {
    it('both roles can post moments; they mix into the feed', async () => {
      const userMoment = await api()
        .post('/posts/moments')
        .set('X-User-Id', ANDREA)
        .send({
          text: 'Best coffee afternoon in months, thanks to my host',
          images: ['/uploads/recap1.jpg', '/uploads/recap2.jpg'],
          venue: 'Single Origin, Salcedo Village',
        })
        .expect(201);
      expect(userMoment.body.type).toBe('MOMENT');
      expect(userMoment.body.feeMinor).toBe(0);
      expect(userMoment.body.venue).toBe('Single Origin, Salcedo Village');
      expect(userMoment.body.images).toEqual([
        '/uploads/recap1.jpg',
        '/uploads/recap2.jpg',
      ]);

      await api()
        .post('/posts/moments')
        .set('X-User-Id', JAMES)
        .send({
          text: 'Hosted a great cafe crawl today',
          images: ['/uploads/crawl.jpg'],
          venue: 'Yardstick Coffee, Legazpi Village',
        })
        .expect(201);

      // Photos carry the recap: a moment without at least one image is
      // rejected, whether the field is missing or an empty array.
      await api()
        .post('/posts/moments')
        .set('X-User-Id', JAMES)
        .send({ text: 'No photos', venue: 'Somewhere' })
        .expect(400);
      await api()
        .post('/posts/moments')
        .set('X-User-Id', JAMES)
        .send({ text: 'No photos', images: [], venue: 'Somewhere' })
        .expect(400);

      // Text is required.
      await api()
        .post('/posts/moments')
        .set('X-User-Id', ANDREA)
        .send({ images: ['/uploads/x.jpg'], venue: 'Somewhere' })
        .expect(400);

      // The venue is the recommendation: a recap without it is rejected.
      await api()
        .post('/posts/moments')
        .set('X-User-Id', ANDREA)
        .send({ text: 'Great afternoon', images: ['/uploads/x.jpg'] })
        .expect(400);

      const wall = await api()
        .get('/posts')
        .set('X-User-Id', MIGUEL)
        .expect(200);
      const types = new Set(wall.body.map((p: { type: string }) => p.type));
      expect(types.has('MOMENT')).toBe(true);
      expect(types.has('DEMAND')).toBe(false);
      expect(
        wall.body.find((p: { id: string }) => p.id === userMoment.body.id),
      ).toBeDefined();

      // Moments never take sign-ups.
      await api()
        .post(`/posts/${userMoment.body.id}/applications`)
        .set('X-User-Id', NOEL)
        .expect(409);
    });
  });

  describe('place search proxy', () => {
    it('requires auth and a query; degrades to empty without a key', async () => {
      await api().get('/places/search?q=coffee').expect(401);
      await api()
        .get('/places/search')
        .set('X-User-Id', ANDREA)
        .expect(400);
      // The test environment has no AMAP_KEY: the proxy answers an empty
      // list so the client fields degrade to free typing.
      const res = await api()
        .get('/places/search?q=coffee')
        .set('X-User-Id', ANDREA)
        .expect(200);
      expect(res.body).toEqual([]);
    });
  });

  describe('runtime repricing (admin)', () => {
    it('only admins can reprice; changes apply to new posts only', async () => {
      await api()
        .put('/admin/pricing')
        .set('X-User-Id', ANDREA)
        .send({
          platformFeeRateBp: 1500,
          defaultFeeMinor: 60000,
          sceneBudgetTiers: { Coffee: [70000] },
        })
        .expect(403);

      await api()
        .put('/admin/pricing')
        .set('X-User-Id', ADMIN)
        .send({
          platformFeeRateBp: 1500,
          defaultFeeMinor: 60000,
          sceneBudgetTiers: { Dinner: [70000] },
        })
        .expect(200);

      const config = await api().get('/config/pricing').expect(200);
      expect(config.body.platformFeeRateBp).toBe(1500);

      // New post snapshots the new fee; new order uses the new rate with
      // the exact-remainder split (70000 * 15% = 10500, net 59500).
      const post = await api()
        .post('/posts')
        .set('X-User-Id', PAOLO)
        .send({
          templateId: BBQ_TEMPLATE,
          title: 'KBBQ uptown',
          scheduledAt: MEET_AT,
        })
        .expect(201);
      expect(post.body.feeMinor).toBe(70000);

      const application = await api()
        .post(`/posts/${post.body.id}/applications`)
        .set('X-User-Id', LIZA)
        .expect(201);
      const order = await api()
        .post(`/posts/${post.body.id}/selection`)
        .set('X-User-Id', PAOLO)
        .send({ applicationId: application.body.id })
        .expect(201);
      expect(order.body.commissionMinor).toBe(10500);
      expect(order.body.netMinor).toBe(59500);
      expect(order.body.feeMinor).toBe(
        order.body.commissionMinor + order.body.netMinor,
      );
    });
  });

  describe('order list views: no chat before escrow', () => {
    it('unpaid orders stay out of the conversation list but show in the full history', async () => {
      // MIGUEL still owes the payment on the proposal deal from earlier.
      const history = await api()
        .get('/orders?view=all')
        .set('X-User-Id', MIGUEL)
        .expect(200);
      const unpaid = history.body.find(
        (o: { status: string }) => o.status === 'AWAITING_PAYMENT',
      );
      expect(unpaid).toBeDefined();

      // The Messages view hides it: no money, no conversation.
      const conversations = await api()
        .get('/orders')
        .set('X-User-Id', MIGUEL)
        .expect(200);
      expect(
        conversations.body.find((o: { id: string }) => o.id === unpaid.id),
      ).toBeUndefined();
    });

    it('an order unpaid past the pay window auto-cancels and reopens the pitch', async () => {
      const history = await api()
        .get('/orders?view=all')
        .set('X-User-Id', MIGUEL)
        .expect(200);
      const unpaid = history.body.find(
        (o: { status: string }) => o.status === 'AWAITING_PAYMENT',
      );
      // Age the order past the pay window; the next read runs the clock.
      await prisma.order.update({
        where: { id: unpaid.id },
        data: { createdAt: new Date(Date.now() - 31 * 60_000) },
      });
      const expired = await api()
        .get(`/orders/${unpaid.id}`)
        .set('X-User-Id', MIGUEL)
        .expect(200);
      expect(expired.body.status).toBe('CANCELLED');

      // Dead deals leave the Messages view entirely (they never had, or
      // no longer have, a conversation) but stay in the full history.
      const conversations = await api()
        .get('/orders')
        .set('X-User-Id', MIGUEL)
        .expect(200);
      expect(
        conversations.body.find(
          (o: { status: string }) =>
            o.status === 'CANCELLED' || o.status === 'FORFEITED',
        ),
      ).toBeUndefined();
      const fullHistory = await api()
        .get('/orders?view=all')
        .set('X-User-Id', MIGUEL)
        .expect(200);
      expect(
        fullHistory.body.find((o: { id: string }) => o.id === unpaid.id),
      ).toBeDefined();

      // No money ever moved: nothing to refund, and the pitch is back on
      // the market with the host's queue logic intact.
      const post = await prisma.post.findUnique({
        where: { id: unpaid.postId },
      });
      expect(post!.status).toBe('OPEN');
      const proposal = await prisma.proposal.findUnique({
        where: { id: post!.proposalId },
      });
      expect(proposal!.status).toBe('OPEN');
    });
  });

  describe('security hardening: cross-user access and input abuse', () => {
    let outsiderProofOrderId: string;

    it('outsiders cannot read, cancel or start another pair\'s order', async () => {
      // A fresh deal between Paolo (payer) and Liza (earner)...
      const post = await api()
        .post('/posts')
        .set('X-User-Id', PAOLO)
        .send({
          templateId: HOTPOT_TEMPLATE,
          title: 'Privacy perimeter test',
          scheduledAt: MEET_AT,
        })
        .expect(201);
      const application = await api()
        .post(`/posts/${post.body.id}/applications`)
        .set('X-User-Id', LIZA)
        .expect(201);
      const selection = await api()
        .post(`/posts/${post.body.id}/selection`)
        .set('X-User-Id', PAOLO)
        .send({ applicationId: application.body.id })
        .expect(201);
      outsiderProofOrderId = selection.body.id as string;
      await api()
        .post(`/orders/${outsiderProofOrderId}/payment`)
        .set('X-User-Id', PAOLO)
        .expect(201);

      // ...is a wall to everyone else, host or user, on every verb.
      for (const outsider of [KAT, ANDREA]) {
        await api()
          .get(`/orders/${outsiderProofOrderId}`)
          .set('X-User-Id', outsider)
          .expect(403);
        await api()
          .post(`/orders/${outsiderProofOrderId}/cancel`)
          .set('X-User-Id', outsider)
          .expect(403);
        await api()
          .post(`/orders/${outsiderProofOrderId}/start`)
          .set('X-User-Id', outsider)
          .send({ code: '0000' })
          .expect(403);
      }
      // Nonexistent orders are 404, not information leaks.
      await api()
        .get('/orders/no-such-order')
        .set('X-User-Id', PAOLO)
        .expect(404);
    });

    it('selection is owner-only and rejects applications from other posts', async () => {
      // A second open post with its own candidate.
      const otherPost = await api()
        .post('/posts')
        .set('X-User-Id', MIGUEL)
        .send({
          templateId: BBQ_TEMPLATE,
          title: 'Cross-reference guard',
          scheduledAt: MEET_AT,
        })
        .expect(201);
      const foreignApplication = await api()
        .post(`/posts/${otherPost.body.id}/applications`)
        .set('X-User-Id', KAT)
        .expect(201);

      // A non-owner cannot select on someone else's post.
      await api()
        .post(`/posts/${otherPost.body.id}/selection`)
        .set('X-User-Id', ANDREA)
        .send({ applicationId: foreignApplication.body.id })
        .expect(403);

      // The owner cannot smuggle in an application belonging to a
      // different post.
      const ownPost = await api()
        .post('/posts')
        .set('X-User-Id', MIGUEL)
        .send({
          templateId: HOTPOT_TEMPLATE,
          title: 'Cross-reference guard second post',
          scheduledAt: MEET_AT,
        })
        .expect(201);
      await api()
        .post(`/posts/${ownPost.body.id}/selection`)
        .set('X-User-Id', MIGUEL)
        .send({ applicationId: foreignApplication.body.id })
        .expect(404);
    });

    it('public surfaces never leak phone numbers or birth dates', async () => {
      const hall = await api()
        .get('/posts?view=requests')
        .set('X-User-Id', JAMES)
        .expect(200);
      expect(hall.body.length).toBeGreaterThan(0);
      for (const post of hall.body) {
        expect(post.author.phone).toBeUndefined();
        expect(post.author.birthDate).toBeUndefined();
      }
      const hosts = await api()
        .get('/hosts')
        .set('X-User-Id', ANDREA)
        .expect(200);
      for (const card of hosts.body) {
        expect(card.user.phone).toBeUndefined();
        expect(card.user.birthDate).toBeUndefined();
      }
      // Another user's profile view: same trim.
      const profile = await api()
        .get(`/users/${BIANCA}`)
        .set('X-User-Id', ANDREA)
        .expect(200);
      expect(profile.body.phone).toBeUndefined();
      expect(profile.body.birthDate).toBeUndefined();
    });

    it('profile updates cannot smuggle privileged fields', async () => {
      const before = await api()
        .get('/users/me')
        .set('X-User-Id', MIGUEL)
        .expect(200);
      // The whitelist pipe strips unknown fields; role and verification
      // are not in the DTO, so they survive untouched.
      const res = await api()
        .patch('/users/me')
        .set('X-User-Id', MIGUEL)
        .send({
          name: 'Miguel',
          role: 'ADMIN',
          isVerified: false,
          phone: '+639990000000',
          id: 'user-999',
        })
        .expect(200);
      expect(res.body.role).toBe(before.body.role);
      expect(res.body.isVerified).toBe(before.body.isVerified);
      expect(res.body.id).toBe(MIGUEL);
      const row = await prisma.user.findUnique({ where: { id: MIGUEL } });
      expect(row!.role).toBe('USER');
      expect(row!.phone).not.toBe('+639990000000');
    });

    it('rejects blanking the display name and out-of-range body stats', async () => {
      await api()
        .patch('/users/me')
        .set('X-User-Id', MIGUEL)
        .send({ name: '   ' })
        .expect(400);
      await api()
        .patch('/users/me')
        .set('X-User-Id', MIGUEL)
        .send({ heightCm: 300 })
        .expect(400);
      await api()
        .patch('/users/me')
        .set('X-User-Id', MIGUEL)
        .send({ weightKg: 10 })
        .expect(400);
      // The account is intact afterwards.
      const me = await api()
        .get('/users/me')
        .set('X-User-Id', MIGUEL)
        .expect(200);
      expect((me.body.name as string).length).toBeGreaterThan(0);
    });

    it('expense policy accepts only the known values and defaults to TREAT', async () => {
      const defaulted = await api()
        .post('/posts')
        .set('X-User-Id', ANDREA)
        .send({
          templateId: BBQ_TEMPLATE,
          title: 'Expense default check',
          scheduledAt: MEET_AT,
        })
        .expect(201);
      expect(defaulted.body.expensePolicy).toBe('TREAT');

      const explicit = await api()
        .post('/posts')
        .set('X-User-Id', ANDREA)
        .send({
          templateId: BBQ_TEMPLATE,
          title: 'Expense explicit AA',
          scheduledAt: MEET_AT,
          expensePolicy: 'AA',
        })
        .expect(201);
      expect(explicit.body.expensePolicy).toBe('AA');

      await api()
        .post('/posts')
        .set('X-User-Id', ANDREA)
        .send({
          templateId: BBQ_TEMPLATE,
          title: 'Expense junk value',
          scheduledAt: MEET_AT,
          expensePolicy: 'WHATEVER',
        })
        .expect(400);

      // Keep the hall tidy for the remaining assertions.
      await api()
        .delete(`/posts/${defaulted.body.id}`)
        .set('X-User-Id', ANDREA)
        .expect(200);
      await api()
        .delete(`/posts/${explicit.body.id}`)
        .set('X-User-Id', ANDREA)
        .expect(200);
    });

    it('rejects oversized or empty content payloads', async () => {
      // Order chat: empty and over-limit messages bounce.
      await api()
        .post(`/orders/${outsiderProofOrderId}/messages`)
        .set('X-User-Id', PAOLO)
        .send({ text: '' })
        .expect(400);
      await api()
        .post(`/orders/${outsiderProofOrderId}/messages`)
        .set('X-User-Id', PAOLO)
        .send({ text: 'x'.repeat(2001) })
        .expect(400);
      // Moments: text over 600 chars bounces.
      await api()
        .post('/posts/moments')
        .set('X-User-Id', ANDREA)
        .send({
          text: 'x'.repeat(601),
          images: ['/uploads/x.jpg'],
          venue: 'Somewhere',
        })
        .expect(400);
      // Meet code must be exactly 4 characters.
      await api()
        .post(`/orders/${outsiderProofOrderId}/start`)
        .set('X-User-Id', LIZA)
        .send({ code: '123' })
        .expect(400);
    });

    it('rejects zero and negative withdrawals', async () => {
      await api()
        .post('/wallet/withdrawals')
        .set('X-User-Id', JAMES)
        .send({ amountMinor: 0 })
        .expect(400);
      await api()
        .post('/wallet/withdrawals')
        .set('X-User-Id', JAMES)
        .send({ amountMinor: -5000 })
        .expect(400);
      await api()
        .post('/wallet/withdrawals')
        .set('X-User-Id', JAMES)
        .send({ amountMinor: 10.5 })
        .expect(400);
    });
  });

  describe('concurrency, idempotency and upload abuse', () => {
    /** The ACTIVE order produced by the double-payment race, reused to
     *  race the meet-code start below. */
    let racedOrderId: string;

    it('concurrent double payment escrows the fee exactly once', async () => {
      const post = await api()
        .post('/posts')
        .set('X-User-Id', ANDREA)
        .send({
          templateId: BBQ_TEMPLATE,
          title: 'Double payment race',
          scheduledAt: MEET_AT,
        })
        .expect(201);
      const application = await api()
        .post(`/posts/${post.body.id}/applications`)
        .set('X-User-Id', KAT)
        .expect(201);
      const selection = await api()
        .post(`/posts/${post.body.id}/selection`)
        .set('X-User-Id', ANDREA)
        .send({ applicationId: application.body.id })
        .expect(201);
      racedOrderId = selection.body.id as string;

      // Two simultaneous payment submissions (double tap / two tabs).
      const [first, second] = await Promise.all([
        api().post(`/orders/${racedOrderId}/payment`).set('X-User-Id', ANDREA),
        api().post(`/orders/${racedOrderId}/payment`).set('X-User-Id', ANDREA),
      ]);

      // Exactly one submission wins however the race lands...
      expect(
        [first.status, second.status].filter((s) => s === 201),
      ).toHaveLength(1);
      // ...and the books hold exactly one charge and one escrow entry.
      expect(
        await prisma.payment.count({ where: { orderId: racedOrderId } }),
      ).toBe(1);
      expect(
        await prisma.ledgerEntry.count({
          where: { orderId: racedOrderId, entryType: 'ESCROW_IN' },
        }),
      ).toBe(1);
    });

    it('racing two selections on one post creates exactly one order', async () => {
      const post = await api()
        .post('/posts')
        .set('X-User-Id', MIGUEL)
        .send({
          templateId: HOTPOT_TEMPLATE,
          title: 'Selection race',
          scheduledAt: MEET_AT,
        })
        .expect(201);
      const firstCandidate = await api()
        .post(`/posts/${post.body.id}/applications`)
        .set('X-User-Id', LIZA)
        .expect(201);
      const secondCandidate = await api()
        .post(`/posts/${post.body.id}/applications`)
        .set('X-User-Id', NOEL)
        .expect(201);

      // The poster double-fires on two different candidates at once.
      const [first, second] = await Promise.all([
        api()
          .post(`/posts/${post.body.id}/selection`)
          .set('X-User-Id', MIGUEL)
          .send({ applicationId: firstCandidate.body.id }),
        api()
          .post(`/posts/${post.body.id}/selection`)
          .set('X-User-Id', MIGUEL)
          .send({ applicationId: secondCandidate.body.id }),
      ]);

      expect(
        [first.status, second.status].filter((s) => s === 201),
      ).toHaveLength(1);
      // One order, one selected candidate: no double booking.
      expect(
        await prisma.order.count({ where: { postId: post.body.id } }),
      ).toBe(1);
      expect(
        await prisma.application.count({
          where: { postId: post.body.id, status: 'SELECTED' },
        }),
      ).toBe(1);
    });

    it('the meet code starts the service clock exactly once', async () => {
      const payerView = await api()
        .get(`/orders/${racedOrderId}`)
        .set('X-User-Id', ANDREA)
        .expect(200);
      const code = payerView.body.meetCode as string;
      expect(code).toMatch(/^\d{4}$/);

      const [first, second] = await Promise.all([
        api()
          .post(`/orders/${racedOrderId}/start`)
          .set('X-User-Id', KAT)
          .send({ code }),
        api()
          .post(`/orders/${racedOrderId}/start`)
          .set('X-User-Id', KAT)
          .send({ code }),
      ]);

      expect(
        [first.status, second.status].filter((s) => s === 201),
      ).toHaveLength(1);
      const row = await prisma.order.findUnique({
        where: { id: racedOrderId },
      });
      expect(row!.startedAt).not.toBeNull();
    });

    it('uploads demand auth, an image mime, and never trust the client filename', async () => {
      const fakeImage = Buffer.from('not really a png but small');

      // No session: no storage.
      await api()
        .post('/uploads')
        .attach('file', fakeImage, {
          filename: 'x.png',
          contentType: 'image/png',
        })
        .expect(401);

      // A non-image mime is refused outright.
      await api()
        .post('/uploads')
        .set('X-User-Id', ANDREA)
        .attach('file', fakeImage, {
          filename: 'x.png',
          contentType: 'text/plain',
        })
        .expect(400);

      // An .html name with an image mime must NOT be stored as .html:
      // the extension comes from the mime, killing the stored-XSS vector.
      const smuggled = await api()
        .post('/uploads')
        .set('X-User-Id', ANDREA)
        .attach('file', fakeImage, {
          filename: 'evil.html',
          contentType: 'image/png',
        })
        .expect(201);
      expect(smuggled.body.url).toMatch(/^\/uploads\/[0-9a-f-]{36}\.png$/);

      // Path traversal in the name is neutralised by the server-chosen name.
      const traversal = await api()
        .post('/uploads')
        .set('X-User-Id', ANDREA)
        .attach('file', fakeImage, {
          filename: '../../evil.png',
          contentType: 'image/png',
        })
        .expect(201);
      expect(traversal.body.url).toMatch(/^\/uploads\/[0-9a-f-]{36}\.png$/);

      // Over the 8 MB cap: payload too large.
      const oversized = Buffer.alloc(8 * 1024 * 1024 + 1);
      await api()
        .post('/uploads')
        .set('X-User-Id', ANDREA)
        .attach('file', oversized, {
          filename: 'big.png',
          contentType: 'image/png',
        })
        .expect(413);
    });
  });

  describe('ops console: bans, takedowns, reports, force refunds', () => {
    it('hides every admin endpoint from ordinary accounts', async () => {
      await api().get('/admin/users?q=x').set('X-User-Id', ANDREA).expect(403);
      await api()
        .post(`/admin/users/${MIGUEL}/ban`)
        .set('X-User-Id', KAT)
        .expect(403);
      await api().get('/admin/reports').set('X-User-Id', MIGUEL).expect(403);
    });

    it('finds accounts by phone or name', async () => {
      const byPhone = await api()
        .get('/admin/users?q=%2B639170000102')
        .set('X-User-Id', ADMIN)
        .expect(200);
      expect(byPhone.body.map((u: { id: string }) => u.id)).toContain(PAOLO);
    });

    it('a ban locks the account instantly and pulls its open inventory', async () => {
      // PAOLO (USER) has an open post; JAMES (HOST) is applied to it.
      const post = await api()
        .post('/posts')
        .set('X-User-Id', PAOLO)
        .send({
          templateId: STEAK_TEMPLATE,
          title: 'Ban cascade fixture',
          scheduledAt: MEET_AT,
        })
        .expect(201);
      await api()
        .post(`/posts/${post.body.id}/applications`)
        .set('X-User-Id', JAMES)
        .expect(201);

      // Banning the applicant releases their pending application...
      await api()
        .post(`/admin/users/${JAMES}/ban`)
        .set('X-User-Id', ADMIN)
        .expect(201);
      const jamesBlocked = await api()
        .get('/posts')
        .set('X-User-Id', JAMES)
        .expect(403);
      expect(JSON.stringify(jamesBlocked.body)).toContain('ACCOUNT_BANNED');
      expect(
        await prisma.application.count({
          where: { postId: post.body.id, status: 'APPLIED' },
        }),
      ).toBe(0);

      // ...and an unban restores access on the very next request.
      await api()
        .post(`/admin/users/${JAMES}/unban`)
        .set('X-User-Id', ADMIN)
        .expect(201);
      await api().get('/posts').set('X-User-Id', JAMES).expect(200);

      // Banning the author takes the open post off the market.
      await api()
        .post(`/admin/users/${PAOLO}/ban`)
        .set('X-User-Id', ADMIN)
        .expect(201);
      const row = await prisma.post.findUnique({
        where: { id: post.body.id },
      });
      expect(row!.status).toBe('CANCELLED');
      await api().get('/posts').set('X-User-Id', PAOLO).expect(403);

      // Leave PAOLO usable for anything that follows.
      await api()
        .post(`/admin/users/${PAOLO}/unban`)
        .set('X-User-Id', ADMIN)
        .expect(201);
    });

    it('refuses to ban an admin account', async () => {
      await api()
        .post(`/admin/users/${ADMIN}/ban`)
        .set('X-User-Id', ADMIN)
        .expect(403);
    });

    it('lets the admin delete anyone open post; strangers still cannot', async () => {
      const post = await api()
        .post('/posts')
        .set('X-User-Id', MIGUEL)
        .send({
          templateId: BBQ_TEMPLATE,
          title: 'Takedown fixture',
          scheduledAt: MEET_AT,
        })
        .expect(201);

      // A random user is still shut out of someone else's post.
      await api()
        .delete(`/posts/${post.body.id}`)
        .set('X-User-Id', ANDREA)
        .expect(403);

      await api()
        .delete(`/posts/${post.body.id}`)
        .set('X-User-Id', ADMIN)
        .expect(200);
      const row = await prisma.post.findUnique({
        where: { id: post.body.id },
      });
      expect(row!.status).toBe('CANCELLED');
    });

    it('an open report freezes settlement until ops resolves it', async () => {
      // A started order whose clock has fully run out...
      const post = await api()
        .post('/posts')
        .set('X-User-Id', ANDREA)
        .send({
          templateId: HOTPOT_TEMPLATE,
          title: 'Frozen settlement fixture',
          scheduledAt: MEET_AT,
        })
        .expect(201);
      const application = await api()
        .post(`/posts/${post.body.id}/applications`)
        .set('X-User-Id', LIZA)
        .expect(201);
      const selection = await api()
        .post(`/posts/${post.body.id}/selection`)
        .set('X-User-Id', ANDREA)
        .send({ applicationId: application.body.id })
        .expect(201);
      const orderId = selection.body.id as string;
      await api()
        .post(`/orders/${orderId}/payment`)
        .set('X-User-Id', ANDREA)
        .expect(201);
      const payerView = await api()
        .get(`/orders/${orderId}`)
        .set('X-User-Id', ANDREA)
        .expect(200);
      await api()
        .post(`/orders/${orderId}/start`)
        .set('X-User-Id', LIZA)
        .send({ code: payerView.body.meetCode })
        .expect(201);

      // ...but the payer reported it before the clock expired.
      await api()
        .post(`/orders/${orderId}/report`)
        .set('X-User-Id', ANDREA)
        .send({ reason: 'Host behaved inappropriately during the meetup' })
        .expect(201);
      // A blank reason is never a report.
      await api()
        .post(`/orders/${orderId}/report`)
        .set('X-User-Id', ANDREA)
        .send({ reason: '   ' })
        .expect(400);

      await prisma.order.update({
        where: { id: orderId },
        data: { startedAt: new Date(Date.now() - 150 * 60 * 1000) },
      });

      // The lazy settlement clock reads the order... and holds.
      const frozen = await api()
        .get(`/orders/${orderId}`)
        .set('X-User-Id', ANDREA)
        .expect(200);
      expect(frozen.body.status).toBe('ACTIVE');

      // Resolving the report lets the next read settle normally.
      const reports = await api()
        .get('/admin/reports')
        .set('X-User-Id', ADMIN)
        .expect(200);
      const mine = reports.body.find(
        (r: { orderId: string }) => r.orderId === orderId,
      );
      expect(mine.status).toBe('OPEN');
      expect(mine.reported.id).toBe(LIZA);
      await api()
        .post(`/admin/reports/${mine.id}/resolve`)
        .set('X-User-Id', ADMIN)
        .expect(201);
      const settled = await api()
        .get(`/orders/${orderId}`)
        .set('X-User-Id', ANDREA)
        .expect(200);
      expect(settled.body.status).toBe('COMPLETED');
    });

    it('force-refunds an active order in full, exactly once', async () => {
      const post = await api()
        .post('/posts')
        .set('X-User-Id', MIGUEL)
        .send({
          templateId: STEAK_TEMPLATE,
          title: 'Force refund fixture',
          scheduledAt: MEET_AT,
        })
        .expect(201);
      const application = await api()
        .post(`/posts/${post.body.id}/applications`)
        .set('X-User-Id', NOEL)
        .expect(201);
      const selection = await api()
        .post(`/posts/${post.body.id}/selection`)
        .set('X-User-Id', MIGUEL)
        .send({ applicationId: application.body.id })
        .expect(201);
      const orderId = selection.body.id as string;
      await api()
        .post(`/orders/${orderId}/payment`)
        .set('X-User-Id', MIGUEL)
        .expect(201);

      const refunded = await api()
        .post(`/admin/orders/${orderId}/refund`)
        .set('X-User-Id', ADMIN)
        .expect(201);
      expect(refunded.body.status).toBe('CANCELLED');
      // The meet code is never disclosed through the admin view.
      expect(refunded.body.meetCode).toBe('');

      // Money: charge marked refunded, escrow zeroed out by the refund entry.
      const payment = await prisma.payment.findFirst({ where: { orderId } });
      expect(payment!.status).toBe('REFUNDED');
      const escrowSum = await prisma.ledgerEntry.aggregate({
        where: { orderId, account: 'PLATFORM_ESCROW' },
        _sum: { amountMinor: true },
      });
      expect(escrowSum._sum.amountMinor).toBe(0);
      // The disputed post does NOT quietly reopen on the market.
      const row = await prisma.post.findUnique({
        where: { id: post.body.id },
      });
      expect(row!.status).toBe('CANCELLED');

      // A second refund attempt finds nothing active to claim.
      await api()
        .post(`/admin/orders/${orderId}/refund`)
        .set('X-User-Id', ADMIN)
        .expect(409);
    });
  });
});
