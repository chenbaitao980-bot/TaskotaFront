import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getServiceClient } from "../_shared/supabase.ts";
import { sendWxPusherMessage } from "../_shared/wxpusher.ts";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200 });
  }

  const supabase = getServiceClient();

  try {
    // 1. 查所有已启用的微信绑定
    const { data: bindings, error: bindErr } = await supabase
      .from("wechat_bindings")
      .select("user_id, wxpusher_uid")
      .eq("enabled", true);

    if (bindErr) throw bindErr;
    if (!bindings || bindings.length === 0) {
      return new Response(JSON.stringify({ sent: 0, reason: "no bindings" }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    const now = Date.now();
    const windowEnd = now + 2 * 60 * 1000; // 未来 2 分钟窗口
    let totalSent = 0;

    for (const binding of bindings) {
      const { user_id, wxpusher_uid } = binding;

      // 2. 查该用户的待提醒任务
      const { data: tasks, error: taskErr } = await supabase
        .from("user_tasks")
        .select(
          "id, title, description, start_date, remind_before_minutes, reminder_enabled"
        )
        .eq("user_id", user_id)
        .eq("deleted", false)
        .neq("status", 2) // 非完成
        .eq("reminder_enabled", true)
        .not("start_date", "is", null);

      if (taskErr) {
        console.error(`[scan] task query error for user=${user_id}:`, taskErr);
        continue;
      }
      if (!tasks || tasks.length === 0) continue;

      for (const task of tasks) {
        const startMs =
          typeof task.start_date === "number"
            ? task.start_date
            : new Date(task.start_date).getTime();
        const remindBefore = (task.remind_before_minutes ?? 15) * 60 * 1000;
        const remindAt = startMs - remindBefore;

        // 提醒时间在 [now, now+2min) 窗口内
        if (remindAt < now || remindAt >= windowEnd) continue;

        // 3. 检查是否已推送
        const { data: existing } = await supabase
          .from("wechat_reminder_log")
          .select("id")
          .eq("user_id", user_id)
          .eq("task_id", task.id)
          .eq("reminder_type", "before")
          .maybeSingle();

        if (existing) continue;

        // 4. 推送
        const minutesText = task.remind_before_minutes ?? 15;
        const title = `⏰ ${task.title}`;
        const content = `任务「${task.title}」将在 ${minutesText} 分钟后开始${task.description ? "\n" + task.description : ""}`;

        const ok = await sendWxPusherMessage(wxpusher_uid, title, content);
        if (ok) {
          // 5. 记录日志
          await supabase.from("wechat_reminder_log").upsert({
            user_id,
            task_id: task.id,
            reminder_type: "before",
          });
          totalSent++;
          console.log(
            `[scan] sent reminder: user=${user_id} task=${task.id} title=${task.title}`
          );
        }
      }
    }

    return new Response(JSON.stringify({ sent: totalSent }), {
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
