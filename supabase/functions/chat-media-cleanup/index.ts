// Deletes chat photos/videos that no message points to any more (see migration 015).
// Safe for any signed-in member to trigger: it only ever removes orphaned files.
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data, error } = await sb.rpc("chat_media_orphans", { p_limit: 500 });
  if (error) return json({ error: error.message }, 500);
  const names = (data ?? []).map((r: { name: string }) => r.name);
  let removed = 0;
  for (let i = 0; i < names.length; i += 100) {
    const batch = names.slice(i, i + 100);
    const { error: e } = await sb.storage.from("chat-media").remove(batch);
    if (!e) removed += batch.length;
  }
  return json({ removed, found: names.length });
});
