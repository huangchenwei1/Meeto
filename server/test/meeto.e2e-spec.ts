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

// The plan card every host sign-up carries (place + time + pitch).
// Selecting the candidate approves this plan in the same tap, so paid
// orders start with chat open and the plan already confirmed.
const PLAN_CARD = {
  proposal: 'Cafe in Makati, Saturday 3pm',
  place: 'Single Origin, Salcedo Village',
  scheduledAt: new Date(Date.now() + 7 * 24 * 3600 * 1000).toISOString(),
  durationMinutes: 180,
};

// The plan card the host fills when selecting an inviter on a pitch:
// the mirror of the sign-up plan card, locked at the same tap.
const SELECT_PLAN = {
  place: 'NOEL Bar, Poblacion',
  scheduledAt: new Date(Date.now() + 5 * 24 * 3600 * 1000).toISOString(),
  durationMinutes: 150,
  note: 'Signature cocktails first, rooftop after',
};

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
      30000, 40000, 60000,
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
        .send({ sceneTag: 'Coffee', title: 'Blocked' })
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
        .send({ sceneTag: 'Coffee', title: 'Now allowed' })
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
          sceneTag: 'Coffee',
          title: 'Cafe hopping in Makati',
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
        .send({ sceneTag: 'Dinner', title: 'Cancelled leaves the hall' })
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
          sceneTag: 'Dinner',
          title: 'Dinner on the starter tier',
          budgetMinor: 30000,
        })
        .expect(201);
      expect(low.body.feeMinor).toBe(30000);

      // An amount outside the scene's tier list is rejected: the platform
      // prices, the poster only picks.
      const rejected = await api()
        .post('/posts')
        .set('X-User-Id', ANDREA)
        .send({
          sceneTag: 'Dinner',
          title: 'Free-priced dinner',
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

    it('demand posts carry the fuzzy slot and area through to the hall', async () => {
      // Publish from a template: fuzzy window + rough district only; the
      // exact schedule still arrives later via the plan flow.
      const created = await api()
        .post('/posts')
        .set('X-User-Id', ANDREA)
        .send({
          sceneTag: 'Tea',
          title: 'Dessert run with zero decisions by me',
          timeSlot: 'WEEKEND',
          area: 'Rockwell',
        })
        .expect(201);
      expect(created.body.timeSlot).toBe('WEEKEND');
      expect(created.body.area).toBe('Rockwell');

      const hall = await api()
        .get('/posts?view=requests')
        .set('X-User-Id', NOEL)
        .expect(200);
      const seen = hall.body.find(
        (p: { id: string }) => p.id === created.body.id,
      );
      expect(seen.timeSlot).toBe('WEEKEND');
      expect(seen.area).toBe('Rockwell');
      // Seeded posts got the backfill too.
      const seeded = hall.body.find(
        (p: { id: string }) => p.id === 'post-001',
      );
      expect(seeded.timeSlot).toBe('WEEKEND');
      expect(seeded.area).toBe('Makati');
    });
  });

  describe('templates: the curated activity shelf', () => {
    it('serves the operations-curated list to both roles', async () => {
      const asUser = await api()
        .get('/templates')
        .set('X-User-Id', ANDREA)
        .expect(200);
      expect(asUser.body.length).toBeGreaterThanOrEqual(5);
      for (const template of asUser.body) {
        expect(template.id).toContain('template-');
        expect(template.sceneTag).toBeTruthy();
        expect(template.title).toBeTruthy();
        expect(template.imageUrl).toContain('https://');
        expect(template.durationLabel).toBeTruthy();
        expect(template.venueLabel).toBeTruthy();
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
          sceneTag: 'Movie',
          title: 'Signup visibility flow',
        })
        .expect(201);
      postId = postRes.body.id;

      await api()
        .post(`/posts/${postId}/applications`)
        .set('X-User-Id', NOEL)
        .send(PLAN_CARD)
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

      // Other hosts see anonymous interest on the post: a count plus
      // avatar URLs only, never names, ids, or rival pitches.
      const asHost = await api()
        .get(`/posts/${postId}`)
        .set('X-User-Id', NOEL)
        .expect(200);
      expect(asHost.body.applicantCount).toBe(1);
      expect(asHost.body.applicantAvatars).toHaveLength(1);
      expect(typeof asHost.body.applicantAvatars[0]).toBe('string');
      expect(asHost.body.applicantPreviews).toEqual([]);

      // Other users instead get a service showcase: clear avatar plus a
      // server-truncated pitch teaser, still no names or ids.
      const asUser = await api()
        .get(`/posts/${postId}`)
        .set('X-User-Id', MIGUEL)
        .expect(200);
      expect(asUser.body.applicantAvatars).toEqual([]);
      expect(asUser.body.applicantPreviews).toHaveLength(1);
      const preview = asUser.body.applicantPreviews[0];
      expect(Object.keys(preview).sort()).toEqual([
        'avatarUrl',
        'proposalTeaser',
      ]);
      expect(preview.proposalTeaser.length).toBeLessThanOrEqual(13);

      // The owner needs neither trimmed view: the full pool lives on the
      // owner-only applications endpoint.
      const asOwner = await api()
        .get(`/posts/${postId}`)
        .set('X-User-Id', ANDREA)
        .expect(200);
      expect(asOwner.body.applicantAvatars).toEqual([]);
      expect(asOwner.body.applicantPreviews).toEqual([]);
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
          sceneTag: 'Dinner',
          title: 'Japanese dinner downtown',
        })
        .expect(201);
      postId = res.body.id;
      // No explicit tier pick -> the middle Dinner tier.
      expect(res.body.feeMinor).toBe(40000);
      expect(res.body.status).toBe('OPEN');
      // Posts carry no structured time or place: the host proposes the
      // concrete plan on the order after matching.
      expect(res.body.scheduledAt).toBeUndefined();
      expect(res.body.place).toBeUndefined();
    });

    it('candidates of any gender sign up for free; invalid sign-ups are rejected', async () => {
      const jamesRes = await api()
        .post(`/posts/${postId}/applications`)
        .set('X-User-Id', JAMES)
        .send(PLAN_CARD)
        .expect(201);
      jamesApplicationId = jamesRes.body.id;
      await api()
        .post(`/posts/${postId}/applications`)
        .set('X-User-Id', NOEL)
        .send(PLAN_CARD)
        .expect(201);
      // Same-gender sign-up is allowed: the marketplace is gender-neutral.
      await api()
        .post(`/posts/${postId}/applications`)
        .set('X-User-Id', BIANCA)
        .send(PLAN_CARD)
        .expect(201);

      // Only hosts can sign up; users invite hosts instead.
      await api()
        .post(`/posts/${postId}/applications`)
        .set('X-User-Id', MIGUEL)
        .send(PLAN_CARD)
        .expect(403);
      // Duplicate sign-up rejected.
      await api()
        .post(`/posts/${postId}/applications`)
        .set('X-User-Id', JAMES)
        .send(PLAN_CARD)
        .expect(409);
      // The pitch and the plan card are required: selection means
      // picking a concrete plan.
      const noProposal = await api()
        .post(`/posts/${postId}/applications`)
        .set('X-User-Id', KAT)
        .send({})
        .expect(400);
      expect(noProposal.body.message).toBeDefined();
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
      // Each candidate pitches a plan; the poster picks between plans.
      expect(res.body[0].proposal).toBe(PLAN_CARD.proposal);
      expect(res.body[0].planPlace).toBe(PLAN_CARD.place);
      expect(res.body[0].planAt).toBe(PLAN_CARD.scheduledAt);
      expect(res.body[0].planDurationMinutes).toBe(180);
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
      expect(res.body.feeMinor).toBe(40000);
      expect(res.body.commissionMinor).toBe(4000);
      expect(res.body.netMinor).toBe(36000);

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
      expect(escrow._sum.amountMinor).toBe(40000);
    });

    it('selection locked the sign-up plan card; no plan flow in chat', async () => {
      // The plan card delivered at sign-up was approved by the selection:
      // place and time are already effective, nothing left to confirm.
      const current = await api()
        .get(`/orders/${orderId}`)
        .set('X-User-Id', ANDREA)
        .expect(200);
      expect(current.body.planConfirmedAt).not.toBeNull();
      expect(current.body.place).toBe(PLAN_CARD.place);
      expect(current.body.scheduledAt).toBe(PLAN_CARD.scheduledAt);
      // The sign-up pitch doubles as the itinerary.
      expect(current.body.planNote).toBe(PLAN_CARD.proposal);

      // The approved plan card opened the conversation as a PLAN message
      // carrying the frozen snapshot of the card.
      const opening = await api()
        .get(`/orders/${orderId}/messages`)
        .set('X-User-Id', ANDREA)
        .expect(200);
      expect(opening.body[0].kind).toBe('PLAN');
      expect(JSON.parse(opening.body[0].text)).toEqual({
        place: PLAN_CARD.place,
        scheduledAt: PLAN_CARD.scheduledAt,
        note: PLAN_CARD.proposal,
        durationMinutes: PLAN_CARD.durationMinutes,
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

      // The conversation dies with the activity: the thread turns
      // read-only, while the history stays listable for both sides.
      const closed = await api()
        .post(`/orders/${orderId}/messages`)
        .set('X-User-Id', ANDREA)
        .send({ text: 'one more thing...' })
        .expect(409);
      expect(closed.body.message).toBe('CHAT_CLOSED');
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
      expect(revenue._sum.amountMinor).toBe(4000);
    });

    it('the earner wallet reflects net income and supports withdrawal', async () => {
      const wallet = await api()
        .get('/wallet')
        .set('X-User-Id', JAMES)
        .expect(200);
      expect(wallet.body.balanceMinor).toBe(36000);
      expect(wallet.body.monthIncomeMinor).toBe(36000);

      await api()
        .post('/wallet/withdrawals')
        .set('X-User-Id', JAMES)
        .send({ amountMinor: 5000 })
        .expect(201);
      const after = await api()
        .get('/wallet')
        .set('X-User-Id', JAMES)
        .expect(200);
      expect(after.body.balanceMinor).toBe(31000);

      // Overdraft rejected.
      await api()
        .post('/wallet/withdrawals')
        .set('X-User-Id', JAMES)
        .send({ amountMinor: 40000 })
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
  });

  describe('post deletion (author only, open posts only)', () => {
    it('author deletes an open post; it leaves the feed', async () => {
      const post = await api()
        .post('/posts')
        .set('X-User-Id', MIGUEL)
        .send({ sceneTag: 'Coffee', title: 'Delete me' })
        .expect(201);

      // Someone applied before deletion.
      await api()
        .post(`/posts/${post.body.id}/applications`)
        .set('X-User-Id', BIANCA)
        .send(PLAN_CARD)
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
        .send({ sceneTag: 'Dinner', title: 'Meet code flow' })
        .expect(201);
      await api()
        .post(`/posts/${post.body.id}/applications`)
        .set('X-User-Id', KAT)
        .send(PLAN_CARD)
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
        .send({ sceneTag: 'Coffee', title: 'Coffee date' })
        .expect(201);
      postId = post.body.id;

      const application = await api()
        .post(`/posts/${postId}/applications`)
        .set('X-User-Id', BIANCA)
        .send(PLAN_CARD)
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
        .send({ sceneTag: 'Coffee', title: 'Window test date' })
        .expect(201);
      const application = await api()
        .post(`/posts/${post.body.id}/applications`)
        .set('X-User-Id', BIANCA)
        .send(PLAN_CARD)
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
        .send({ sceneTag: 'Coffee', title: 'Host post' })
        .expect(403);
    });

    it('users cannot sign up for posts', async () => {
      const post = await api()
        .post('/posts')
        .set('X-User-Id', PAOLO)
        .send({ sceneTag: 'Tea', title: 'Role guard' })
        .expect(201);
      await api()
        .post(`/posts/${post.body.id}/applications`)
        .set('X-User-Id', MIGUEL)
        .send({ ...PLAN_CARD, proposal: 'A plan from the wrong side' })
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
      // The seeded application proposal surfaces as a hosting credential.
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

    it('several users queue invitations; the pitch locks the price', async () => {
      // A fresh pitch so the seeded feed stays untouched for later tests.
      const pitch = await api()
        .post('/proposals')
        .set('X-User-Id', NOEL)
        .send({
          title: 'Friday rooftop crawl, my shortlist',
          sceneTag: 'Bar',
          budgetMinor: 35000,
        })
        .expect(201);
      proposalId = pitch.body.id;
      expect(pitch.body.status).toBe('OPEN');
      expect(pitch.body.inviteCount).toBe(0);
      expect(pitch.body.hasInvited).toBe(false);

      // Inviting carries only the note: scene and price come from the
      // pitch (whoever launches the activity prices it).
      const first = await api()
        .post(`/proposals/${proposalId}/invitations`)
        .set('X-User-Id', ANDREA)
        .send({ note: 'Friday works for me, pick the quiet rooftops' })
        .expect(201);
      andreaInviteId = first.body.id;
      expect(first.body.status).toBe('PENDING');
      expect(first.body.from.id).toBe(ANDREA);
      expect(first.body.proposalId).toBe(proposalId);

      // Duplicate pending invitation on the same pitch conflicts...
      const dup = await api()
        .post(`/proposals/${proposalId}/invitations`)
        .set('X-User-Id', ANDREA)
        .send({ note: 'Again' })
        .expect(409);
      expect(dup.body.message).toBe('INVITE_ALREADY_PENDING');
      // ...but other users queue freely on the same pitch.
      const second = await api()
        .post(`/proposals/${proposalId}/invitations`)
        .set('X-User-Id', MIGUEL)
        .send({ note: 'Any Friday after 9pm' })
        .expect(201);
      miguelInviteId = second.body.id;

      // Hosts cannot invite; a dead proposal id is a 404.
      await api()
        .post(`/proposals/${proposalId}/invitations`)
        .set('X-User-Id', JAMES)
        .send({ note: 'no' })
        .expect(403);
      await api()
        .post('/proposals/nope/invitations')
        .set('X-User-Id', ANDREA)
        .send({ note: 'no' })
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

    it('only the host selects; selection creates the order and takes the pitch off the market', async () => {
      await api()
        .post(`/proposals/${proposalId}/invitations/${andreaInviteId}/select`)
        .set('X-User-Id', ANDREA)
        .send(SELECT_PLAN)
        .expect(403);

      const res = await api()
        .post(`/proposals/${proposalId}/invitations/${andreaInviteId}/select`)
        .set('X-User-Id', NOEL)
        .send(SELECT_PLAN)
        .expect(201);
      orderId = res.body.id;
      expect(res.body.status).toBe('AWAITING_PAYMENT');
      expect(res.body.payer.id).toBe(ANDREA);
      expect(res.body.earner.id).toBe(NOEL);
      expect(res.body.feeMinor).toBe(35000); // the pitch's locked tier
      // The host's plan card was locked in the same tap: the order is
      // born with the plan confirmed, nothing left to negotiate in chat.
      expect(res.body.planConfirmedAt).not.toBeNull();
      expect(res.body.place).toBe(SELECT_PLAN.place);
      expect(res.body.scheduledAt).toBe(SELECT_PLAN.scheduledAt);
      expect(res.body.planNote).toBe(SELECT_PLAN.note);

      // Selecting twice, or selecting another inviter while the deal is
      // pending, both conflict: the pitch is off the market.
      await api()
        .post(`/proposals/${proposalId}/invitations/${andreaInviteId}/select`)
        .set('X-User-Id', NOEL)
        .send(SELECT_PLAN)
        .expect(409);
      await api()
        .post(`/proposals/${proposalId}/invitations/${miguelInviteId}/select`)
        .set('X-User-Id', NOEL)
        .send(SELECT_PLAN)
        .expect(409);
      // New invitations bounce too, and the pitch left the hall feed.
      const late = await api()
        .post(`/proposals/${proposalId}/invitations`)
        .set('X-User-Id', ANDREA)
        .send({ note: 'too late' })
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
        .send(SELECT_PLAN)
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
      expect(pitch.sceneTag).toBe('Bar');
      expect(pitch.imageUrl).toContain('https://');
      expect(pitch.area).toBe('Poblacion');
      expect(pitch.host.role).toBe('HOST');
      expect(typeof pitch.hostCompletedActivities).toBe('number');
    });

    it('only hosts publish; any priced scene goes', async () => {
      await api()
        .post('/proposals')
        .set('X-User-Id', ANDREA)
        .send({ title: 'Users cannot pitch', sceneTag: 'Coffee' })
        .expect(403);

      // No registration-declared scene list anymore: what a host offers
      // is whatever they actually pitch. Omitting the budget lands on the
      // scene's middle platform tier.
      const barPitch = await api()
        .post('/proposals')
        .set('X-User-Id', BIANCA)
        .send({ title: 'Rooftop crawl', sceneTag: 'Bar' })
        .expect(201);
      expect(barPitch.body.budgetMinor).toBe(35000);

      // Whoever launches the activity prices it: the host picks a
      // platform tier; made-up prices are rejected.
      await api()
        .post('/proposals')
        .set('X-User-Id', BIANCA)
        .send({
          title: 'Free pricing is not a thing',
          sceneTag: 'Coffee',
          budgetMinor: 99,
        })
        .expect(400);
      const created = await api()
        .post('/proposals')
        .set('X-User-Id', BIANCA)
        .send({
          title: 'Morning filter tasting in Salcedo',
          sceneTag: 'Coffee',
          budgetMinor: 25000,
        })
        .expect(201);
      expect(created.body.host.id).toBe(BIANCA);
      expect(created.body.budgetMinor).toBe(25000);

      // The fresh pitch leads the feed.
      const feed = await api()
        .get('/proposals')
        .set('X-User-Id', ANDREA)
        .expect(200);
      expect(feed.body[0].id).toBe(created.body.id);
      expect(feed.body[0].title).toBe('Morning filter tasting in Salcedo');
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
        .send({ ...PLAN_CARD, proposal: 'Not applicable' })
        .expect(409);
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
          sceneBudgetTiers: { Coffee: [70000], Dinner: [100000] },
        })
        .expect(200);

      const config = await api().get('/config/pricing').expect(200);
      expect(config.body.platformFeeRateBp).toBe(1500);

      // New post snapshots the new fee; new order uses the new rate with
      // the exact-remainder split (70000 * 15% = 10500, net 59500).
      const post = await api()
        .post('/posts')
        .set('X-User-Id', PAOLO)
        .send({ sceneTag: 'Coffee', title: 'Coffee uptown' })
        .expect(201);
      expect(post.body.feeMinor).toBe(70000);

      const application = await api()
        .post(`/posts/${post.body.id}/applications`)
        .set('X-User-Id', LIZA)
        .send(PLAN_CARD)
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
});
