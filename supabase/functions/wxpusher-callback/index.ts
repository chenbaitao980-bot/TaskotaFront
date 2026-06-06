import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getServiceClient } from "../_shared/supabase.ts";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200 });
  }

  try {
    const body = await req.json();

    // WxPusher 回调格式: { action: "app_subscribe", data: { appId, uid, extra, ... } }
    const action = body.action;
    if (action !== "app_subscribe") {
      return new Response(JSON.stringify({ success: true }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    const uid = body.data?.uid;
    const userId = body.data?.extra; // 我们在二维码 URL 的 extra 参数中传入 userId

    if (!uid || !userId) {
      console.error("[wxpusher-callback] missing uid or extra(userId):", body);
      return new Response(JSON.stringify({ error: "missing uid or userId" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const supabase = getServiceClient();
    const { error } = await supabase.from("wechat_bindings").upsert(
      {
        user_id: userId,
        wxpusher_uid: uid,
        enabled: true,
        updated_at: new Date().toISOString(),
      },
      { onConflict: "user_id" }
    );

    if (error) {
      console.error("[wxpusher-callback] upsert error:", error);
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    console.log(`[wxpusher-callback] bound user=${userId} uid=${uid}`);
    return new Response(JSON.stringify({ success: true }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error("[wxpusher-callback] error:", e);
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
