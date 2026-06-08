import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getUserIdFromAuth } from "../_shared/supabase.ts";

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

  const appToken = Deno.env.get("WXPUSHER_APP_TOKEN");
  if (!appToken) {
    return new Response(JSON.stringify({ error: "WxPusher 未配置" }), {
      status: 500,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }

  try {
    const resp = await fetch(
      "https://wxpusher.zjiecode.com/api/fun/create/qrcode",
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          appToken,
          extra: userId,
          validTime: 1800, // 30分钟有效
        }),
      }
    );

    const data = await resp.json();

    if (data.code !== 1000) {
      console.error("[wechat-qr] WxPusher error:", data);
      return new Response(
        JSON.stringify({ error: data.msg ?? "获取二维码失败" }),
        {
          status: 400,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        }
      );
    }

    return new Response(
      JSON.stringify({ url: data.data.url, shortUrl: data.data.shortUrl }),
      { headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  } catch (e) {
    console.error("[wechat-qr] error:", e);
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  }
});
