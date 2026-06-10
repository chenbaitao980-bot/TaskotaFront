# Deploy Guide

> **Purpose**: 项目 Web 端部署流程规范 — 如何将代码变更推送到 Vercel 生产环境。

---

## 部署架构

```
本地开发 → git push github master → GitHub Actions (deploy-web.yml) → flutter build web → push build/web 到 main 分支 → Vercel 检测 main 变化 → 自动部署
```

- **GitHub Actions workflow**: `.github/workflows/deploy-web.yml`
- **触发分支**: `master`、`source`
- **Vercel 关联分支**: `main`（由 GitHub Actions 自动推送构建产物）
- **Vercel 配置**: `web/vercel.json`（rewrites + headers）

---

## 每次改完代码后的部署流程

### Step 1: 确保代码已提交

```bash
git status              # 确认没有未提交的改动
```

### Step 2: 推送到 master 分支

```bash
git push github master
```

**注意**: 必须推到 `github` 这个 remote（即 `https://github.com/chenbaitao980-bot/TaskotaFront.git`），不是其他 remote。

### Step 3: 等待 GitHub Actions 完成

推送后 GitHub Actions 会自动运行 `Deploy Flutter Web` workflow：
1. 拉取代码 → `flutter pub get` → `flutter build web`
2. 将 `build/web` 产物 force push 到 `main` 分支

可以在 https://github.com/chenbaitao980-bot/TaskotaFront/actions 查看进度。

### Step 4: 验证 Vercel 部署

GitHub Actions 成功后，Vercel 检测到 `main` 分支变化，自动触发部署。

在 Vercel Dashboard 确认部署状态和生产 URL 是否更新。

---

## 常见问题

### Q: 推了 master 但 Vercel 没反应？

1. 检查 GitHub Actions 是否成功跑完：https://github.com/chenbaitao980-bot/TaskotaFront/actions
2. 确认 Vercel 项目关联的是 `main` 分支
3. 如果 Actions 失败，检查 `flutter build web` 的构建日志

### Q: 只想部署但不走 Actions？

```bash
# 手动构建并直接推到 main 分支
flutter build web --release --base-href /
cd build/web
git init && git add -A && git commit -m "manual deploy"
git push --force https://github.com/chenbaitao980-bot/TaskotaFront.git HEAD:main
```

### Q: 如何修改部署触发条件？

编辑 `.github/workflows/deploy-web.yml` 中的 `on.push.branches` 列表。

---

## 相关文件

| 文件 | 作用 |
|------|------|
| `.github/workflows/deploy-web.yml` | CI/CD workflow 定义 |
| `web/vercel.json` | Vercel 部署配置（rewrites, headers） |
| `build/web/vercel.json` | 构建时复制到产物目录 |

---

**Core Rule**: **每次改完代码 → `git push github master` → 等 Actions 跑完 → Vercel 自动部署。**
