import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getAlipayConfig, verifyAlipayNotify } from "../_shared/alipay.ts";
import { getServiceClient } from "../_shared/supabase.ts";

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  try {
    // 1. 解析表单参数
    const body = await req.text();
    const params: Record<string, string> = {};
    for (const pair of body.split("&")) {
      const [k, v] = pair.split("=").map(decodeURIComponent);
      params[k] = v;
    }

    // 2. 验签
    const config = await getAlipayConfig();
    const valid = await verifyAlipayNotify(params, config.alipayPublicKey);
    if (!valid) {
      console.error("[alipay-notify] 验签失败");
      return new Response("fail");
    }

    // 3. 检查交易状态
    const tradeStatus = params.trade_status;
    const outTradeNo = params.out_trade_no;
    const tradeNo = params.trade_no;

    if (tradeStatus !== "TRADE_SUCCESS" && tradeStatus !== "TRADE_FINISHED") {
      return new Response("success");
    }

    // 4. 查询订单
    const supabase = getServiceClient();
    const { data: order } = await supabase
      .from("payment_orders")
      .select("*")
      .eq("out_trade_no", outTradeNo)
      .single();

    if (!order) {
      console.error(`[alipay-notify] 订单不存在: ${outTradeNo}`);
      return new Response("success");
    }

    if (order.status === "paid") {
      return new Response("success");
    }

    // 5. 金额校验
    if (params.total_amount !== order.amount) {
      console.error(`[alipay-notify] 金额不匹配: ${params.total_amount} vs ${order.amount}`);
      return new Response("fail");
    }

    // 6. 更新订单状态
    await supabase
      .from("payment_orders")
      .update({ status: "paid", trade_no: tradeNo, paid_at: new Date().toISOString() })
      .eq("out_trade_no", outTradeNo);

    // 7. 激活/续费 VIP
    const { data: existing } = await supabase
      .from("user_subscriptions")
      .select("*")
      .eq("user_id", order.user_id)
      .single();

    const now = new Date();
    let startedAt = now;
    let expiresAt = new Date(order.expires_at);

    // 如果已有未过期的 VIP，续期从当前到期时间开始
    if (existing && existing.plan !== "free" && existing.status === "active") {
      const currentExpires = new Date(existing.expires_at);
      if (currentExpires > now) {
        startedAt = currentExpires;
        const months = order.plan === "vip_yearly" ? 12 : 1;
        expiresAt = new Date(currentExpires);
        expiresAt.setMonth(expiresAt.getMonth() + months);
      }
    }

    await supabase.from("user_subscriptions").upsert({
      user_id: order.user_id,
      plan: order.plan,
      status: "active",
      started_at: startedAt.toISOString(),
      expires_at: expiresAt.toISOString(),
      payment_channel: "alipay",
      transaction_id: tradeNo,
      auto_renew: false,
      updated_at: new Date().toISOString(),
    }, { onConflict: "user_id" });

    console.log(`[alipay-notify] VIP 激活成功: user=${order.user_id}, plan=${order.plan}, expires=${expiresAt.toISOString()}`);
    return new Response("success");
  } catch (e) {
    console.error(`[alipay-notify] 异常: ${e.message}`);
    return new Response("fail");
  }
});
