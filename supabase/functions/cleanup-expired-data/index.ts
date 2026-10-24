import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const cronSecret = Deno.env.get("CRON_SECRET");

if (!supabaseUrl || !serviceRoleKey || !cronSecret) {
  throw new Error("Missing protected cleanup configuration");
}

const admin = createClient(supabaseUrl, serviceRoleKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return Response.json({ error: "method_not_allowed" }, { status: 405 });
  }
  if (request.headers.get("x-cron-secret") !== cronSecret) {
    return Response.json({ error: "unauthorized" }, { status: 401 });
  }

  const { data: inactive, error } = await admin.rpc("list_inactive_account_ids", {
    p_inactive_for: "14 days",
    p_limit: 500,
  });
  if (error) {
    console.error("inactive_account_lookup_failed", error.message);
    return Response.json({ error: "lookup_failed" }, { status: 500 });
  }

  let deleted = 0;
  const failures: string[] = [];
  for (const row of inactive ?? []) {
    const userId = row.user_id as string;
    const result = await admin.auth.admin.deleteUser(userId);
    if (result.error) {
      failures.push(userId);
      console.error("inactive_account_delete_failed", userId, result.error.message);
    } else {
      deleted += 1;
    }
  }

  return Response.json({ scanned: inactive?.length ?? 0, deleted, failures });
});
