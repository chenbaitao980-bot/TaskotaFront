# Research: 桌面悬浮便签 UI 美化调研

- **Query**: 为 Taskora Windows 桌面 360x112 置顶悬浮便签（内容卡 344x96）做美化调研，解决"边框有黑线很丑"问题；不写代码，只产出结论
- **Scope**: mixed（内部代码 + 外部 GitHub/设计规范）
- **Date**: 2026-08-03

## 结论速览（TL;DR）

"黑线"的直接元凶是当前卡片三重叠加：`Material(elevation: 10, shadowColor: 黑@18%)` 的深色挤出阴影紧贴卡片边缘 + `Border.all(优先级色@48%)` 的半透明整圈描边 + `bgCard@0.98` 非完全不透明让阴影/底色从边缘漏入。**推荐方案 A（无彩色整圈描边 + 阴影分层 + 不透明卡 + 圆角 8→12）**，必要时叠加 hairline `borderSubtle` 细边框兜底；优先级只用左侧色条 + 标题色点，不再整圈描边。真毛玻璃（透出桌面）需要原生窗口效果依赖，成本高，建议列为 V2。

---

## 1. 可用的 UI / frontend skills

基于本会话可用 skills 列表盘点（浏览而非 find-skills 安装，见 Caveats）：

| Skill | 是否可用 | 价值 |
|---|---|---|
| `frontend-design`（anthropic-skills:frontend-design） | ✅ 可用 | 提供"非模板化"视觉方向、排版、间距、层级指引；任务描述明确覆盖"reshape existing UI"，最契合本卡片美化定调 |
| `design-review` | ✅ 可用 | 视觉 QA 循环：间距/层级/AI-slop/慢交互检测，改完后用 before/after 截图逐项验证，做验收 |
| `flutter-dart-code-review` | ✅ 可用 | Flutter widget / 状态管理 / 性能 checklist，改完后做代码质量复查（非视觉） |
| `ui-ux-pro-max`（anthropic-skills:ui-ux-pro-max） | ⚠️ 受限 | 仅目录入口，上游模板/数据未随附，本会话不能实际执行，只能当方法论索引 |
| `mermaid-expert` / `archify` | ❌ | 绘图工具，与本任务无关 |
| `obsidian-*` / `product-lens` / `market-research` 等 | ❌ | 笔记/业务调研，与本任务无关 |

**建议**：定方向用 `frontend-design`，改完用 `design-review` 验收，代码用 `flutter-dart-code-review` 复查。无需 find-skills 安装新技能。

---

## 2. GitHub / 网页参考（附 URL）与视觉手法

### 2.1 flutter_acrylic — 原生窗口 acrylic / mica 效果
- URL: https://github.com/alexmercerind/flutter_acrylic （655★，2024-06 后未更新）
- 视觉手法：`WindowEffect.acrylic` / `mica` / `tabbed` / `aero` / `transparent` 系统级毛玻璃与动态材质。Win10 1803+ 用未公开的 `SetWindowCompositionAttribute`，Win11 22523+ 用 `DwmSetWindowAttribute`；README 提示 Win10 下 blur 可能漏出窗口边界、需自绘边框。
- 参考价值：真"透桌面毛玻璃"的唯一低成本通道；但因未更新 + 未公开 API，只建议作为 V2 探索。

### 2.2 fluent_ui — WinUI3 移植到 Flutter
- URL: https://github.com/bdlukaa/fluent_ui （3449★，活跃）
- 视觉手法：`Card`/`CardThemeData`、layer fill（`CardFillColorDefaultBrush`）、elevation 分级（resting/hover/pressed 阴影逐级变化）、hover 才出现的描边、圆角 8/12 体系、FocusVisual。**常态无描边，靠 elevation + layer 颜色分层；强调只出现一次（hover 或焦点）**。
- 参考价值：Windows 原生观感的最佳对标，其 Card 造型/边框时机逻辑可直接借鉴。

