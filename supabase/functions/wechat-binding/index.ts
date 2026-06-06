import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getServiceClient, getUserIdFromAuth } from "../_shared/supabase.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  const userId = getUserIdFromAuth(req);
  if (!userId) {
    return new Response(JSON.stringify({ error: "未登录" }), {
      status: 401,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }

  const supabase = getServiceClient();

  try {
    // GET — 查询绑定状态
    if (req.method === "GET") {
      const { data, error } = await supabase
        .from("wechat_bindings")
        .select("wxpusher_uid, enabled, created_at")
        .eq("user_id", userId)
        .maybeSingle();

      if (error) throw error;

      return new Response(
        JSON.stringify({
          bound: !!data,
          enabled: data?.enabled ?? false,
          uid: data?.wxpusher_uid ?? null,
          boundAt: data?.created_at ?? null,
        }),
        { headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // PUT — 切换 enabled
    if (req.method === "PUT") {
      const body = await req.json();
      const enabled = body.enabled === true;

      const { error } = await supabase
        .from("wechat_bindings")
        .update({ enabled, updated_at: new Date().toISOString() })
        .eq("user_id", userId);

      if (error) throw error;

      return new Response(JSON.stringify({ success: true, enabled }), {
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    // DELETE — 解绑
    if (req.method === "DELETE") {
      const { error } = await supabase
        .from("wechat_bindings")
        .delete()
        .eq("user_id", userId);

      if (error) throw error;

      return new Response(JSON.stringify({ success: true }), {
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error("[wechat-binding] error:", e);
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }
});
