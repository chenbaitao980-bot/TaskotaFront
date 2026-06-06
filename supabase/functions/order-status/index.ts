import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getAlipayConfig, queryTrade } from "../_shared/alipay.ts";
import { getServiceClient, getUserIdFromAuth } from "../_shared/supabase.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    const userId = getUserIdFromAuth(req);
    if (!userId) {
      return new Response(JSON.stringify({ error: "未登录" }), {
        status: 401,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    let outTradeNo: string | null = null;
    if (req.method === "POST") {
      const body = await req.json();
      outTradeNo = body.out_trade_no;
    } else {
      const url = new URL(req.url);
      outTradeNo = url.searchParams.get("out_trade_no");
    }
    if (!outTradeNo) {
      return new Response(JSON.stringify({ error: "缺少 out_trade_no" }), {
        status: 400,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    // 先查本地订单状态
    const supabase = getServiceClient();
    const { data: order } = await supabase
      .from("payment_orders")
      .select("status, user_id")
      .eq("out_trade_no", outTradeNo)
      .single();

    if (!order || order.user_id !== userId) {
      return new Response(JSON.stringify({ error: "订单不存在" }), {
        status: 404,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    // 如果本地已标记为 paid，直接返回
    if (order.status === "paid") {
      return new Response(
        JSON.stringify({ status: "paid" }),
        { headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // 否则主动查询支付宝
    const config = getAlipayConfig();
    const result = await queryTrade(config, outTradeNo);

    let status = "pending";
    if (result.tradeStatus === "TRADE_SUCCESS" || result.tradeStatus === "TRADE_FINISHED") {
      status = "paid";
    } else if (result.tradeStatus === "TRADE_CLOSED") {
      status = "closed";
    }

    return new Response(
      JSON.stringify({ status, trade_status: result.tradeStatus }),
      { headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ error: `查询失败: ${e.message}` }),
      { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  }
});
