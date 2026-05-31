# 低成本上线方案

## 结论

采用 Cloudflare Pages 免费层 + Supabase 免费层，预估月固定成本 0 美元。

## 依据

- Cloudflare Pages Free 当前包含每月 500 次构建、单站点最多 20,000 个文件、单文件 25 MiB、每项目最多 100 个自定义域名，足够托管本静态站点。
- Supabase Free 当前包含 500 MB 数据库、50,000 MAU、5 GB egress、1 GB Storage。本项目只有个人使用，容量和访问量都远低于免费额度。

官方链接：

- https://developers.cloudflare.com/pages/platform/limits/
- https://supabase.com/pricing

## 为什么不用服务器

本网站的业务只需要登录、表格 CRUD、少量配置读写。Supabase Auth + Postgres RLS 可以直接完成鉴权和数据隔离，静态前端不需要 Node、云服务器、容器或反向代理。

## 上线步骤

1. 撤销已暴露的 Supabase Personal Access Token。
2. 在 Supabase 新建项目，运行 `supabase.sql`。
3. 把 `allowed_users` 示例邮箱改成自己的登录邮箱。
4. 把 `config.js` 中的占位值改成 Supabase Project URL 和 anon public key。
5. 在 Cloudflare Pages 创建项目：
   - Build command 填 `bash personal_admin_site/build-cloudflare.sh`。
   - Build output directory 填 `personal_admin_site`。
   - 环境变量填 `PUBLIC_SUPABASE_URL` 和 `PUBLIC_SUPABASE_ANON_KEY`。
6. 部署后把 Supabase Auth 的 Site URL 和 Redirect URLs 改成 Cloudflare Pages URL。
7. 用登录邮箱测试 OTP 登录、密钥加密保存、动态数据保存、App 保存和删除。

## 发布前检查

- `config.js` 不包含 `sbp_`、`service_role` 或其他私钥。
- `supabase.sql` 已开启 RLS。
- `allowed_users` 只包含自己的邮箱。
- Cloudflare Pages 已应用 `_headers` 安全头。
