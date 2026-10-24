// ============================================================================
// Crystal Messenger — send-push Edge Function.
//
// Invoked fire-and-forget by the `notify_message_push` Postgres trigger
// (pg_net) whenever a message row is inserted. Fans out FCM notifications to
// the conversation's OTHER members with sound + vibration + (call) actions.
//
// Auth: the trigger sends `Authorization: Bearer <SERVICE_ROLE_KEY>`, so only
// the database can call us; the Service Role key is read from env, never from
// the request.
//
// FCM transport:
//   v1 (plus actions/sound/vibrate, recommended):
//       FCM_SERVICE_ACCOUNT_JSON  = Google Service Account JSON (auto JWT grant)
//   legacy fallback:
//       FCM_SERVER_KEY            = Firebase project server key
// ============================================================================
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const fcmLegacyKey = Deno.env.get("FCM_SERVER_KEY") ?? "";
const fcmServiceAccount = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON") ?? "";

const TEXT_PREVIEW_LEN = 120;

export async function handler(req: Request): Promise<Response> {
  if (req.method !== "POST") {
    return new Response("method not allowed", { status: 405 });
  }
  // Only the DB trigger (Bearer service role) may call this endpoint.
  const auth = req.headers.get("authorization") ?? "";
  if (auth !== `Bearer ${serviceRoleKey}`) {
    return new Response("unauthorized", { status: 401 });
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return new Response("bad json", { status: 400 });
  }

  const messageId = body.message_id as string | undefined;
  const conversationId = body.conversation_id as string | undefined;
  const senderId = body.sender_id as string | undefined;
  const messageType = (body.message_type as string) ?? "text";
  const rawText = (body.text as string) ?? "";

  if (!conversationId || !senderId || !messageId) {
    return new Response("missing payload", { status: 400 });
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey);
  const results = { recipients: 0, sent: 0, errors: 0 };

  try {
    const { data: members, error: memErr } = await supabase
      .from("conversation_members")
      .select("user_id")
      .eq("conversation_id", conversationId)
      .neq("user_id", senderId);

    if (memErr) throw memErr;
    if (!members || members.length === 0) {
      return json({ results });
    }

    const asUsers = (u: string) => `"${u}"`;
    const ids = members.map((m: { user_id: string }) => m.user_id);
    const filter = ids.map(asUsers).join(",");

    // Sender display name (for the "New message" title).
    const { data: senderRow } = await supabase
      .from("profiles")
      .select("display_name")
      .eq("id", senderId)
      .limit(1)
      .single<string>();

    const senderName = senderRow?.display_name ??
      (messageType === "call" ? "Crystal voice call" : "Crystal");

    // Recipients: profiles + active device push tokens + privacy preview opt.
    const { data: recipients, error: recErr } = await supabase
      .from("profiles")
      .select(`
        id,
        display_name,
        devices!inner ( push_token, status ),
        user_privacy_settings ( push_preview_enabled )
      `)
      .in("id", ids)
      .eq("devices.status", "active")
      .not("devices.push_token", "is", null);

    if (recErr) throw recErr;
    if (!recipients) return json({ results });

    const previewsOn = (p: { user_privacy_settings?: { push_preview_enabled?: boolean } | null }) =>
      p.user_privacy_settings?.push_preview_enabled !== false;

    const notifications: Array<Record<string, unknown>> = [];
    const tokens = new Set<string>();

    for (const p of recipients as Array<{ id: string; devices: Array<{ push_token: string }> }>) {
      const bodyText = messageType === "call"
        ? "Incoming call \u2026 answer or decline"
        : (previewsOn(p) ? preview(rawText) : "You have a new message");

      notifications.push({
        user_id: p.id,
        type: messageType === "call" ? "call" : "message",
        title: senderName,
        body: bodyText,
        data: {
          message_id: messageId,
          conversation_id: conversationId,
          sender_id: senderId,
          kind: messageType === "call" ? "call" : "message",
        },
      });
      for (const d of p.devices) {
        if (d.push_token) tokens.add(d.push_token);
      }
    }

    // In-app notifications list (bell) so the app never depends on push alone.
    await supabase.from("notifications").insert(notifications);

    for (const token of tokens) {
      try {
        await sendFcm(token, senderName, bodyText, messageType, {
          message_id: messageId,
          conversation_id: conversationId,
          sender_id: senderId,
        });
        results.sent++;
      } catch (e) {
        results.errors++;
        console.error("fcm_failed", e);
      }
    }
    results.recipients = recipients.length;
  } catch (e) {
    console.error("send_push_failed", e);
    results.errors++;
  }

  return json({ results });
}

