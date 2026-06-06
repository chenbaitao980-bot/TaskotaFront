import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getAlipayConfig, precreate } from "../_shared/alipay.ts";
import { getServiceClient, getUserIdFromAuth } from "../_shared/supabase.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// 套餐配置
const PLANS: Record<string, { amount: string; subject: string; months: number }> = {
  vip_monthly: { amount: "9.90", subject: "Taskora VIP月度会员", months: 1 },
  vip_yearly: { amount: "68.00", subject: "Taskora VIP年度会员", months: 12 },
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    // 1. 验证用户身份
    const userId = getUserIdFromAuth(req);
    if (!userId) {
      return new Response(JSON.stringify({ error: "未登录" }), {
        status: 401,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    // 2. 解析请求
    const { plan } = await req.json();
    const planConfig = PLANS[plan];
    if (!planConfig) {
      return new Response(JSON.stringify({ error: "无效的套餐类型" }), {
        status: 400,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    // 3. 生成订单号
    const outTradeNo = `TKR${Date.now()}${Math.random().toString(36).slice(2, 8).toUpperCase()}`;

    // 4. 调用支付宝当面付
    const config = getAlipayConfig();
    const result = await precreate(config, outTradeNo, planConfig.amount, planConfig.subject);

    if (!result.qrCode) {
      return new Response(
        JSON.stringify({ error: result.error || "创建支付宝订单失败" }),
        { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // 5. 记录订单到数据库（待支付状态）
    const supabase = getServiceClient();
    const expiresAt = new Date();
    expiresAt.setMonth(expiresAt.getMonth() + planConfig.months);

    await supabase.from("payment_orders").upsert({
      out_trade_no: outTradeNo,
      user_id: userId,
      plan,
      amount: planConfig.amount,
      status: "pending",
      expires_at: expiresAt.toISOString(),
      created_at: new Date().toISOString(),
    });

    // 6. 返回二维码
    return new Response(
      JSON.stringify({
        qr_code: result.qrCode,
        out_trade_no: outTradeNo,
        amount: planConfig.amount,
        subject: planConfig.subject,
      }),
      { headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ error: `服务器错误: ${e.message}` }),
      { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  }
});
