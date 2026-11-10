import { api, majorToMinor } from '@/api/client';
import { toConversation, toLiveOrder, toOrderMessage } from '@/api/mappers';
import type {
  ConversationItem,
  LiveOrder,
  OrderMessage,
} from '@/types/models';

type Json = Record<string, unknown>;

export async function listMine(all = false): Promise<LiveOrder[]> {
  const json = (await api.get(
    '/orders',
    all ? { view: 'all' } : undefined,
  )) as Json[];
  return json.map(toLiveOrder);
}

/** The contact-style conversation list, one row per partner. */
export async function fetchConversations(): Promise<ConversationItem[]> {
  const json = (await api.get('/orders/conversations')) as Json[];
  return json.map(toConversation);
}

export async function getOrder(orderId: string): Promise<LiveOrder> {
  return toLiveOrder((await api.get(`/orders/${orderId}`)) as Json);
}

/** The non-cancelled order attached to a post, if any. */
export async function findByPostId(postId: string): Promise<LiveOrder | null> {
  // Full view: a freshly created order is still unpaid and would be
  // invisible in the conversations view.
  const orders = await listMine(true);
  return (
    orders.find((o) => o.postId === postId && o.status !== 'CANCELLED') ?? null
  );
}

export async function pay(orderId: string): Promise<LiveOrder> {
  return toLiveOrder((await api.post(`/orders/${orderId}/payment`)) as Json);
}

export async function cancel(orderId: string): Promise<LiveOrder> {
  return toLiveOrder((await api.post(`/orders/${orderId}/cancel`)) as Json);
}

/** In-room safety report, filed by either participant. Settlement stays
 * frozen while the report is open. */
export async function reportOrder(
  orderId: string,
  reason: string,
): Promise<void> {
  await api.post(`/orders/${orderId}/report`, { reason });
}

/** The host submits the payer's meet code to start the service. */
export async function start(
  orderId: string,
  code: string,
): Promise<LiveOrder> {
  return toLiveOrder(
    (await api.post(`/orders/${orderId}/start`, { code })) as Json,
  );
}

export async function sendMessage(
  orderId: string,
  text: string,
): Promise<OrderMessage> {
  return toOrderMessage(
    (await api.post(`/orders/${orderId}/messages`, { text })) as Json,
  );
}

/** The payer sends a rebooking card into the conversation: template +
 * concrete time + price tier, same deal terms as an invitation. */
export async function sendActivityRequest(
  orderId: string,
  input: { templateId: string; scheduledAt: Date; budget: number; note: string },
): Promise<OrderMessage> {
  const body: Json = {
    templateId: input.templateId,
    scheduledAt: input.scheduledAt.toISOString(),
    budgetMinor: majorToMinor(input.budget),
  };
  if (input.note.length > 0) body.note = input.note;
  return toOrderMessage(
    (await api.post(`/orders/${orderId}/messages/request`, body)) as Json,
  );
}

/** The host accepts or declines a rebooking card; accepting creates the
 * new order (its id lands in the returned card's payload). */
export async function respondActivityRequest(
  orderId: string,
  messageId: string,
  accept: boolean,
): Promise<OrderMessage> {
  return toOrderMessage(
    (await api.post(`/orders/${orderId}/messages/${messageId}/respond`, {
      accept,
    })) as Json,
  );
}

export async function listMessages(
  orderId: string,
  afterId?: string,
): Promise<OrderMessage[]> {
  const json = (await api.get(
    `/orders/${orderId}/messages`,
    afterId ? { afterId } : undefined,
  )) as Json[];
  return json.map(toOrderMessage);
}

// --- Client-side order helpers (mirror LiveOrder getters in Flutter) ---

export function isCancellableNow(order: LiveOrder): boolean {
  return (
    order.status === 'ACTIVE' &&
    order.startedAt === null &&
    order.cancellableUntil !== null &&
    Date.now() < order.cancellableUntil.getTime()
  );
}

export function peerOf(order: LiveOrder, userId: string) {
  return order.payer.id === userId ? order.earner : order.payer;
}

export function peerPhoneOf(order: LiveOrder, userId: string): string {
  return order.payer.id === userId ? order.earnerPhone : order.payerPhone;
}
