// ============================================================================
// Crystal Messenger — edge-runtime main service.
//
// Self-hosted edge-runtime bundles every function into one service and routes
// by URL. This dispatcher maps the last path segment to each function handler:
//
//   /functions/v1/app-config  -> GET   supabase config
//   /functions/v1/send-push   -> POST  FCM fan-out (DB trigger -> pg_net)
//   /functions/v1/presence    -> POST  Redis presence + rate limiting
// ============================================================================
import { handler as appConfig } from "../app-config/index.ts";
import { handler as presence } from "../presence/index.ts";
import { handler as sendPush } from "../send-push/index.ts";

const routes: Record<string, (req: Request) => Promise<Response>> = {
  "app-config": appConfig,
  "send-push": sendPush,
  presence,
};

export async function handler(req: Request): Promise<Response> {
  const url = new URL(req.url);
  const segments = url.pathname.split("/").filter(Boolean);
  const name = segments[segments.length - 1];

  const route = routes[name];
  if (!route) {
    return new Response("not found", { status: 404 });
  }
  return route(req);
}

if (import.meta.main) {
  Deno.serve(handler);
}