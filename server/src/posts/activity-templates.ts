/// Curated activity templates — the ONLY publish entry: picking one
/// prefills the composer (users post a request, hosts post a pitch).
/// The platform controls the full activity envelope: scene, cover,
/// district, partner venue and the exact meeting point. Publishers only
/// bring their own words (title + description) and pick a meeting time.
/// Operations-owned content: identifiers stay English, display copy is
/// whatever the market speaks. Hand-picked Manila list standing in for
/// the future ops console. The budget is not stored here — it is the
/// platform scene fee, resolved from pricing at display time.

/// Every activity runs on one platform-standard duration: the settlement
/// clock and all "about X hours" copy derive from this single value, so
/// users never pick (or dispute) a duration.
export const ACTIVITY_DURATION_MINUTES = 120;

/// Host working window, Manila local time (UTC+8, no DST). A safety rule
/// as much as an ops rule: hosts are on the clock 09:00-22:00, so an
/// activity must start at opening or later and END by closing - with the
/// standard duration the latest start is 19:00. The composer only offers
/// slots inside this window; this guard is the server-side backstop.
export const MANILA_UTC_OFFSET_HOURS = 8;
export const MEETING_OPEN_HOUR = 9;
export const MEETING_CLOSE_HOUR = 22;

export function isWithinMeetingHours(at: Date): boolean {
  const manila = new Date(
    at.getTime() + MANILA_UTC_OFFSET_HOURS * 3600 * 1000,
  );
  const minutesOfDay = manila.getUTCHours() * 60 + manila.getUTCMinutes();
  const openMinutes = MEETING_OPEN_HOUR * 60;
  const lastStartMinutes =
    MEETING_CLOSE_HOUR * 60 - ACTIVITY_DURATION_MINUTES;
  return minutesOfDay >= openMinutes && minutesOfDay <= lastStartMinutes;
}

/// A host pitch advertises availability, not a scheduled event: the host
/// declares one of these rough windows and the INVITER picks the concrete
/// start time inside it (and inside working hours). Ranges are Manila
/// local START times, inclusive.
export const PROPOSAL_TIME_SLOTS: Record<
  string,
  { startHour: number; endHour: number }
> = {
  ANYTIME: {
    startHour: MEETING_OPEN_HOUR,
    endHour: MEETING_CLOSE_HOUR - ACTIVITY_DURATION_MINUTES / 60,
  },
  NOON: { startHour: 11, endHour: 14 },
  EVENING: {
    startHour: 17,
    endHour: MEETING_CLOSE_HOUR - ACTIVITY_DURATION_MINUTES / 60,
  },
};

export function isWithinProposalSlot(slot: string, at: Date): boolean {
  const window = PROPOSAL_TIME_SLOTS[slot];
  if (!window) return false;
  const manila = new Date(
    at.getTime() + MANILA_UTC_OFFSET_HOURS * 3600 * 1000,
  );
  const minutesOfDay = manila.getUTCHours() * 60 + manila.getUTCMinutes();
  return (
    minutesOfDay >= window.startHour * 60 &&
    minutesOfDay <= window.endHour * 60
  );
}

export interface ActivityTemplate {
  id: string;
  sceneTag: string;
  title: string;
  description: string;
  imageUrl: string;
  /// Display label for the suggested duration, e.g. "建议 2–3 小时".
  /// Display-only: settlement always uses ACTIVITY_DURATION_MINUTES.
  durationLabel: string;
  /// Partner venue the activity anchors to, e.g. "Glorietta Mall".
  venueName: string;
  /// The exact meeting point inside the venue; becomes the order's plan
  /// place verbatim, so both sides always know where to stand.
  meetingPoint: string;
  /// City district for card display and filtering, e.g. "Makati".
  area: string;
}

export const ACTIVITY_TEMPLATES: ActivityTemplate[] = [
  {
    id: 'template-japanese-dinner-date',
    sceneTag: 'Dinner',
    title: '日式美食约会',
    description:
      '在 Little Tokyo 正门碰面，挑一家日料店：寿司、烧鸟或拉面都好。',
    imageUrl:
      'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?auto=format&fit=crop&w=800&h=800&q=80',
    durationLabel: '约 2 小时',
    venueName: 'Little Tokyo',
    meetingPoint: 'Little Tokyo 正门',
    area: 'Makati',
  },
  {
    id: 'template-korean-bbq-date',
    sceneTag: 'Dinner',
    title: '韩式烤肉约会',
    description:
      '在 High Street 主入口碰面，一起吃韩式烤肉，饭后沿步行街散步。',
    imageUrl:
      'https://images.unsplash.com/photo-1590301157890-4810ed352733?auto=format&fit=crop&w=800&h=800&q=80',
    durationLabel: '约 2 小时',
    venueName: 'Bonifacio High Street',
    meetingPoint: 'Bonifacio High Street 主入口',
    area: 'BGC, Taguig',
  },
  {
    id: 'template-chinese-hotpot-date',
    sceneTag: 'Dinner',
    title: '中式火锅约会',
    description:
      '在 Mall of Asia 海底捞门口碰面，吃火锅聊天，轻松不冷场。',
    imageUrl:
      'https://images.unsplash.com/photo-1541529086526-db283c563270?auto=format&fit=crop&w=800&h=800&q=80',
    durationLabel: '约 2 小时',
    venueName: 'Mall of Asia',
    meetingPoint: 'Mall of Asia 海底捞门口',
    area: 'Pasay',
  },
  {
    id: 'template-western-steak-date',
    sceneTag: 'Dinner',
    title: '西式牛排约会',
    description:
      '在 Glorietta Mall 主入口碰面，选一家牛排馆，适合安静聊天。',
    imageUrl:
      'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=800&h=800&q=80',
    durationLabel: '约 2 小时',
    venueName: 'Glorietta Mall',
    meetingPoint: 'Glorietta Mall 主入口',
    area: 'Makati',
  },
];

export function findTemplate(id: string): ActivityTemplate | undefined {
  return ACTIVITY_TEMPLATES.find((t) => t.id === id);
}