### 2.3 super_native_extensions — 原生能力（剪贴板/拖放/菜单）
- URL: https://github.com/superlistapp/super_native_extensions （570★）
- 视觉手法：非 UI 包，但其 rust 侧已有 `rust/src/blur.rs`（Windows 背景模糊），Dart 侧**尚未暴露稳定的 Windows blur API**（lib 下只有 web blur）。
- 参考价值：本项目经 `super_clipboard` 已把它作为传递依赖（`super_native_extensions_plugin.dll` 已在 release 构建里）。若未来走模糊路线，原生构建产物已具备，但当前 pub 包版本（0.9.1）拿不到 blur API，不能零成本使用。

### 2.4 one4zero/sticky-flow — Flutter 桌面便签应用
- URL: https://github.com/one4zero/sticky-flow （真实桌面便签实现，参考代码结构/卡片造型，星标少）
- 视觉手法：经典"便签纸"意象——卡片本体淡色 + 圆角 + 阴影，优先级/状态用色点或标签而非整圈描边；悬浮面板常带微渐变与顶部色带。

### 2.5 twist_toast — Flutter 通知卡片样式库
- URL: https://github.com/QasimAwan925/twist_toast （toast/通知卡样式集合）
- 视觉手法：10 种卡片样式 + 9 方向 + 动效。样式差异主要来自：圆角半径、是否描边（多数无描边/细 hairline）、阴影柔和度、左侧色条/图标点亮色、深浅主题两套 token。可当"卡片层级"现成题库。

---

## 3. 主流同类应用"迷你悬浮提醒"设计惯例

### 3.1 滴答清单（TickTick）桌面
- 悬浮/时间块卡片：纯色卡 + 圆角 ~12 + 柔和阴影，**无描边**；优先级用左侧窄色条（~4px）或标题前小圆点 + 顶行小标签；动作按钮 hover 才显示。
- 深色模式边框用近黑灰 token，绝不用纯黑。

### 3.2 Todoist 桌面
- 极浅底色 + 无边框或 hairline；阴影轻柔；优先级用左侧 4 档色条（红→灰）加宽 ~3px，**不整圈描边**。

### 3.3 Things 3（macOS）
- 无边框卡片，hover 才出阴影；priority 用标题左侧小色块（红橙黄蓝）点缀；圆角 8-10；背景用 macOS vibrancy 毛玻璃分层。

### 3.4 Notion 桌面
- 卡片/toggle：hairline 边框 + 无阴影或极淡阴影；强调色只用于 hover 描边而非常态；深色模式 border 用 `#2C2C2E` 一类近黑灰。

### 3.5 macOS 通知横幅（Notification Center）
- 圆角 10-12；背景 `NSVisualEffectView` 毛玻璃 + 1px 半透明白 hairline；图标 + 粗体标题 + 副文本，右侧两个胶囊按钮；**没有彩色整圈描边**，靠模糊/半透明分层。

### 3.6 Windows 11 通知 toast（WinUI / Fluent）
- 圆角 ~8；背景 `AcrylicBrush` 毛玻璃透桌面；hairline 用 `CardStrokeColorDefaultBrush`（白色 5-8% alpha）；图标 + Segoe UI SemiBold 14 标题 + 正文 + 2 action；品牌色只出现在 app 图标一角。

### 3.7 Material 3 Card 规范（m3.material.io/components/card）
- 三型卡片：**elevated**（表面色 + 阴影 + surfaceTint 叠色）、**filled**（surfaceContainerHighest）、**outlined**（`outline` 色 1dp hairline）。
- 圆角 12dp（大卡 16、小卡 8）；层级靠阴影/叠色而非描边；hover 态只提升 elevation。

### 3.8 共性总结——"为什么它们好看"
1. **无硬边框，靠阴影分层**：elevation 才是层级信号；常态描边只在必须时用。
2. **hairline 必用主题 token**：近底色的极淡色（M3 `outlineVariant`、WinUI 白 5-8%），绝不用高饱和色半透明叠在卡片上。
3. **圆角 12-16**：现代桌面观感，避免 4-8 的"按钮感"。
4. **信息层级 2-3 级**：小标签(11-12px)/标题(14-16px 700)/副文本(12px textSecondary)；动作图标 hover 才出现。
5. **优先级用色条/色点点缀**，不用整圈描边——整圈描边放大优先级会抢视觉重心，且半透明描边在合成时容易脏。
6. **深浅主题两套 token**：border 深色下用近黑灰而非纯黑；透明度用整卡 opacity，不用边缘 stroke alpha。

