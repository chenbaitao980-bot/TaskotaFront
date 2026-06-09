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

  try {
    const supabase = getServiceClient();

    // GET: 返回所有会员配置（供 Flutter app 读取）
    if (req.method === "GET") {
      // 获取会员类型
      const { data: memberTypes, error: typesError } = await supabase
        .from("member_types")
        .select("*")
        .order("sort_order", { ascending: true });

      if (typesError) {
        return new Response(
          JSON.stringify({ error: `获取会员类型失败: ${typesError.message}` }),
          {
            status: 500,
            headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
          }
        );
      }

      // 获取有效的折扣码
      const { data: discountCodes, error: discountsError } = await supabase
        .from("member_discount_codes")
        .select("*")
        .eq("active", true)
        .order("created_at", { ascending: false });

      if (discountsError) {
        return new Response(
          JSON.stringify({
            error: `获取折扣码失败: ${discountsError.message}`,
          }),
          {
            status: 500,
            headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
          }
        );
      }

      // 获取充值梯度
      const { data: rechargeTiers, error: tiersError } = await supabase
        .from("member_recharge_tiers")
        .select("*")
        .order("sort_order", { ascending: true });

      if (tiersError) {
        return new Response(
          JSON.stringify({
            error: `获取充值梯度失败: ${tiersError.message}`,
          }),
          {
            status: 500,
            headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
          }
        );
      }

      return new Response(
        JSON.stringify({
          member_types: memberTypes || [],
          discount_codes: discountCodes || [],
          recharge_tiers: rechargeTiers || [],
        }),
        {
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        }
      );
    }

    // POST: 创建/更新会员配置（仅管理员）
    if (req.method === "POST") {
      // 验证管理员身份
      const userId = getUserIdFromAuth(req);
      if (!userId) {
        return new Response(JSON.stringify({ error: "未登录" }), {
          status: 401,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        });
      }

      // 检查用户是否为管理员（通过邮箱白名单）
      const { data: userData, error: userError } = await supabase.auth.admin.getUserById(userId);
      const adminEmails = (Deno.env.get("ADMIN_EMAILS") || "574658218@qq.com").split(",").map(e => e.trim());
      const userEmail = userData?.user?.email || "";

      if (userError || !userEmail || !adminEmails.includes(userEmail)) {
        return new Response(JSON.stringify({ error: "无管理员权限" }), {
          status: 403,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        });
      }

      const body = await req.json();
      const { action, table, data, id } = body;

      if (!action || !table) {
        return new Response(
          JSON.stringify({ error: "缺少 action 或 table 参数" }),
          {
            status: 400,
            headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
          }
        );
      }

      // 验证表名
      const allowedTables = [
        "member_types",
        "member_discount_codes",
        "member_recharge_tiers",
      ];
      if (!allowedTables.includes(table)) {
        return new Response(JSON.stringify({ error: "无效的表名" }), {
          status: 400,
          headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
        });
      }

      let result;

      switch (action) {
        case "create": {
          const { data: created, error: createError } = await supabase
            .from(table)
            .insert(data)
            .select()
            .single();

          if (createError) {
            return new Response(
              JSON.stringify({ error: `创建失败: ${createError.message}` }),
              {
                status: 500,
                headers: {
                  ...CORS_HEADERS,
                  "Content-Type": "application/json",
                },
              }
            );
          }
          result = created;

          // 记录操作日志
          await supabase.from("member_config_logs").insert({
            admin_email: userEmail || userId,
            action: `create_${table.replace("member_", "")}`,
            detail: `创建记录: ${JSON.stringify(data)}`,
            payload: JSON.stringify(data),
          });
          break;
        }

        case "update": {
          if (!id) {
            return new Response(
              JSON.stringify({ error: "更新操作需要提供 id" }),
              {
                status: 400,
                headers: {
                  ...CORS_HEADERS,
                  "Content-Type": "application/json",
                },
              }
            );
          }

          const { data: updated, error: updateError } = await supabase
            .from(table)
            .update(data)
            .eq("id", id)
            .select()
            .single();

          if (updateError) {
            return new Response(
              JSON.stringify({ error: `更新失败: ${updateError.message}` }),
              {
                status: 500,
                headers: {
                  ...CORS_HEADERS,
                  "Content-Type": "application/json",
                },
              }
            );
          }
          result = updated;

          // 记录操作日志
          await supabase.from("member_config_logs").insert({
            admin_email: userEmail || userId,
            action: `update_${table.replace("member_", "")}`,
            detail: `更新记录 ID: ${id}`,
            payload: JSON.stringify({ id, ...data }),
          });
          break;
        }

        case "delete": {
          if (!id) {
            return new Response(
              JSON.stringify({ error: "删除操作需要提供 id" }),
              {
                status: 400,
                headers: {
                  ...CORS_HEADERS,
                  "Content-Type": "application/json",
                },
              }
            );
          }

          // 如果是会员类型，检查是否有用户在使用
          if (table === "member_types") {
            const { count, error: countError } = await supabase
              .from("user_subscriptions")
              .select("*", { count: "exact", head: true })
              .eq("plan", id);

            if (!countError && count && count > 0) {
              return new Response(
                JSON.stringify({
                  error: `无法删除：该类型仍有 ${count} 个活跃用户`,
                }),
                {
                  status: 400,
                  headers: {
                    ...CORS_HEADERS,
                    "Content-Type": "application/json",
                  },
                }
              );
            }
          }

          const { error: deleteError } = await supabase
            .from(table)
            .delete()
            .eq("id", id);

          if (deleteError) {
            return new Response(
              JSON.stringify({ error: `删除失败: ${deleteError.message}` }),
              {
                status: 500,
                headers: {
                  ...CORS_HEADERS,
                  "Content-Type": "application/json",
                },
              }
            );
          }

          // 记录操作日志
          await supabase.from("member_config_logs").insert({
            admin_email: userEmail || userId,
            action: `delete_${table.replace("member_", "")}`,
            detail: `删除记录 ID: ${id}`,
            payload: JSON.stringify({ id }),
          });

          result = { success: true };
          break;
        }

        default:
          return new Response(
            JSON.stringify({ error: `未知操作: ${action}` }),
            {
              status: 400,
              headers: {
                ...CORS_HEADERS,
                "Content-Type": "application/json",
              },
            }
          );
      }

      return new Response(JSON.stringify({ data: result }), {
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ error: "不支持的请求方法" }), {
      status: 405,
      headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(
      JSON.stringify({ error: `服务器错误: ${(e as Error).message}` }),
      {
        status: 500,
        headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
      }
    );
  }
});
