/**
 * schedule-push Edge Function
 *
 * POST  { task_id, title, body, scheduled_at }
 *   → 调阿里云 Push API 定时推送（PushTime），同时写入 scheduled_pushes 供 WxPusher cron 兜底
 *
 * DELETE { task_id }
 *   → 取消阿里云定时推送，删除 scheduled_pushes 记录
 */

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { getServiceClient, getUserIdFromAuth } from "../_shared/supabase.ts";
import { callAliyunPush } from "../_shared/aliyun.ts";

const ACCESS_KEY_ID = Deno.env.get("ALIYUN_ACCESS_KEY_ID") ?? "";
const ACCESS_KEY_SECRET = Deno.env.get("ALIYUN_ACCESS_KEY_SECRET") ?? "";
const APP_KEY = Deno.env.get("ALIYUN_PUSH_APP_KEY") ?? "";

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { status: 200 });

  const supabase = getServiceClient();
  const userId = getUserIdFromAuth(req);
  if (!userId) return new Response("Unauthorized", { status: 401 });

  // ── POST: 注册定时推送 ──────────────────────────────────────────────────
  if (req.method === "POST") {
    const { task_id, title, body, scheduled_at } = await req.json();
    if (!task_id || !title || !scheduled_at) {
      return new Response(
        JSON.stringify({ error: "task_id / title / scheduled_at required" }),
        { status: 400 }
      );
    }

    const scheduledDate = new Date(scheduled_at);
    const expireDate = new Date(scheduledDate.getTime() + 24 * 60 * 60 * 1000);

    let aliyunMsgId: string | null = null;

    // 1. 查用户设备 registration ID
    if (ACCESS_KEY_ID) {
      const { data: device } = await supabase
        .from("user_devices")
        .select("aliyun_registration_id")
        .eq("user_id", userId)
        .maybeSingle();

      if (device?.aliyun_registration_id) {
        try {
          const result = await callAliyunPush(
            ACCESS_KEY_ID,
            ACCESS_KEY_SECRET,
            "Push",
            {
              AppKey: APP_KEY,
              Target: "DEVICE",
              TargetValue: device.aliyun_registration_id,
              Title: title,
              Body: body ?? title,
              PushType: "NOTICE",
              DeviceType: "ANDROID",
              PushTime: scheduledDate.toISOString(),
              ExpireTime: expireDate.toISOString(),
              StoreOffline: "true",
              // Android 8.0+ 必须指定 NotificationChannel ID，必须匹配客户端已注册的通道
              // 复用 schedule_reminders（flutter_local_notifications 创建，已确认工作正常）
              AndroidNotificationChannel: "schedule_reminders",
              // 通知提醒方式：声音+震动
              AndroidNotifyType: "BOTH",
            }
          );
          aliyunMsgId = (result.MessageId as string) ?? null;
          console.log(
            `[schedule-push] aliyun scheduled msgId=${aliyunMsgId} user=${userId} task=${task_id}`
          );
        } catch (e) {
          console.error("[schedule-push] aliyun push failed:", e);
        }
      }
    }

    // 2. 存入 scheduled_pushes（供 WxPusher cron 兜底，以及记录 msgId 用于取消）
    await supabase.from("scheduled_pushes").upsert(
      {
        user_id: userId,
        task_id,
        title,
        body: body ?? title,
        scheduled_at,
        aliyun_message_id: aliyunMsgId,
        sent_at: null,
      },
      { onConflict: "user_id,task_id" }
    );

    return new Response(
      JSON.stringify({ success: true, aliyun_msg_id: aliyunMsgId }),
      { headers: { "Content-Type": "application/json" } }
    );
  }

  // ── DELETE: 取消定时推送 ────────────────────────────────────────────────
  if (req.method === "DELETE") {
    const { task_id } = await req.json();
    if (!task_id) {
      return new Response(JSON.stringify({ error: "task_id required" }), {
        status: 400,
      });
    }

    const { data: push } = await supabase
      .from("scheduled_pushes")
      .select("aliyun_message_id")
      .eq("user_id", userId)
      .eq("task_id", task_id)
      .maybeSingle();

    if (push?.aliyun_message_id && ACCESS_KEY_ID) {
      try {
        await callAliyunPush(ACCESS_KEY_ID, ACCESS_KEY_SECRET, "CancelPush", {
          AppKey: APP_KEY,
          MessageId: push.aliyun_message_id,
        });
        console.log(
          `[schedule-push] cancelled msgId=${push.aliyun_message_id}`
        );
      } catch (e) {
        console.error("[schedule-push] cancel failed:", e);
      }
    }

    await supabase
      .from("scheduled_pushes")
      .delete()
      .eq("user_id", userId)
      .eq("task_id", task_id);

    return new Response(JSON.stringify({ success: true }), {
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response("Method not allowed", { status: 405 });
});