---

## 4. "黑线"成因分析（代码级，`desktop_floating_task_tab.dart`）

当前结构（44-74 行附近）：

```dart
Material(color: bgCard.withValues(alpha: 0.98), borderRadius: 8, elevation: 10,
         shadowColor: Colors.black.withValues(alpha: 0.18))
  → InkWell(borderRadius: 8)
    → Container(decoration: BoxDecoration(borderRadius: 8,
        border: Border.all(color: priorityColor.withValues(alpha: 0.48))))  // 整圈彩色描边
```

关键事实（已核实）：
- 窗口**未配置透明**：全项目 grep 无 `setAsFrameless` / `setOpacity` / `setTransparent`。悬浮卡片是 `MaterialApp.home` 的返回值，其窗口背景 = `MaterialApp` 的 `scaffoldBackgroundColor` = `bgScaffold`（亮色 `0xFFF5F5F0`、深色 `0xFF0E0F11`）。
- 卡片根 Material 是 `Colors.transparent`，卡片四周 8px padding 区域直接露出 `bgScaffold`。

三重叠加的成因：

1. **`Material(elevation: 10, shadowColor: Colors.black@0.18)`（主因）**：Flutter 的 elevation 阴影是贴着 shape 外缘挤出的深色剪影。elevation 10 + 黑 18% 在浅色 bgScaffold 上就是一圈紧贴卡片边界的暗色环——用户感知为"黑线"。阴影从卡片外边界就开始，恰好叠在描边下面，把描边衬托得更脏。
2. **`Border.all(priorityColor@0.48)` 半透明整圈描边（主因/放大）**：48% alpha 的彩色 hairline 叠在卡片边缘上，其外半像素与卡片外的 `bgScaffold`（深色模式下近黑）混色 → 边缘发灰发黑。**深色主题下尤其明显**：`bgScaffold`≈`0xFF0E0F11`，48% 的优先级色叠上去本来就向黑去饱和，几乎看不出彩色只剩黑。
3. **`bgCard@0.98` 非完全不透明（放大）**：2% 的透明让 elevation 阴影/底色从整卡边缘漏入，边缘一圈再暗一档；再加上 Material/InkWell/Container 三层同 8px 圆角嵌套的亚像素接缝。

结论：不是"某个 bug 画了黑线"，而是**深色挤出阴影 + 半透明彩色整圈描边 + 非不透明卡**三者叠加的合成产物。

---

## 5. 可行美化方向（每个带利弊）

### 方案 A（推荐）：无彩色整圈描边 + 阴影分层 + 不透明卡 + 圆角 12
- 做法：
  - 去掉 `Border.all(priorityColor...)` 整圈描边；
  - `Material elevation` 降为 0，改在容器 `BoxDecoration.boxShadow` 用 `AppTheme.cardShadow`（已有 token：暗色黑 0.30 / 亮色 0.06，blur 8 offset (0,2)）；
  - 卡片背景改 100% 不透明 `AppTheme.bgCard`；
  - 圆角 8 → 12（对齐项目 popupMenu/input/button 的 12、CardTheme 的 16）；
  - 优先级只保留左侧 8px 色条，标题前补一个 6px 优先级色点（P0/P1 可见）。
- 利：零新依赖、彻底消黑边、完全符合 M3 elevated card / WinUI / macOS 惯例、全用现有 token；阴影 token 已按深浅主题分化。
- 弊：纯靠阴影分层，浅色环境（亮壁纸/低对比显示器）下层级可能偏弱——用"方案 A + hairline borderSubtle 兜底"缓解。

### 方案 B：hairline `borderSubtle` 细边框 + 色条/色点
- 做法：保留边框但用主题 token `AppTheme.borderSubtle`、width 0.5（对齐项目里 popupMenu/input/chip 已有的 0.5 hairline 惯例）；优先级色从整圈描边撤回为左侧色条 + 色点。
- 利：亮色环境仍清晰可辨；与项目其他组件的 hairline 风格统一；深浅主题自动适配。
- 弊：细边框在低 DPI 下 sub-pixel 渲染可能显淡/锯齿，需确认 0.5 在 Windows 各 scale 下观感一致。

