import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getServiceClient } from "../_shared/supabase.ts";
import { sendWxPusherMessage } from "../_shared/wxpusher.ts";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200 });
  }

  const supabase = getServiceClient();

  try {
    const now = new Date();
    // 窗口：24小时前到2分钟后
    // 左边界扩大到24h：若某次cron期间WxPusher短暂失败，下一次cron仍能补发，不会永久丢失
    const windowStart = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    const windowEnd = new Date(now.getTime() + 2 * 60 * 1000);

    // 1. 查未发送的、在时间窗口内的推送记录
    const { data: pushes, error: pushErr } = await supabase
      .from("scheduled_pushes")
      .select("id, user_id, task_id, title, body, scheduled_at")
      .is("sent_at", null)
      .gte("scheduled_at", windowStart.toISOString())
      .lte("scheduled_at", windowEnd.toISOString());

    if (pushErr) throw pushErr;
    if (!pushes || pushes.length === 0) {
      return new Response(JSON.stringify({ sent: 0, reason: "no pending pushes" }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // 2. 批量查用户微信绑定（已启用）
    const userIds = [...new Set(pushes.map((p: any) => p.user_id))];
    const { data: bindings, error: bindErr } = await supabase
      .from("wechat_bindings")
      .select("user_id, wxpusher_uid")
      .in("user_id", userIds)
      .eq("enabled", true);

    if (bindErr) console.error("[scan] wechat_bindings query error:", bindErr);

    const bindingMap = new Map<string, string>(
      (bindings ?? []).map((b: any) => [b.user_id, b.wxpusher_uid])
    );

    let totalSent = 0;

    for (const push of pushes) {
      const wxpusherUid = bindingMap.get(push.user_id);
      if (!wxpusherUid) {
        console.warn(`[scan] no enabled binding for user=${push.user_id}`);
        continue;
      }

      const ok = await sendWxPusherMessage(
        wxpusherUid,
        `⏰ ${push.title}`,
        push.body
      );

      if (ok) {
        await supabase
          .from("scheduled_pushes")
          .update({ sent_at: now.toISOString() })
          .eq("id", push.id);
        totalSent++;
        console.log(`[scan] sent: user=${push.user_id} task=${push.task_id} title=${push.title}`);
      } else {
        console.error(`[scan] failed: user=${push.user_id} task=${push.task_id}`);
      }
    }

    return new Response(JSON.stringify({ sent: totalSent, checked: pushes.length }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error("[scan-wechat-reminders] error:", e);
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
