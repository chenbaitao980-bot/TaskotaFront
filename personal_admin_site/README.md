# Personal Control Desk

最低成本方案：

1. 前端：静态 HTML/CSS/JS，部署到 Cloudflare Pages 免费层。
2. 数据/Auth：Supabase 免费层，使用 Email OTP 登录、RLS、邮箱 allowlist。
3. 密钥值：浏览器端 AES-GCM 加密后写入 Supabase，口令不保存、不上传。

## 初始化 Supabase

1. 在 Supabase 新建项目。
2. 打开 SQL Editor，执行 `supabase.sql`。
3. 把最后一行 `your-email@example.com` 改成自己的登录邮箱。
4. Authentication -> URL Configuration：
   - Site URL：填部署后的站点 URL。
   - Redirect URLs：填同一个站点 URL。
5. Project Settings -> API 复制 `Project URL` 和 `anon public key`。

## 本地配置

复制配置文件：

```powershell
Copy-Item personal_admin_site\config.example.js personal_admin_site\config.js
```

编辑 `config.js`：

```js
window.APP_CONFIG = {
  supabaseUrl: "https://YOUR_PROJECT_REF.supabase.co",
  supabaseAnonKey: "YOUR_SUPABASE_ANON_KEY"
};
```

只能使用 `anon public key`，不要把 Supabase Personal Access Token 或 service_role key 放进前端。

## 本地预览

```powershell
python -m http.server 4173 -d personal_admin_site
```

打开 `http://localhost:4173`。

## Cloudflare Pages 上线

1. 新建 Pages 项目。
2. 连接仓库，或选择 Direct Upload。
3. 推荐连接仓库后使用环境变量构建：
   - Build command：`bash personal_admin_site/build-cloudflare.sh`
   - Build output directory：`personal_admin_site`
   - 环境变量：`PUBLIC_SUPABASE_URL`、`PUBLIC_SUPABASE_ANON_KEY`
4. Direct Upload 时先在本机生成 `config.js`：
   ```powershell
   $env:PUBLIC_SUPABASE_URL="https://YOUR_PROJECT_REF.supabase.co"
   $env:PUBLIC_SUPABASE_ANON_KEY="YOUR_SUPABASE_ANON_KEY"
   powershell -ExecutionPolicy Bypass -File personal_admin_site\build-local.ps1
   powershell -ExecutionPolicy Bypass -File personal_admin_site\deploy-check.ps1
   ```
   然后上传 `personal_admin_site` 目录。
5. 部署后，把 Supabase Auth 的 Site URL / Redirect URLs 改成 Cloudflare Pages 域名。

## 安全事项

- 已泄露的 `sbp_` Personal Access Token 必须撤销并重新生成。
- 前端只能放 Supabase `anon public key`。
- 密钥加密口令丢失后，已有密钥值无法解密。
