import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getServiceClient, getUserIdFromAuth } from "../_shared/supabase.ts";

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { status: 200 });
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const supabase = getServiceClient();
  const userId = getUserIdFromAuth(req);
  if (!userId) return new Response("Unauthorized", { status: 401 });

  let body: { registration_id?: string; platform?: string };
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "invalid json" }), {
      status: 400,
    });
  }

  const { registration_id, platform } = body;
  if (!registration_id) {
    return new Response(
      JSON.stringify({ error: "registration_id required" }),
      { status: 400 }
    );
  }

  const { error } = await supabase.from("user_devices").upsert(
    {
      user_id: userId,
      aliyun_registration_id: registration_id,
      platform: platform ?? "android",
      updated_at: new Date().toISOString(),
    },
    { onConflict: "user_id" }
  );

  if (error) {
    console.error("[register-device] error:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
    });
  }

  console.log(
    `[register-device] user=${userId} reg=${registration_id.slice(0, 8)}...`
  );
  return new Response(JSON.stringify({ success: true }), {
    headers: { "Content-Type": "application/json" },
  });
});