function preview(text: string): string {
  const t = text.replace(/\s+/g, " ").trim();
  return t.length > TEXT_PREVIEW_LEN ? `${t.slice(0, TEXT_PREVIEW_LEN)}\u2026` : t;
}

async function sendFcm(
  token: string,
  title: string,
  body: string,
  kind: string,
  data: Record<string, string>,
): Promise<void> {
  // HTTP v1 (recommended): supports sound, vibration AND Android actions.
  if (fcmServiceAccount) {
    const accessToken = await fcmAccessToken(JSON.parse(fcmServiceAccount));
    const isCall = kind === "call";
  const message: Record<string, unknown> = {
      message: {
        token,
        notification: { title, body, sound: "default" },
        android: {
          priority: "high",
          // A call must land on the dedicated max-importance `calls` channel,
          // otherwise Android renders a dismissible banner and never rings.
          notification: {
            channel_id: isCall ? "calls" : "messages",
            sound: "default",
            click_action: isCall ? "CALL_ACTION" : "OPEN_CHAT",
            // `fullScreenIntent` + `category: call` + `fullScreen` are what turn
            // this into a WhatsApp-style ring screen while backgrounded.
            ...(isCall
              ? {
                  category: "call",
                  fullScreenIntent: true,
                  visibility: "private",
                }
              : {}),
            actions: isCall
              ? [
                  { title: "Answer", icon: "sip", intent: "crystal.ACTION_ANSWER" },
                  { title: "Decline", icon: "hangup", intent: "crystal.ACTION_DECLINE" },
                ]
              : undefined,
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
              ...(isCall
                ? {
                    "thread-id": `call-${data.call_id ?? "unknown"}`,
                    "interruption-level": "critical",
                    category: "crystal.CALL",
                  }
                : {}),
            },
          },
        },
        data,
      },
    };
    if (!(message.message as Record<string, unknown>).android.notification.actions) {
      delete (message.message as Record<string, unknown>).android.notification.actions;
    }
    const { project_id } = JSON.parse(fcmServiceAccount) as { project_id: string };
    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${project_id}/messages:send`,
      {
        method: "POST",
        headers: { authorization: `Bearer ${accessToken}`, "content-type": "application/json" },
        body: JSON.stringify(message),
      },
    );
    if (!res.ok) throw new Error(`fcm_v1 ${res.status} ${await res.text()}`);
    return;
  }

  // Legacy fallback.
  if (!fcmLegacyKey) throw new Error("no FCM credential configured");
  const res = await fetch("https://fcm.googleapis.com/fcm/send", {
    method: "POST",
    headers: {
      authorization: `key=${fcmLegacyKey}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      to: token,
      priority: "high",
      notification: { title, body, sound: "default", vibrate: [0, 250, 250, 250] },
      data,
    }),
  });
  if (!res.ok) throw new Error(`fcm_legacy ${res.status} ${await res.text()}`);
}

// Google OAuth: RS256 JWT -> access token for FCM HTTP v1.
let cachedToken = { token: "", expiresAt: 0 };
async function fcmAccessToken(sa: {
  client_email: string;
  private_key: string;
  token_uri: string;
}): Promise<string> {
  if (cachedToken.token && Date.now() < cachedToken.expiresAt) return cachedToken.token;

  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = b64url(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: sa.token_uri,
    iat: now,
    exp: now + 3600,
  }));
  const input = `${header}.${claims}`;
  const sig = await signRsaSha256(sa.private_key, input);
  const jwt = `${input}.${sig}`;

  const res = await fetch(sa.token_uri, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  const out = (await res.json()) as { access_token?: string; expires_in?: number };
  if (!out.access_token) throw new Error("oauth token failed");
  cachedToken = { token: out.access_token, expiresAt: now + (out.expires_in ?? 3600) - 60 };
  return out.access_token;
}

function b64url(s: string): string {
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function signRsaSha256(pem: string, data: string): Promise<string> {
  const body = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const der = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der as ArrayBuffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    key,
    new TextEncoder().encode(data),
  );
  return b64url(String.fromCharCode(...new Uint8Array(sig)));
}

function json(o: unknown): Response {
  return new Response(JSON.stringify(o), {
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}