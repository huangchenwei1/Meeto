import { api, majorToMinor, resolveMediaUrl } from '@/api/client';
import { toActivityPost, toAuthor } from '@/api/mappers';
import type {
  ActivityPost,
  ActivityTemplate,
  Candidate,
  SignupNotice,
} from '@/types/models';

type Json = Record<string, unknown>;

/** Curated activity templates — the only publish path; both roles read
 * the same list. */
export async function fetchTemplates(): Promise<ActivityTemplate[]> {
  const json = (await api.get('/templates')) as Json[];
  return json.map((e) => ({
    id: e.id as string,
    sceneTag: e.sceneTag as string,
    title: e.title as string,
    description: (e.description as string) ?? '',
    imageUrl: resolveMediaUrl((e.imageUrl as string) ?? ''),
    durationLabel: (e.durationLabel as string) ?? '',
    venueName: (e.venueName as string) ?? '',
    meetingPoint: (e.meetingPoint as string) ?? '',
    area: (e.area as string) ?? '',
  }));
}

/** Open demand posts for the hall feed. */
export async function fetchOpenRequests(): Promise<ActivityPost[]> {
  const json = (await api.get('/posts', { view: 'requests' })) as Json[];
  return json.map(toActivityPost);
}

/** Demand posts the caller signed up on. */
export async function fetchAppliedRequests(): Promise<ActivityPost[]> {
  const json = (await api.get('/posts', { view: 'applied' })) as Json[];
  return json.map(toActivityPost);
}

export async function fetchPostsByAuthor(
  authorId: string,
): Promise<ActivityPost[]> {
  const json = (await api.get('/posts', { authorId })) as Json[];
  return json.map(toActivityPost);
}

export async function fetchPostById(postId: string): Promise<ActivityPost> {
  return toActivityPost((await api.get(`/posts/${postId}`)) as Json);
}

export interface CreatePostInput {
  templateId: string;
  title: string;
  description: string;
  /** The concrete meeting time; duration is the platform standard. */
  scheduledAt: Date;
  budget: number;
}

export async function createPost(
  input: CreatePostInput,
): Promise<ActivityPost> {
  // The expense policy is not sent: on-site expenses are always on the
  // publisher (the server defaults to TREAT).
  const body: Json = {
    templateId: input.templateId,
    title: input.title,
    scheduledAt: input.scheduledAt.toISOString(),
  };
  if (input.description.length > 0) body.description = input.description;
  if (input.budget > 0) body.budgetMinor = majorToMinor(input.budget);
  return toActivityPost((await api.post('/posts', body)) as Json);
}

export async function deletePost(postId: string): Promise<void> {
  await api.delete(`/posts/${postId}`);
}

/** One-tap sign-up into the candidate pool; returns the fresh post. The
 * activity is fully fixed by the template and the post, so the sign-up
 * carries nothing. */
export async function signUp(postId: string): Promise<ActivityPost> {
  await api.post(`/posts/${postId}/applications`, {});
  return fetchPostById(postId);
}

/** Pending sign-ups across everything I published, newest first. The
 * caller diffs against a locally stored last-seen timestamp to surface
 * only fresh ones. */
export async function fetchSignupNotices(): Promise<SignupNotice[]> {
  const json = (await api.get('/posts/signups/notice')) as Json[];
  return json.map((e) => ({
    id: e.id as string,
    kind: e.kind as SignupNotice['kind'],
    targetId: e.targetId as string,
    actor: toAuthor(e.actor as Json),
    createdAt: new Date(e.createdAt as string),
  }));
}

/** Candidate pool (post author only), with application ids kept for selection. */
export async function fetchCandidates(postId: string): Promise<Candidate[]> {
  const json = (await api.get(`/posts/${postId}/applications`)) as Json[];
  return json.map((application) => ({
    applicationId: application.id as string,
    author: toAuthor(application.applicant as Json),
  }));
}

/** Approves one candidate; the server creates an AWAITING_PAYMENT order. */
export async function selectCandidate(
  postId: string,
  applicationId: string,
): Promise<void> {
  await api.post(`/posts/${postId}/selection`, { applicationId });
}
