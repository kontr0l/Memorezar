// Edge Function: delete-user-account
//
// Authenticated endpoint that performs a full cascade delete for the calling
// user. Removes all server-side data linked to their auth.users row and then
// deletes the auth row itself, so no admin processing is required.
//
// Called from the in-app "Delete My Account" button. The client passes the
// user's JWT in the Authorization header; we verify it server-side, then
// switch to the service-role client for the actual deletes.
//
// Deletes (in order):
//   1. recording audio files from the `recordings` storage bucket
//   2. rows from public.recordings where user_id = caller
//   3. rows from public.user_backups where user_id = caller
//   4. rows from public.support_tickets where user_id = caller
//   5. the auth.users row itself
//
// Anything that survives (e.g. equivalences are global/community, user-images
// in storage are not user-tagged) is left intact.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, apikey, Authorization",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: cors });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  // Pull the caller's JWT. Prefer the request body's `access_token` field
  // over the Authorization header — the Edge Functions gateway rejects ES256
  // JWTs in the header (UNAUTHORIZED_UNSUPPORTED_TOKEN_ALGORITHM), but
  // Supabase Auth itself supports ES256 via admin.auth.getUser(). Passing
  // the token in the body bypasses the gateway check while still verifying
  // the user properly server-side.
  let token: string | null = null;
  try {
    const body = await req.json();
    token = body?.access_token ?? null;
  } catch { /* no body or not JSON */ }
  if (!token) {
    // Fallback: try the Authorization header (works for HS256 projects)
    const authHeader = req.headers.get("Authorization") ?? "";
    token = authHeader.replace(/^Bearer\s+/i, "") || null;
  }
  if (!token) return json({ error: "Missing access_token in body or Authorization header" }, 401);

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: userRes, error: userErr } = await admin.auth.getUser(token);
  if (userErr || !userRes?.user) {
    return json({ error: `Invalid or expired token: ${userErr?.message ?? "unknown"}` }, 401);
  }
  const userId = userRes.user.id;

  // 1. Collect file_paths so we can clean up storage before nuking rows.
  const { data: recordings, error: recListErr } = await admin
    .from("recordings")
    .select("file_path")
    .eq("user_id", userId);
  if (recListErr) {
    return json({ error: `Failed to list recordings: ${recListErr.message}` }, 500);
  }
  const filePaths = (recordings ?? [])
    .map((r) => r.file_path as string)
    .filter((p) => typeof p === "string" && p.length > 0);

  // 2. Delete audio files from storage in batches (Supabase caps `remove` at
  //    ~1000 paths per call; chunk to be safe).
  if (filePaths.length > 0) {
    const chunkSize = 100;
    for (let i = 0; i < filePaths.length; i += chunkSize) {
      const chunk = filePaths.slice(i, i + chunkSize);
      const { error } = await admin.storage.from("recordings").remove(chunk);
      if (error) {
        console.warn(`storage.remove batch failed: ${error.message}`);
        // Don't bail — continue with row deletion so partial cleanup still
        // happens. Orphaned files are recoverable via admin UI.
      }
    }
  }

  // 3. Recordings rows.
  const { error: recDelErr } = await admin
    .from("recordings")
    .delete()
    .eq("user_id", userId);
  if (recDelErr) console.warn(`recordings delete: ${recDelErr.message}`);

  // 4. User backups (data lives inline in the row's JSONB column, no separate
  //    storage file to clean).
  const { error: backupDelErr } = await admin
    .from("user_backups")
    .delete()
    .eq("user_id", userId);
  if (backupDelErr) console.warn(`user_backups delete: ${backupDelErr.message}`);

  // 5. Support tickets — delete the user's tickets too so they don't hang
  //    around with a dangling user_id.
  const { error: ticketDelErr } = await admin
    .from("support_tickets")
    .delete()
    .eq("user_id", userId);
  if (ticketDelErr) console.warn(`support_tickets delete: ${ticketDelErr.message}`);

  // 6. Finally, the auth.users row itself.
  const { error: authDelErr } = await admin.auth.admin.deleteUser(userId);
  if (authDelErr) {
    return json({ error: `Failed to delete auth user: ${authDelErr.message}` }, 500);
  }

  return json({
    ok: true,
    deleted: {
      recordings: recordings?.length ?? 0,
      storage_files: filePaths.length,
    },
  });
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}
