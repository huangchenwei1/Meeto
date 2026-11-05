import {
  BadRequestException,
  Controller,
  Get,
  Query,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '../common/auth.guard.js';

/// One place suggestion for the search-as-you-type fields.
export interface PlaceSuggestion {
  name: string;
  address: string;
  district: string;
}

/// Amap sends empty fields as `[]` instead of `''`.
function asString(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

const CACHE_TTL_MS = 5 * 60 * 1000;
const CACHE_MAX_ENTRIES = 200;
const UPSTREAM_TIMEOUT_MS = 3000;
const MAX_SUGGESTIONS = 8;

/// Server-side proxy for place search, so the map-provider key never
/// reaches clients and the provider stays swappable per region (Amap
/// covers mainland China only; a future SEA rollout routes elsewhere
/// behind this same endpoint).
@Controller('places')
@UseGuards(AuthGuard)
export class PlacesController {
  private readonly cache = new Map<
    string,
    { at: number; data: PlaceSuggestion[] }
  >();

  @Get('search')
  async search(
    @Query('q') q?: string,
    @Query('city') city?: string,
  ): Promise<PlaceSuggestion[]> {
    const query = (q ?? '').trim();
    if (!query) {
      throw new BadRequestException('QUERY_REQUIRED');
    }
    // Without a configured provider the fields quietly degrade to free
    // typing, so an unset key must not break the flow.
    const key = process.env.AMAP_KEY ?? '';
    if (!key) {
      return [];
    }
    const targetCity = (city ?? '').trim() || process.env.PLACES_CITY || '武汉';
    const cacheKey = `${targetCity}|${query}`;
    const hit = this.cache.get(cacheKey);
    if (hit && Date.now() - hit.at < CACHE_TTL_MS) {
      return hit.data;
    }
    const url =
      'https://restapi.amap.com/v3/assistant/inputtips?' +
      new URLSearchParams({
        key,
        keywords: query,
        city: targetCity,
        citylimit: 'true',
        datatype: 'poi',
      }).toString();
    let tips: unknown[];
    try {
      const response = await fetch(url, {
        signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MS),
      });
      const body = (await response.json()) as {
        status?: string;
        tips?: unknown[];
      };
      tips = body.status === '1' && Array.isArray(body.tips) ? body.tips : [];
    } catch {
      // Upstream hiccup: degrade to no suggestions rather than an error.
      return [];
    }
    const data: PlaceSuggestion[] = tips
      .map((tip) => {
        const t = tip as Record<string, unknown>;
        return {
          name: asString(t.name),
          address: asString(t.address),
          district: asString(t.district),
        };
      })
      // Category-only suggestions (e.g. bare "咖啡厅") come without an id
      // or district; keep concrete places only.
      .filter((s) => s.name !== '' && s.district !== '')
      .slice(0, MAX_SUGGESTIONS);
    if (this.cache.size >= CACHE_MAX_ENTRIES) {
      const oldest = this.cache.keys().next().value;
      if (oldest !== undefined) {
        this.cache.delete(oldest);
      }
    }
    this.cache.set(cacheKey, { at: Date.now(), data });
    return data;
  }
}
