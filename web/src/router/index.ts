import { createRouter, createWebHistory } from 'vue-router';

import { INTRO_SEEN_KEY, isProfileReady, markProfileReady } from '@/constants/guest';
import { useSessionStore } from '@/stores/session';

export const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/intro',
      name: 'intro',
      component: () => import('@/pages/IntroPage.vue'),
      meta: { public: true },
    },
    {
      path: '/boot',
      name: 'boot',
      component: () => import('@/pages/BootPage.vue'),
      meta: { public: true },
    },
    {
      path: '/setup',
      name: 'setup',
      component: () => import('@/pages/ProfileSetupPage.vue'),
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

function registrationFinished(): boolean {
  if (isProfileReady()) return true;
  const session = useSessionStore();
  if (session.isSignedIn && (session.user?.avatarUrl ?? '') !== '') {
    markProfileReady();
    return true;
  }
  return false;
}

function splashTarget(fullPath: string): { name: 'boot' | 'intro'; query?: { next: string } } {
  const name = registrationFinished() ? 'boot' : 'intro';
  return fullPath === '/' ? { name } : { name, query: { next: fullPath } };
}

router.beforeEach((to) => {
  const session = useSessionStore();
  const introSeen = sessionStorage.getItem(INTRO_SEEN_KEY) === '1';
  const ready = registrationFinished();
  const profileOpen = session.isSignedIn && (session.user?.avatarUrl ?? '') === '';
  if (!introSeen && to.name !== 'intro' && to.name !== 'boot') {
    return splashTarget(to.fullPath);
  }
  const carried = typeof to.query.next === 'string' ? to.query.next : '/';
  if (to.name === 'intro' && ready) return splashTarget(carried);
  if (to.name === 'boot' && !ready) return splashTarget(carried);
  // Registration still runs after the story splash. Only role and gender are skipped.
  if (profileOpen && !ready && to.name !== 'setup' && to.name !== 'intro' && to.name !== 'boot') {
    return { name: 'setup', query: { resume: '1' } };
  }
  if (!to.meta.public && !session.isSignedIn) {
    return { name: 'intro' };
  }
  return true;
});
