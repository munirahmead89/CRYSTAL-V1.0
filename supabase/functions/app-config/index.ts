// Secure Supabase configuration endpoint.
//
// The Supabase URL + publishable (anon) key live HERE as Edge Function secrets
// (`CRYSTAL_SUPABASE_URL` / `CRYSTAL_SUPABASE_ANON_KEY`), never in the APK.
// The mobile app fetches this over HTTPS at startup:
//
//   flutter build apk --dart-define=APP_CONFIG_URL=https://<project>.functions.supabase.co/app-config
//
// Deploy:
//   supabase secrets set CRYSTAL_SUPABASE_URL=https://<project>.supabase.co
//   supabase secrets set CRYSTAL_SUPABASE_ANON_KEY=eyJ...
//   supabase functions deploy app-config --no-verify-jwt
//
// The anon key is the publishable key (RLS is the real security boundary);
// the service-role key and DB credentials must NEVER be returned or shipped.
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const crystalSupabaseUrl = Deno.env.get("CRYSTAL_SUPABASE_URL") ?? "";
const crystalSupabaseAnonKey = Deno.env.get("CRYSTAL_SUPABASE_ANON_KEY") ?? "";

export async function handler(req: Request): Promise<Response> {
  if (req.method !== "GET") {
    return new Response("method not allowed", { status: 405 });
  }
  return new Response(
    JSON.stringify({
      url: crystalSupabaseUrl,
      anonKey: crystalSupabaseAnonKey,
      updatedAt: new Date().toISOString(),
    }),
    {
      headers: {
        "content-type": "application/json; charset=utf-8",
        "cache-control": "no-store",
      },
    },
  );
}

// Standalone cloud deploy runs this file as the entrypoint; edge-runtime
// (main/index.ts) imports it as a module instead.
if (import.meta.main) {
  serve(handler);
}