import { api, majorToMinor } from '@/api/client';
import {
  toHostCard,
  toInvitation,
  toLiveOrder,
  toProposalCard,
} from '@/api/mappers';
import type {
  HostCard,
  InvitationRecord,
  LiveOrder,
  ProposalCard,
} from '@/types/models';

type Json = Record<string, unknown>;

export async function fetchHosts(): Promise<HostCard[]> {
  const json = (await api.get('/hosts')) as Json[];
  return json.map(toHostCard);
}

export async function fetchHost(hostId: string): Promise<HostCard> {
  return toHostCard((await api.get(`/hosts/${hostId}`)) as Json);
}

export async function fetchProposals(): Promise<ProposalCard[]> {
  const json = (await api.get('/proposals')) as Json[];
  return json.map(toProposalCard);
}

export async function fetchProposal(
  proposalId: string,
): Promise<ProposalCard> {
  return toProposalCard((await api.get(`/proposals/${proposalId}`)) as Json);
}

export async function createProposal(input: {
  templateId: string;
  title: string;
  description: string;
  /** The host's rough availability window: ANYTIME | NOON | EVENING. */
  timeSlot: string;
}): Promise<ProposalCard> {
  const body: Json = {
    templateId: input.templateId,
    title: input.title,
    timeSlot: input.timeSlot,
  };
  if (input.description.length > 0) body.description = input.description;
  return toProposalCard((await api.post('/proposals', body)) as Json);
}

/** Inviting carries the deal terms: the inviter picks the concrete time
 * (inside the pitch's window) and the price tier. */
export async function inviteToProposal(
  proposalId: string,
  input: { scheduledAt: Date; budget: number; note: string },
): Promise<InvitationRecord> {
  const body: Json = {
    scheduledAt: input.scheduledAt.toISOString(),
    budgetMinor: majorToMinor(input.budget),
  };
  if (input.note.length > 0) body.note = input.note;
  return toInvitation(
    (await api.post(`/proposals/${proposalId}/invitations`, body)) as Json,
  );
}

export async function fetchProposalInvites(
  proposalId: string,
): Promise<InvitationRecord[]> {
  const json = (await api.get(
    `/proposals/${proposalId}/invitations`,
  )) as Json[];
  return json.map(toInvitation);
}

/** Picks one invitation; the plan is already fixed by the pitch. Returns
 * the created order. */
export async function selectInvite(
  proposalId: string,
  invitationId: string,
): Promise<LiveOrder> {
  return toLiveOrder(
    (await api.post(
      `/proposals/${proposalId}/invitations/${invitationId}/select`,
      {},
    )) as Json,
  );
}
