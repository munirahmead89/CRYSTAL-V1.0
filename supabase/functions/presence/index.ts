// ============================================================================
// Crystal Messenger — Redis gateway (presence + rate limiting).
//
// WHY THIS EXISTS AS A FUNCTION AND NOT IN THE APK
//
// Redis has no per-user authorisation. A mobile app that held the Redis URL and
// token could be reverse-engineered out of the APK in minutes, after which
// anyone could read or poison the whole instance. So the app never sees Redis
// credentials: it calls this function, this function authenticates the caller
// against Supabase Auth and then talks to Redis over the Upstash REST API
// (HTTPS, no TCP listeners, no new infrastructure to secure).
//
// WHAT IT IS GOOD FOR HERE, AND WHAT IT IS NOT
//
//   * Presence. A per-user key with a TTL beats a Supabase Realtime presence
//     channel for a "who is online" roster: writing is one O(log n) ZADD and a
//     SETEX, versus every client being pushed a broadcast on every join/leave.
//     On a free tier with a 200-connection cap that difference is the whole
//     ballgame.
//   * Rate limiting. Sign-in attempts, QR pairing and message sends are all
//     abusable and currently unprotected; a token bucket in Redis is the
//     cheapest correct place for that.
//
// It is deliberately NOT used for messages, media or anything durable. Those
// stay in Postgres and Storage: Redis is a cache, and a cache that silently
// loses data is the wrong home for a user's chat history.
//
// Deploy:
//   supabase secrets set UPSTASH_REDIS_REST_URL=https://<...>.upstash.io
//   supabase secrets set UPSTASH_REDIS_REST_TOKEN=<token>
//   supabase functions deploy presence --no-verify-jwt
//
// With no Redis configured this returns 501 and the client transparently falls
// back to Supabase Realtime presence, so the app keeps working either way.
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const redisUrl = Deno.env.get("UPSTASH_REDIS_REST_URL") ?? "";
const redisToken = Deno.env.get("UPSTASH_REDIS_REST_TOKEN") ?? "";

/** How long a user stays "online" without a heartbeat. */
const PRESENCE_TTL_SECONDS = 60;

/** Upper bound on the roster we will return, to keep the response small. */
const MAX_ROSTER = 2000;

interface Caller {
  id: string;
}

/**
 * Identifies the caller from their Supabase access token.
 *
 * Identity is taken from the token, never from the request body. A gateway that
 * accepted a caller-supplied user id would let anyone mark anyone else online
 * or burn another user's rate-limit budget.
 */
async function authenticate(req: Request): Promise<Caller | null> {
  const header = req.headers.get("authorization") ?? "";
  const token = header.replace(/^Bearer\s+/i, "").trim();
  if (!token) return null;

  const url = Deno.env.get("CRYSTAL_SUPABASE_URL") ?? "";
  const anonKey = Deno.env.get("CRYSTAL_SUPABASE_ANON_KEY") ?? "";
  if (!url || !anonKey) return null;

  try {
    const res = await fetch(`${url}/auth/v1/user`, {
      headers: { apikey: anonKey, authorization: `Bearer ${token}` },
    });
    if (!res.ok) return null;
    const user = await res.json();
    return user?.id ? { id: user.id as string } : null;
  } catch {
    return null;
  }
}

/** Single Upstash REST command. Returns null on any failure. */
async function redis(command: unknown[]): Promise<unknown> {
  const res = await fetch(redisUrl, {
    method: "POST",
    headers: {
      authorization: `Bearer ${redisToken}`,
      "content-type": "application/json",
    },
    body: JSON.stringify(command),
  });
  if (!res.ok) return null;
  const body = await res.json();
  return body?.result ?? null;
}

const onlineKey = (id: string) => `cm:presence:user:${id}`;
const rosterKey = "cm:presence:roster";
const rateKey = (scope: string, id: string) => `cm:rl:${scope}:${id}`;

/**
 * Token bucket: at most [limit] events per [windowSeconds].
 *
 * Returns whether the call is allowed and how many remain, so the client can
 * tell the user "try again in N seconds" instead of silently dropping.
 */
