import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getAlipayConfig, precreate } from "../_shared/alipay.ts";
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
    // 1. 验证用户身份
    const userId = getUserIdFromAuth(req);
    if (!userId) {
      return new Response(JSON.stringify({ error: "未登录" }), {
        status: 401,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    // 2. 解析请求
    const { plan, discount_code } = await req.json();
    if (!plan) {
      return new Response(JSON.stringify({ error: "缺少 plan 参数" }), {
        status: 400,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    const supabase = getServiceClient();

    // 3. 从数据库获取套餐配置
    const { data: planConfig, error: planError } = await supabase
      .from("member_types")
      .select("*")
      .eq("id", plan)
      .single();

    if (planError || !planConfig) {
      return new Response(JSON.stringify({ error: "无效的套餐类型" }), {
        status: 400,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    // 4. 计算价格（如果有折扣码）
    let finalAmount = planConfig.price;
    let discountApplied = null;

    if (discount_code) {
      const { data: discountCode, error: discountError } = await supabase
        .from("member_discount_codes")
        .select("*")
        .eq("code", discount_code.toUpperCase())
        .eq("active", true)
        .single();

      if (!discountError && discountCode) {
        // 检查折扣码是否适用于该套餐
        if (!discountCode.type_id || discountCode.type_id === plan) {
          finalAmount = planConfig.price * (discountCode.percent / 100);
          discountApplied = {
            code: discountCode.code,
            percent: discountCode.percent,
          };

          // 更新折扣码使用次数
          await supabase
            .from("member_discount_codes")
            .update({ used_count: discountCode.used_count + 1 })
            .eq("id", discountCode.id);
        }
      }
    }

    // 格式化金额（保留两位小数）
    const amountStr = finalAmount.toFixed(2);
    const subject = `Taskora ${planConfig.name}`;

    // 5. 生成订单号
    const outTradeNo = `TKR${Date.now()}${Math.random().toString(36).slice(2, 8).toUpperCase()}`;

    // 6. 调用支付宝当面付
    const config = await getAlipayConfig();
    const result = await precreate(config, outTradeNo, amountStr, subject);

    if (!result.qrCode) {
      return new Response(
        JSON.stringify({ error: result.error || "创建支付宝订单失败" }),
        { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // 7. 记录订单到数据库（待支付状态）
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + planConfig.duration_days);

    await supabase.from("payment_orders").upsert({
      out_trade_no: outTradeNo,
      user_id: userId,
      plan: plan,
      amount: amountStr,
      status: "pending",
      expires_at: expiresAt.toISOString(),
      created_at: new Date().toISOString(),
    });

    // 8. 返回结果
    return new Response(
      JSON.stringify({
        qr_code: result.qrCode,
        out_trade_no: outTradeNo,
        amount: amountStr,
        subject,
        discount: discountApplied,
        duration_days: planConfig.duration_days,
      }),
      { headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ error: `服务器错误: ${(e as Error).message}` }),
      { status: 500, headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  }
});
