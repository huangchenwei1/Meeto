import { ref } from 'vue';

/**
 * Journeys with a counterpart action waiting (signups on my posts,
 * invites on my pitches); badges the My Activities tab. Updated by the
 * My Activities page, read by the tab shell.
 */
export const actionableCount = ref(0);

/**
 * Unread partner messages summed across every conversation; badges the
 * Messages tab. Kept fresh by the tab shell's poll and by the chats page
 * whenever it refreshes its list.
 */
export const unreadChatCount = ref(0);