async function consume(
  scope: string,
  id: string,
  limit: number,
  windowSeconds: number,
): Promise<{ allowed: boolean; remaining: number; retryAfter: number }> {
  const key = rateKey(scope, id);
  // INCR then set the expiry only on the first hit, so the window is fixed from
  // the first request rather than sliding forward on every call.
  const count = (await redis(["INCR", key])) as number | null;
  if (count === null) {
    // Redis unavailable: fail OPEN for rate limiting. Refusing traffic because
    // a cache is down would turn a degradation into an outage.
    return { allowed: true, remaining: limit, retryAfter: 0 };
  }
  if (count === 1) {
    await redis(["EXPIRE", key, windowSeconds]);
  }
  const ttl = (await redis(["TTL", key])) as number | null;
  return {
    allowed: count <= limit,
    remaining: Math.max(0, limit - count),
    retryAfter: ttl !== null && ttl > 0 ? ttl : windowSeconds,
  };
}

export async function handler(req: Request): Promise<Response> {
  const json = (body: unknown, status = 200, extra: Record<string, string> = {}) =>
    new Response(JSON.stringify(body), {
      status,
      headers: {
        "content-type": "application/json; charset=utf-8",
        "cache-control": "no-store",
        ...extra,
      },
    });

  if (!redisUrl || !redisToken) {
    // Not configured. The client treats this as "use Realtime presence".
    return json({ error: "redis_not_configured" }, 501);
  }

  if (req.method !== "POST") {
    return json({ error: "method not allowed" }, 405);
  }

  const caller = await authenticate(req);
  if (!caller) {
    return json({ error: "unauthorized" }, 401);
  }

  let action = "";
  let payload: Record<string, unknown> = {};
  try {
    const body = await req.json();
    action = String(body?.action ?? "");
    payload = (body?.payload ?? {}) as Record<string, unknown>;
  } catch {
    return json({ error: "invalid body" }, 400);
  }

  switch (action) {
    // Heartbeat. Cheap: two commands, both O(1)/O(log n). The client calls
    // this on a timer so a user is dropped from the roster ~60s after their app
    // actually stops (crash, force-quit, signal loss) with no explicit
    // goodbye needed.
    case "presence-touch": {
      const now = Math.floor(Date.now() / 1000);
      await redis(["ZADD", rosterKey, now.toString(), caller.id]);
      await redis(["SET", onlineKey(caller.id), now.toString(), "EX", PRESENCE_TTL_SECONDS]);
      return json({ ok: true, ttl: PRESENCE_TTL_SECONDS });
    }

    // Read the roster, pruning anyone whose TTL lapsed.
    //
    // The ZSET alone cannot expire members, so a plain ZRANGE would return
    // everyone who ever connected. Trimming by score on read keeps the set
    // self-healing without a background job.
    case "presence-roster": {
      const cutoff = Math.floor(Date.now() / 1000) - PRESENCE_TTL_SECONDS;
      await redis(["ZREMRANGEBYSCORE", rosterKey, "-inf", cutoff.toString()]);
      const ids = (await redis(["ZRANGE", rosterKey, 0, MAX_ROSTER - 1])) as
        | string[]
        | null;
      return json({ online: ids ?? [], ttl: PRESENCE_TTL_SECONDS });
    }

    case "presence-offline": {
      await redis(["ZREM", rosterKey, caller.id]);
      await redis(["DEL", onlineKey(caller.id)]);
      return json({ ok: true });
    }

    // Rate limits. Each is scoped so one noisy feature cannot starve another.
    case "rate-limit": {
      const scope = String(payload.scope ?? "default");
      const limit = Number(payload.limit ?? 20);
      const window = Number(payload.windowSeconds ?? 60);
      const result = await consume(scope, caller.id, limit, window);
      return json(
        { ...result },
        result.allowed ? 200 : 429,
        result.allowed
          ? {}
          : { "retry-after": String(result.retryAfter) },
      );
    }

    default:
      return json({ error: "unknown action" }, 400);
  }
}

if (import.meta.main) {
  serve(handler);
}