### 方案 C：优先级色条 + 顶部 2-3px 色带 / softGradient 渐变卡
- 做法：不做整圈描边；左侧色条保留，卡片内顶部加 2-3px 同优先级色渐变带；背景可选 `AppTheme.softGradient`（已有 softGradientStart/End token）做轻渐变。
- 利：层次最丰富、优先级一眼可见、无描边黑线问题、复用现成 gradient token。
- 弊：顶部色带在 344px 窄卡上可能喧宾夺主；渐变卡需为深浅两套再调 token；实现比 A/B 略复杂。

### 方案 D（备选，成本高）：真毛玻璃（透出桌面）
- 做法：用 `flutter_acrylic`（`WindowEffect.acrylic`/`mica`）做原生窗口模糊，或等 `super_native_extensions` 的 Windows blur API 放出（当前 0.9.1 无稳定 Dart API）。
- 利：视觉上限最高，最像 macOS/Windows 11 原生。
- 弊：**新增第三方依赖**（flutter_acrylic 自 2024-06 未更新、Win10 用未公开 API、README 提示 blur 可能漏出窗口边界需自绘边框）；原生窗口效果改动可能影响 frameless/置顶/拖拽；深色/亮色需两套 effect 参数；收益/风险比低。**纯 Flutter `BackdropFilter` 做不到透桌面模糊**（只能模糊窗口内自身内容），必须走原生窗口效果。

### 推荐
**方案 A 为主，叠加方案 B 的 hairline `borderSubtle` 兜底**（即：无彩色整圈描边、不透明卡、`AppTheme.cardShadow` 阴影分层、圆角 12、hairline borderSubtle 0.5 可选、左侧色条 + 标题色点）。C 可作为视觉增强的候选，D 明确列为 V2，不进入本次改动。

---

## 6. 建议的 Flutter widget 结构（供 implement 参考，非本调研的改动）

```dart
Material(
  color: Colors.transparent,
  child: DragToMoveArea(
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadow,                       // 替换 Material elevation
        border: Border.all(color: AppTheme.borderSubtle, width: 0.5), // 可选 hairline 兜底
      ),
      child: Material(
        color: AppTheme.bgCard,                               // 100% 不透明
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            child: Row(children: [ /* 保留：左侧 8px 优先级色条 + 12 间距 + 文本列 + 图标列 */ ]),
          ),
        ),
      ),
    ),
  ),
)
```

要点：
- 阴影从 `Material elevation` 迁到 `BoxDecoration.boxShadow` 用 `AppTheme.cardShadow` token；Material 降为纯底色载体 + InkWell 水波纹宿主。
- 卡片 `bgCard` 用 100% 不透明，消除边缘漏光；圆角 8→12 并统一（InkWell 与容器同半径）。
- 优先级色彩只保留左侧色条；如需在 P0/P1 强调，在标题行加 6px 色点（`AppTheme.priorityP0/P1`），不整圈描边。

---

## 7. 约束与注意事项

- **不引入新第三方依赖**：A/B/C 全部零新增依赖，复用 `AppTheme` 现有 token（`bgCard`、`borderSubtle`、`cardShadow`、`priorityP0..P3`、`softGradient`）。
- 若走 D（毛玻璃）才需引入 `flutter_acrylic`（未维护）或等 `super_native_extensions` blur API（已在依赖树、原生构建产物已具备，但当前 0.9.1 未暴露），两项都有维护风险。
- 窗口未配置透明：本改动不应涉及 `window_manager` 的透明/帧配置，只动 widget 层。

## Caveats / Not Found

- GitHub 搜索接口对若干查询返回空/噪声（如 "flutter always on top window" 命中无关仓库），故参考资料改为按已知仓库名直接抓取，2.4/2.5 为低星但真实的相关实现，仅作实现参考，不作为权威设计来源。
- `super_native_extensions` 的 Windows blur：rust 侧 `rust/src/blur.rs` 存在但 Dart 侧未见稳定导出，结论以 pub 版本 0.9.1 为准。
- 未实际运行应用验证黑线在亮/暗两套主题下的具体观感；成因分析基于代码逐层推理 + Flutter/Windows 合成常识，建议 implement 后先在 obsidian（暗）与 claude（亮）各截图核对。
