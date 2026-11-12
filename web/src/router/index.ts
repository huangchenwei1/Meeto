import { createRouter, createWebHistory } from 'vue-router';

import { realPersonVerificationEnabled } from '@/constants/features';
import { useSessionStore } from '@/stores/session';
import { isLaunchSplashPending } from '@/utils/launchSplash';

export const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/login',
      name: 'login',
      component: () => import('@/pages/LoginPage.vue'),
      meta: { public: true },
    },
    {
      path: '/setup',
      name: 'setup',
      component: () => import('@/pages/ProfileSetupPage.vue'),
      meta: { public: true },
    },
    {
      path: '/splash',
      name: 'splash',
      component: () => import('@/pages/SplashPage.vue'),
      meta: { public: true },
    },
    {
      path: '/',
      component: () => import('@/pages/TabsShell.vue'),
      children: [
        { path: '', redirect: '/hall' },
        {
          path: 'hall',
          name: 'hall',
          component: () => import('@/pages/HallPage.vue'),
        },
        {
          path: 'chats',
          name: 'chats',
          component: () => import('@/pages/ChatsPage.vue'),
        },
        {
          path: 'activities',
          name: 'activities',
          component: () => import('@/pages/MyActivitiesPage.vue'),
        },
        {
          path: 'me',
          name: 'me',
          component: () => import('@/pages/ProfilePage.vue'),
        },
      ],
    },
    {
      path: '/posts/:id',
      name: 'post-detail',
      component: () => import('@/pages/PostDetailPage.vue'),
    },
    {
      path: '/proposals/:id',
      name: 'proposal-detail',
      component: () => import('@/pages/ProposalDetailPage.vue'),
    },
    {
      path: '/publish',
      name: 'publish',
      component: () => import('@/pages/ComposerPage.vue'),
    },
    {
      path: '/orders/:id/pay',
      name: 'pay',
      component: () => import('@/pages/PayPage.vue'),
    },
    {
      path: '/orders/:id',
      name: 'order-room',
      component: () => import('@/pages/OrderRoomPage.vue'),
    },
    {
      path: '/wallet',
      name: 'wallet',
      component: () => import('@/pages/WalletPage.vue'),
    },
    {
      path: '/users/:id',
      name: 'user-profile',
      component: () => import('@/pages/UserProfilePage.vue'),
    },
    {
      path: '/my-posts',
      name: 'my-posts',
      component: () => import('@/pages/MyPostsPage.vue'),
    },
    ...(realPersonVerificationEnabled
      ? [
          {
            path: '/verification',
            name: 'verification',
            component: () => import('@/pages/VerificationPage.vue'),
          },
        ]
      : []),
    {
      path: '/guidelines',
      name: 'guidelines',
      component: () => import('@/pages/GuidelinesPage.vue'),
    },
    {
      // Catch-all: typos and dead links land on a friendly page instead
      // of a blank screen.
      path: '/:pathMatch(.*)*',
      name: 'not-found',
      component: () => import('@/pages/NotFoundPage.vue'),
      meta: { public: true },
    },
  ],
});

router.beforeEach((to) => {
  const session = useSessionStore();
  // Splash runs once each time the site is opened, before login or the app.
  if (to.name !== 'splash' && isLaunchSplashPending()) {
    return { name: 'splash', query: { next: to.fullPath } };
  }
  if (!to.meta.public && !session.isSignedIn) {
    return { name: 'login' };
  }
  if (to.name === 'login' && session.isSignedIn) {
    return { name: 'hall' };
  }
  return true;
});
