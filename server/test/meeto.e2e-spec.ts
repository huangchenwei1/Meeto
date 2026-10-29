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
    expect(res.body.sceneFees.Dinner).toBe(100000);
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

  describe('feed: the community activity wall', () => {
    it('shows every open post to every caller by default', async () => {
      // Seed posts are all male-authored; add one female-authored post so
      // neutrality is observable in both directions.
      await api()
        .post('/posts')
        .set('X-User-Id', ANDREA)
        .send({
          sceneTag: 'Coffee',
          title: 'Cafe hopping in Makati',
        })
        .expect(201);

      const maleView = await api()
        .get('/posts')
        .set('X-User-Id', MIGUEL)
        .expect(200);
      const maleGenders = new Set(
        maleView.body.map((p: { author: { gender: string } }) => p.author.gender),
      );
      expect(maleGenders.has('FEMALE')).toBe(true);
      expect(maleGenders.has('MALE')).toBe(true);

      const femaleView = await api()
        .get('/posts')
        .set('X-User-Id', ANDREA)
        .expect(200);
      const femaleGenders = new Set(
        femaleView.body.map(
          (p: { author: { gender: string } }) => p.author.gender,
        ),
      );
      expect(femaleGenders.has('MALE')).toBe(true);
      expect(femaleGenders.has('FEMALE')).toBe(true);
    });

    it('keeps in-progress activities visible with host attribution', async () => {
      // The seeded movie night is MATCHED with Liza's plan selected: it
      // must stay on the wall and carry the host attribution.
      const feed = await api()
        .get('/posts')
        .set('X-User-Id', MIGUEL)
        .expect(200);
      const matched = feed.body.find(
        (p: { id: string }) => p.id === 'post-003',
      );
      expect(matched).toBeDefined();
      expect(matched.status).toBe('MATCHED');
      expect(matched.selectedHost.id).toBe(LIZA);

      // Open posts have no attribution yet.
      const open = feed.body.find((p: { id: string }) => p.id === 'post-001');
      expect(open.selectedHost).toBeNull();

      // Cancelled posts leave the wall.
      const gone = await api()
        .post('/posts')
        .set('X-User-Id', MIGUEL)
        .send({ sceneTag: 'Dinner', title: 'Cancelled leaves the wall' })
        .expect(201);
      await api()
        .delete(`/posts/${gone.body.id}`)
        .set('X-User-Id', MIGUEL)
        .expect(200);
      const after = await api()
        .get('/posts')
        .set('X-User-Id', ANDREA)
        .expect(200);
      expect(
        after.body.find((p: { id: string }) => p.id === gone.body.id),
      ).toBeUndefined();
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
  });

  describe('notifications: in-app events along the match flow', () => {
    let postId: string;
    let orderId: string;

    it('applying notifies the poster', async () => {
      const postRes = await api()
        .post('/posts')
        .set('X-User-Id', ANDREA)
        .send({
          sceneTag: 'Movie',
          title: 'Notification flow',
        })
        .expect(201);
      postId = postRes.body.id;

      await api()
        .post(`/posts/${postId}/applications`)
        .set('X-User-Id', NOEL)
        .send({ proposal: 'Cafe in Makati, Saturday 3pm' })
        .expect(201);

      const count = await api()
        .get('/notifications/unread-count')
        .set('X-User-Id', ANDREA)
        .expect(200);
      expect(count.body.count).toBeGreaterThan(0);

      const list = await api()
        .get('/notifications')
        .set('X-User-Id', ANDREA)
        .expect(200);
      const latest = list.body[0];
      expect(latest.type).toBe('NEW_APPLICANT');
      expect(latest.actorName).toBe('Noel');
      expect(latest.postId).toBe(postId);
      expect(latest.isRead).toBe(false);
    });

    it('selection notifies the chosen candidate', async () => {
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

      const list = await api()
        .get('/notifications')
        .set('X-User-Id', NOEL)
        .expect(200);
      const latest = list.body[0];
      expect(latest.type).toBe('SELECTED');
      expect(latest.actorName).toBe('Andrea');
      expect(latest.orderId).toBe(orderId);
    });

    it('payment notifies the earning side', async () => {
      // New rule: the poster (Andrea) pays, the selected host (Noel) earns.
      await api()
        .post(`/orders/${orderId}/payment`)
        .set('X-User-Id', ANDREA)
        .expect(201);

      const list = await api()
        .get('/notifications')
        .set('X-User-Id', NOEL)
        .expect(200);
      expect(list.body[0].type).toBe('ORDER_PAID');
      expect(list.body[0].orderId).toBe(orderId);
    });

    it('cancelling notifies the counterparty, mark-all-read clears the badge', async () => {
      await api()
        .post(`/orders/${orderId}/cancel`)
        .set('X-User-Id', ANDREA)
        .expect(201);

      const list = await api()
        .get('/notifications')
        .set('X-User-Id', NOEL)
        .expect(200);
      expect(list.body[0].type).toBe('ORDER_CANCELLED');

      await api()
        .post('/notifications/read')
        .set('X-User-Id', NOEL)
        .expect(201);
      const count = await api()
        .get('/notifications/unread-count')
        .set('X-User-Id', NOEL)
        .expect(200);
      expect(count.body.count).toBe(0);
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
      expect(res.body.meta).toMatch(/^Female \u00b7 \d{2}$/);
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
          scheduledAt: '2026-11-01T19:00:00.000Z',
          place: 'Greenbelt 3, Makati',
          placeLat: 14.5525,
          placeLng: 121.0208,
        })
        .expect(201);
      postId = res.body.id;
      expect(res.body.feeMinor).toBe(100000);
      expect(res.body.status).toBe('OPEN');
      expect(res.body.scheduledAt).toBe('2026-11-01T19:00:00.000Z');
      expect(res.body.place).toBe('Greenbelt 3, Makati');
      expect(res.body.placeLat).toBeCloseTo(14.5525);
      expect(res.body.placeLng).toBeCloseTo(121.0208);
    });

    it('candidates of any gender sign up for free; invalid sign-ups are rejected', async () => {
      const jamesRes = await api()
        .post(`/posts/${postId}/applications`)
        .set('X-User-Id', JAMES)
        .send({ proposal: 'Cafe in Makati, Saturday 3pm' })
        .expect(201);
      jamesApplicationId = jamesRes.body.id;
      await api()
        .post(`/posts/${postId}/applications`)
        .set('X-User-Id', NOEL)
        .send({ proposal: 'Cafe in Makati, Saturday 3pm' })
        .expect(201);
      // Same-gender sign-up is allowed: the marketplace is gender-neutral.
      await api()
        .post(`/posts/${postId}/applications`)
        .set('X-User-Id', BIANCA)
        .send({ proposal: 'Cafe in Makati, Saturday 3pm' })
        .expect(201);

      // Only hosts can sign up; users invite hosts instead.
      await api()
        .post(`/posts/${postId}/applications`)
        .set('X-User-Id', MIGUEL)
        .send({ proposal: 'Cafe in Makati, Saturday 3pm' })
        .expect(403);
      // Duplicate sign-up rejected.
      await api()
        .post(`/posts/${postId}/applications`)
        .set('X-User-Id', JAMES)
        .send({ proposal: 'Cafe in Makati, Saturday 3pm' })
        .expect(409);
      // A proposal is required: selection means picking a plan.
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
      expect(res.body[0].proposal).toBe('Cafe in Makati, Saturday 3pm');
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
      expect(res.body.feeMinor).toBe(100000);
      expect(res.body.commissionMinor).toBe(10000);
      expect(res.body.netMinor).toBe(90000);

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
      expect(escrow._sum.amountMinor).toBe(100000);
    });

    it('the host proposes the concrete plan; the poster confirms it', async () => {
      // Only the host (earner) can propose.
      await api()
        .post(`/orders/${orderId}/plan`)
        .set('X-User-Id', ANDREA)
        .send({
          place: 'Single Origin, Makati',
          scheduledAt: '2026-11-02T19:00:00.000Z',
        })
        .expect(403);

      const proposed = await api()
        .post(`/orders/${orderId}/plan`)
        .set('X-User-Id', JAMES)
        .send({
          place: 'Single Origin, Makati',
          placeLat: 14.5531,
          placeLng: 121.0215,
          scheduledAt: '2026-11-02T19:00:00.000Z',
        })
        .expect(201);
      expect(proposed.body.planProposedAt).not.toBeNull();
      expect(proposed.body.planConfirmedAt).toBeNull();
      // Effective place/time still come from the post until confirmation.
      expect(proposed.body.place).toBe('Greenbelt 3, Makati');

      // The poster was notified of the proposal.
      const inbox = await api()
        .get('/notifications')
        .set('X-User-Id', ANDREA)
        .expect(200);
      expect(inbox.body[0].type).toBe('PLAN_PROPOSED');

      // Only the poster confirms.
      await api()
        .post(`/orders/${orderId}/plan/confirm`)
        .set('X-User-Id', JAMES)
        .expect(403);
      const confirmed = await api()
        .post(`/orders/${orderId}/plan/confirm`)
        .set('X-User-Id', ANDREA)
        .expect(201);
      expect(confirmed.body.planConfirmedAt).not.toBeNull();
      // The confirmed plan becomes the effective place and time.
      expect(confirmed.body.place).toBe('Single Origin, Makati');
      expect(confirmed.body.scheduledAt).toBe('2026-11-02T19:00:00.000Z');
      expect(confirmed.body.placeLat).toBeCloseTo(14.5531);

      // Double confirmation conflicts.
      await api()
        .post(`/orders/${orderId}/plan/confirm`)
        .set('X-User-Id', ANDREA)
        .expect(409);

      // The host re-proposes a new time: confirmation resets.
      const reproposed = await api()
        .post(`/orders/${orderId}/plan`)
        .set('X-User-Id', JAMES)
        .send({
          place: 'Single Origin, Makati',
          placeLat: 14.5531,
          placeLng: 121.0215,
          scheduledAt: '2026-11-02T20:00:00.000Z',
        })
        .expect(201);
      expect(reproposed.body.planConfirmedAt).toBeNull();
      await api()
        .post(`/orders/${orderId}/plan/confirm`)
        .set('X-User-Id', ANDREA)
        .expect(201);
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
      expect(allRes.body.length).toBe(2);
      expect(allRes.body[0].text).toBe('See you at 7!');

      // incremental poll: only messages after the anchor id
      const afterRes = await api()
        .get(`/orders/${orderId}/messages`)
        .query({ afterId: sendRes.body.id })
        .set('X-User-Id', JAMES)
        .expect(200);
      expect(afterRes.body.length).toBe(1);
      expect(afterRes.body[0].text).toBe('Looking forward to it');
    });

    it('phones are disclosed after escrow; locations drive the distance readout', async () => {
      const order = await api()
        .get(`/orders/${orderId}`)
        .set('X-User-Id', JAMES)
        .expect(200);
      expect(order.body.payerPhone).toMatch(/^\+63/);
      expect(order.body.earnerPhone).toMatch(/^\+63/);
      expect(order.body.distanceKm).toBeNull();

      // Makati CBD, roughly 1.3 km apart.
      await api()
        .post(`/orders/${orderId}/location`)
        .set('X-User-Id', JAMES)
        .send({ lat: 14.5547, lng: 121.0244 })
        .expect(201);
      const located = await api()
        .post(`/orders/${orderId}/location`)
        .set('X-User-Id', ANDREA)
        .send({ lat: 14.5657, lng: 121.0288 })
        .expect(201);
      expect(located.body.distanceKm).toBeGreaterThan(1);
      expect(located.body.distanceKm).toBeLessThan(2);
    });

    it('one-tap meet confirmation requires GPS colocation', async () => {
      // James confirms from across the city first.
      const far = await api()
        .post(`/orders/${orderId}/meet`)
        .set('X-User-Id', JAMES)
        .send({ lat: 14.7, lng: 121.1 })
        .expect(201);
      expect(far.body.status).toBe('ACTIVE');
      expect(far.body.earnerMetAt).not.toBeNull();

      // Andrea confirms at the cafe; fixes are too far apart -> rejected.
      const rejected = await api()
        .post(`/orders/${orderId}/meet`)
        .set('X-User-Id', ANDREA)
        .send({ lat: 14.5547, lng: 121.0244 })
        .expect(409);
      expect(rejected.body.message).toBe('NOT_TOGETHER');

      // James re-taps once actually at the cafe (~15 m away) -> MET.
      const met = await api()
        .post(`/orders/${orderId}/meet`)
        .set('X-User-Id', JAMES)
        .send({ lat: 14.5548, lng: 121.0245 })
        .expect(201);
      expect(met.body.status).toBe('MET');
      expect(met.body.metAt).not.toBeNull();
      expect(met.body.settleAt).not.toBeNull();

      // A met order can no longer be cancelled; money is protected.
      await api()
        .post(`/orders/${orderId}/cancel`)
        .set('X-User-Id', JAMES)
        .expect(409);
    });

    it('auto-settles on the next read once the delay elapsed', async () => {
      process.env.MEET_SETTLE_DELAY_MS = '0';
      const order = await api()
        .get(`/orders/${orderId}`)
        .set('X-User-Id', ANDREA)
        .expect(200);
      process.env.MEET_SETTLE_DELAY_MS = '3600000';
      expect(order.body.status).toBe('COMPLETED');

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
      expect(revenue._sum.amountMinor).toBe(10000);

      // The earner was notified that the money landed.
      const inbox = await api()
        .get('/notifications')
        .set('X-User-Id', JAMES)
        .expect(200);
      expect(
        inbox.body.some(
          (n: { type: string; orderId: string }) =>
            n.type === 'ORDER_SETTLED' && n.orderId === orderId,
        ),
      ).toBe(true);
    });

    it('the earner wallet reflects net income and supports withdrawal', async () => {
      const wallet = await api()
        .get('/wallet')
        .set('X-User-Id', JAMES)
        .expect(200);
      expect(wallet.body.balanceMinor).toBe(90000);
      expect(wallet.body.monthIncomeMinor).toBe(90000);

      await api()
        .post('/wallet/withdrawals')
        .set('X-User-Id', JAMES)
        .send({ amountMinor: 50000 })
        .expect(201);
      const after = await api()
        .get('/wallet')
        .set('X-User-Id', JAMES)
        .expect(200);
      expect(after.body.balanceMinor).toBe(40000);

      // Overdraft rejected.
      await api()
        .post('/wallet/withdrawals')
        .set('X-User-Id', JAMES)
        .send({ amountMinor: 100000 })
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
        .send({ proposal: 'Cafe in Makati, Saturday 3pm' })
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

      const feed = await api()
        .get('/posts')
        .set('X-User-Id', ANDREA)
        .expect(200);
      expect(
        feed.body.find((p: { id: string }) => p.id === post.body.id),
      ).toBeUndefined();

      // Deleting again conflicts (no longer OPEN).
      await api()
        .delete(`/posts/${post.body.id}`)
        .set('X-User-Id', MIGUEL)
        .expect(409);
    });
  });

  describe('dispute: freezes auto-settlement', () => {
    let orderId: string;

    it('met order can be disputed by a participant', async () => {
      const post = await api()
        .post('/posts')
        .set('X-User-Id', MIGUEL)
        .send({ sceneTag: 'Dinner', title: 'Dispute flow' })
        .expect(201);
      await api()
        .post(`/posts/${post.body.id}/applications`)
        .set('X-User-Id', KAT)
        .send({ proposal: 'Cafe in Makati, Saturday 3pm' })
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
      orderId = order.body.id;
      await api()
        .post(`/orders/${orderId}/payment`)
        .set('X-User-Id', MIGUEL)
        .expect(201);

      // Dispute requires MET.
      await api()
        .post(`/orders/${orderId}/dispute`)
        .set('X-User-Id', MIGUEL)
        .expect(409);

      await api()
        .post(`/orders/${orderId}/meet`)
        .set('X-User-Id', MIGUEL)
        .send({ lat: 14.55, lng: 121.02 })
        .expect(201);
      await api()
        .post(`/orders/${orderId}/meet`)
        .set('X-User-Id', KAT)
        .send({ lat: 14.5501, lng: 121.0201 })
        .expect(201);

      const disputed = await api()
        .post(`/orders/${orderId}/dispute`)
        .set('X-User-Id', MIGUEL)
        .expect(201);
      expect(disputed.body.status).toBe('DISPUTED');
    });

    it('a disputed order never auto-settles', async () => {
      process.env.MEET_SETTLE_DELAY_MS = '0';
      const order = await api()
        .get(`/orders/${orderId}`)
        .set('X-User-Id', KAT)
        .expect(200);
      process.env.MEET_SETTLE_DELAY_MS = '3600000';
      expect(order.body.status).toBe('DISPUTED');

      // Escrow still holds the fee; nothing was paid out.
      const escrow = await prisma.ledgerEntry.aggregate({
        where: { account: 'PLATFORM_ESCROW', orderId },
        _sum: { amountMinor: true },
      });
      expect(escrow._sum.amountMinor).toBe(100000);
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
        .send({ proposal: 'Cafe in Makati, Saturday 3pm' })
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
        .send({ proposal: 'A plan from the wrong side' })
        .expect(403);
    });
  });

  describe('host directory + direct invitations', () => {
    let invitationId: string;
    let acceptedOrderId: string;

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

    it('a user invites a host; hosts cannot invite', async () => {
      const res = await api()
        .post('/invitations')
        .set('X-User-Id', ANDREA)
        .send({
          hostId: BIANCA,
          sceneTag: 'Coffee',
          note: 'Plan me a quiet cafe afternoon',
        })
        .expect(201);
      invitationId = res.body.id;
      expect(res.body.status).toBe('PENDING');
      expect(res.body.from.id).toBe(ANDREA);
      expect(res.body.host.id).toBe(BIANCA);

      // Duplicate pending invitation to the same host conflicts.
      await api()
        .post('/invitations')
        .set('X-User-Id', ANDREA)
        .send({ hostId: BIANCA, sceneTag: 'Dinner', note: '' })
        .expect(409);

      // Hosts cannot invite, and only hosts can be invited.
      await api()
        .post('/invitations')
        .set('X-User-Id', JAMES)
        .send({ hostId: NOEL, sceneTag: 'Coffee', note: '' })
        .expect(403);
      await api()
        .post('/invitations')
        .set('X-User-Id', ANDREA)
        .send({ hostId: MIGUEL, sceneTag: 'Coffee', note: '' })
        .expect(404);

      // The invited host was notified and sees it in their list.
      const inbox = await api()
        .get('/notifications')
        .set('X-User-Id', BIANCA)
        .expect(200);
      expect(inbox.body[0].type).toBe('INVITE_RECEIVED');
      const mine = await api()
        .get('/invitations')
        .set('X-User-Id', BIANCA)
        .expect(200);
      expect(
        mine.body.some((i: { id: string }) => i.id === invitationId),
      ).toBe(true);
    });

    it('only the invited host can respond; accepting creates the order', async () => {
      await api()
        .post(`/invitations/${invitationId}/accept`)
        .set('X-User-Id', NOEL)
        .expect(403);
      await api()
        .post(`/invitations/${invitationId}/accept`)
        .set('X-User-Id', ANDREA)
        .expect(403);

      const res = await api()
        .post(`/invitations/${invitationId}/accept`)
        .set('X-User-Id', BIANCA)
        .expect(201);
      acceptedOrderId = res.body.id;
      expect(res.body.status).toBe('AWAITING_PAYMENT');
      expect(res.body.payer.id).toBe(ANDREA);
      expect(res.body.earner.id).toBe(BIANCA);
      expect(res.body.feeMinor).toBe(60000); // Coffee fee snapshot

      // The inviter was notified with the order reference.
      const inbox = await api()
        .get('/notifications')
        .set('X-User-Id', ANDREA)
        .expect(200);
      expect(inbox.body[0].type).toBe('INVITE_ACCEPTED');
      expect(inbox.body[0].orderId).toBe(acceptedOrderId);

      // Responding twice conflicts.
      await api()
        .post(`/invitations/${invitationId}/accept`)
        .set('X-User-Id', BIANCA)
        .expect(409);

      // The backing direct post never shows in the open feed.
      const feed = await api()
        .get('/posts')
        .set('X-User-Id', MIGUEL)
        .expect(200);
      const order = await api()
        .get(`/orders/${acceptedOrderId}`)
        .set('X-User-Id', ANDREA)
        .expect(200);
      expect(
        feed.body.find((p: { id: string }) => p.id === order.body.postId),
      ).toBeUndefined();

      // Downstream is the standard flow: the inviter pays into escrow.
      const paid = await api()
        .post(`/orders/${acceptedOrderId}/payment`)
        .set('X-User-Id', ANDREA)
        .expect(201);
      expect(paid.body.status).toBe('ACTIVE');

      // Even once in progress (MATCHED), the direct post stays private:
      // the wall now lists in-progress activities, DIRECT must not leak.
      const wall = await api()
        .get('/posts')
        .set('X-User-Id', MIGUEL)
        .expect(200);
      expect(
        wall.body.find((p: { id: string }) => p.id === order.body.postId),
      ).toBeUndefined();
    });

    it('declining notifies the inviter and allows re-inviting', async () => {
      const invite = await api()
        .post('/invitations')
        .set('X-User-Id', MIGUEL)
        .send({ hostId: NOEL, sceneTag: 'Bar', note: 'Friday night plan' })
        .expect(201);
      const declined = await api()
        .post(`/invitations/${invite.body.id}/decline`)
        .set('X-User-Id', NOEL)
        .expect(201);
      expect(declined.body.status).toBe('DECLINED');

      const inbox = await api()
        .get('/notifications')
        .set('X-User-Id', MIGUEL)
        .expect(200);
      expect(inbox.body[0].type).toBe('INVITE_DECLINED');

      // Once declined, the pair can start a fresh invitation.
      await api()
        .post('/invitations')
        .set('X-User-Id', MIGUEL)
        .send({ hostId: NOEL, sceneTag: 'Bar', note: 'Another try' })
        .expect(201);
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
        })
        .expect(201);
      expect(userMoment.body.type).toBe('MOMENT');
      expect(userMoment.body.feeMinor).toBe(0);
      expect(userMoment.body.images).toEqual([
        '/uploads/recap1.jpg',
        '/uploads/recap2.jpg',
      ]);

      await api()
        .post('/posts/moments')
        .set('X-User-Id', JAMES)
        .send({ text: 'Hosted a great cafe crawl today' })
        .expect(201);

      // Text is required.
      await api()
        .post('/posts/moments')
        .set('X-User-Id', ANDREA)
        .send({ images: ['/uploads/x.jpg'] })
        .expect(400);

      const feed = await api()
        .get('/posts')
        .set('X-User-Id', MIGUEL)
        .expect(200);
      const types = new Set(feed.body.map((p: { type: string }) => p.type));
      expect(types.has('MOMENT')).toBe(true);
      expect(types.has('DEMAND')).toBe(true);

      // Moments never take sign-ups.
      await api()
        .post(`/posts/${userMoment.body.id}/applications`)
        .set('X-User-Id', NOEL)
        .send({ proposal: 'Not applicable' })
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
          sceneFees: { Coffee: 70000 },
        })
        .expect(403);

      await api()
        .put('/admin/pricing')
        .set('X-User-Id', ADMIN)
        .send({
          platformFeeRateBp: 1500,
          defaultFeeMinor: 60000,
          sceneFees: { Coffee: 70000, Dinner: 100000 },
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
        .send({ proposal: 'Cafe in Makati, Saturday 3pm' })
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
});
