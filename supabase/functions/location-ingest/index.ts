import { createClient } from "npm:@supabase/supabase-js@2.57.4";

const phaseZeroTenantId = "00000000-0000-4000-8000-000000000001";
const phaseZeroDriverId = "00000000-0000-4000-8000-000000000002";

const corsHeaders = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "apikey, content-type",
  "access-control-allow-methods": "GET, POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return Response.json(body, { status, headers: corsHeaders });
}

function configuredKeys(name: string): string[] {
  const raw = Deno.env.get(name);
  if (!raw) return [];
  try {
    return Object.values(JSON.parse(raw) as Record<string, string>);
  } catch {
    return [];
  }
}

function isAuthorized(request: Request): boolean {
  const provided = request.headers.get("apikey");
  return provided != null &&
    configuredKeys("SUPABASE_PUBLISHABLE_KEYS").includes(provided);
}

function adminClient() {
  const url = Deno.env.get("SUPABASE_URL");
  const secret = configuredKeys("SUPABASE_SECRET_KEYS")[0] ??
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !secret) throw new Error("Supabase function secrets unavailable");
  return createClient(url, secret, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (!isAuthorized(request)) return json({ error: "unauthorized" }, 401);

  try {
    const supabase = adminClient();
    if (request.method === "GET") {
      const { data, error } = await supabase.rpc("phase_zero_telemetry_snapshot", {
        p_tenant_id: phaseZeroTenantId,
      });
      if (error) throw error;
      return json(data);
    }

    if (request.method !== "POST") return json({ error: "method not allowed" }, 405);
    const batch = await request.json();
    if (batch.tenantId !== phaseZeroTenantId || batch.driverId !== phaseZeroDriverId) {
      return json({ error: "phase zero identity mismatch" }, 403);
    }
    const { data, error } = await supabase.rpc("ingest_phase_zero_location_batch", {
      p_batch: batch,
    });
    if (error) throw error;
    return json(data);
  } catch (error) {
    console.error(error);
    const details = error as {
      message?: string;
      code?: string;
      details?: string;
      hint?: string;
    };
    return json({
      error: "location ingest failed",
      message: details.message ?? String(error),
      code: details.code,
      details: details.details,
      hint: details.hint,
    }, 400);
  }
});
