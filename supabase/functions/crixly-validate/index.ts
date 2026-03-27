// Supabase Edge Function: crixly-validate
// Validates a license key + machine fingerprint.
// Expected DB tables (suggested): licenses, activations
// This function runs server-side and may use Supabase service role internally.

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

type Req = { key?: string; fingerprint?: string };

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
    },
  });
}

serve(async (req) => {
  if (req.method !== "POST") return json(405, { ok: false, message: "Method not allowed" });

  let payload: Req;
  try {
    payload = await req.json();
  } catch {
    return json(400, { ok: false, message: "Invalid JSON" });
  }

  const key = (payload.key || "").trim();
  const fingerprint = (payload.fingerprint || "").trim();
  if (!key || !fingerprint) {
    return json(400, { ok: false, message: "Missing key or fingerprint" });
  }

  const url = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const supabase = createClient(url, serviceKey, { auth: { persistSession: false } });

  // 1) Find license
  const { data: license, error: licErr } = await supabase
    .from("licenses")
    .select("id,status,expires_at,plan")
    .eq("key", key)
    .maybeSingle();

  if (licErr) return json(500, { ok: false, message: "Server error" });
  if (!license) return json(403, { ok: false, message: "Invalid license" });
  if (license.status !== "active") return json(403, { ok: false, message: "License not active" });
  if (license.expires_at && new Date(license.expires_at).getTime() < Date.now()) {
    return json(403, { ok: false, message: "License expired" });
  }

  // 2) Ensure activation row exists (upsert)
  const now = new Date().toISOString();
  const { error: actErr } = await supabase
    .from("activations")
    .upsert(
      {
        license_id: license.id,
        fingerprint,
        last_seen_at: now,
        activated_at: now,
      },
      { onConflict: "license_id,fingerprint" },
    );

  if (actErr) return json(500, { ok: false, message: "Server error" });

  // You can tune this; client will cache for this duration.
  return json(200, {
    ok: true,
    plan: license.plan,
    expires_at: license.expires_at,
    next_check_seconds: 3600,
  });
});
