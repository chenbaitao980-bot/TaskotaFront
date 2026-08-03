# Research: 跨 OpenAI-compatible 提供商的"关闭思考/最低思考等级"参数方案

- **Query**: 懒人日志 AI 调用 OpenAI-compatible `/chat/completions`，请求体目前只传 `{model, temperature: 0.2, messages}`。用户希望加一个"关闭思考 / 思考等级最低"的控制，且跨提供商尽量生效。
- **Scope**: external + internal（已结合 Taskora 项目代码约束）
- **Date**: 2026-08-03
- **Sources**: OpenAI SDK/官方文档快照、DeepSeek API 官方文档快照（web.archive.org）、阿里云百炼 model-studio 深度思考文档快照、智谱 BigModel 思考模式文档快照、Moonshot 平台文档（2026 快照）。说明：火山方舟 Ark 文档是 SPA，无法直接抓取正文，Ark 部分基于存档目录结构 + 既有认知标注了置信度，建议实现前用真实 Key 实测。

---

## Findings

### 0. 项目现状（内部约束，关键）

- 请求体构造点：`lib/services/home_lazy_log_service.dart:34-57` `structure()`，只发 `model` / `temperature: 0.2` / `messages`，无任何 thinking/reasoning 参数。
- 配置模型：`lib/models/assistant/assistant_models.dart` `AssistantModelConfig`（baseUrl/apiPath/apiKey/model/userInstructions，**没有** thinking 相关字段）。SharedPreferences 持久化（`assistant_config_service.dart`）。
- 配置 UI：`lib/presentation/pages/assistant/assistant_page.dart` `_AssistantConfigDialog`（文本输入，测试连接发 `max_tokens:1`）。默认 baseUrl 是火山方舟 `https://ark.cn-beijing.volces.com/api/coding/v3`（`_normalizedBaseUrl` 强制 `/api/coding/v3`），默认模型 `gpt-4o-mini`。
- **静默降级陷阱**：`structure()` 对非 401/403 的 Dio 错误会**静默走本地 fallback 解析**（`home_lazy_log_service.dart:74-85`）。所以若加的参数被某提供商判 400，用户不会看到报错，只会得到明显变差的 fallback 结果——比"报错"更隐蔽。任何加参数方案都要考虑这一点。
- **temperature 兼容陷阱**：请求体永远带 `temperature: 0.2`。OpenAI 的 o1/o3 推理模型要求 temperature 必须省略(=1)，否则 400。所以现在直接配 o1/o3 其实已经失败并静默 fallback。若做"关闭思考"，需一并考虑在检测到推理模型时去掉 temperature（或至少不加重这个问题）。
- 通用聊天服务 `assistant_chat_service.dart:205-211` 已在读 `reasoning_content`/`reasoning`/`thinking` 响应字段，说明项目对思考类模型已有响应侧适配。

---

### 1. 各提供商思考控制参数（2026-08 主源核实）

#### 1.1 OpenAI（o1 / o3 / gpt-5 系列）— `reasoning_effort`

- Chat Completions 顶层参数 `reasoning_effort`，2026 版 SDK 枚举：`none` / `minimal` / `low` / `medium` / `high` / `xhigh` / `max`（来源：openai-python `src/openai/types/chat/completion_create_params.py` + `types/shared/reasoning_effort.py`）。
- 官方 reasoning 指南（2026 快照）：`reasoning.effort`（Responses API 形态）取值 `none/minimal/low/medium/high/xhigh`，**"none" 用于不需要任何推理的时延敏感任务**；`gpt-5.5` 默认 `medium`。
- **限制**：
  - "Not all reasoning models support every value"——旧推理模型（o1/o3 系列）只支持 `low/medium/high`（更早文档写 "Min: low, Max: high"），`none/minimal` 可能 400。
  - o1/o3 类必须用 `max_completion_tokens`（不能用 `max_tokens`），且**不接受 temperature**（须省略）。gpt-5.x 放宽了 temperature。
  - `reasoning_effort` 对非推理模型（如 `gpt-4o-mini`）**无效但被忽略，不会报错**（OpenAI 官方语义：仅推理模型支持，其余忽略）。
- 结论：跨提供商最通用的"最低思考"参数就是 `reasoning_effort: "low"`；"彻底关闭"在 OpenAI 上=换非推理模型，或新模型用 `"none"`（仅新模型支持）。

#### 1.2 DeepSeek — `thinking` 对象 + `reasoning_effort`（2026 V4）

- **重大变化**：`deepseek-chat` / `deepseek-reasoner` 将于 **2026-07-24 废弃**，分别对应 `deepseek-v4-flash` 的非思考/思考模式。V4 时代建议用 `deepseek-v4-flash` / `deepseek-v4-pro`。
- 官方 Thinking Mode 指南（2026 快照）给出 OpenAI 格式控制参数：
  - 思考开关：`{"thinking": {"type": "enabled/disabled"}}` —— **`disabled` 即关闭思考**。
  - 思考强度：`{"reasoning_effort": "low/high/max"}`（实测映射表另含 `xhigh`，**无 `medium`**；默认思考开启且默认 effort=high）。
  - Anthropic 格式对照：`{"reasoning": {"effort": "none/low/high/max"}}`（none=关）。
- **兼容性铁证**："Thinking mode does not support `temperature`/`top_p`/`presence_penalty`/`frequency_penalty`… **setting these parameters will not trigger an error but will also have no effect**"——即 DeepSeek 对不支持的参数静默忽略，不 400。这直接支持"未知参数被忽略"的跨提供商安全性判断。
- 用 OpenAI SDK 时 `thinking` 要走 `extra_body`；裸 JSON 就是顶层字段，本项目用裸 JSON，直接放 body 顶层即可。
- 关闭思考方案：`{"thinking": {"type": "disabled"}}`；最低思考：`{"reasoning_effort": "low"}`。

#### 1.3 火山方舟 Ark（**项目默认 provider**）— 置信度中，建议实测

- Ark OpenAI 兼容 Chat API：`https://ark.cn-beijing.volces.com/api/v3/chat/completions`（本项目走 `/api/coding/v3/chat/completions`，是"编程场景 OpenAI 兼容"端点）。
- 存档索引确认 Ark 有 thinking 系列模型文档：`docs/82379/doubao-1-5-thinking-pro-m-250415`、`doubao-1.5-thinking-pro` 等——即 doubao 的思考是**模型变体**：thinking 型号（`doubao-1-5-thinking-pro`、`doubao-seed-1-6-thinking` 等）思考，普通 doubao 型号不思考，**没有请求级关闭开关，靠换模型 ID**。
- 对 Ark 上的第三方推理模型（DeepSeek-R1/V3、kimi-k2-thinking 等），Ark OpenAI 兼容接口接受标准 OpenAI 参数 `reasoning_effort`（low/medium/high）。这是 Ark 文档与业界惯例的一致点，但正文是 SPA 抓不到，**置信度中**。
- 建议：实现时把 Ark（baseUrl 含 `volces.com`）纳入"发 `reasoning_effort`"的映射分支，并用测试连接按钮实测确认不报错。

#### 1.4 智谱 GLM（BigModel / Z.ai）— `thinking` 对象

- 官方 Thinking 模式文档（2026 快照）：GLM-5.2 / 5.1 / 5 / 4.7 系列**默认开启 Thinking**（GLM-4.6 是默认混合 thinking）。
- **关闭思考官方写法**：`"thinking": {"type": "disabled"}`；开启 `{"type": "enabled"}`。裸 JSON 放 body 顶层；OpenAI SDK 走 `extra_body`。
- 附：交错式思考（GLM 4.5+）、保留式思考（`clear_thinking: false`）、轮级思考（GLM-4.7+，会话内每轮可独立开关）。base_url 示例 `https://api.z.ai/api/paas/v4/`。
- 关闭思考方案：`{"thinking": {"type": "disabled"}}`。GLM 不走 `reasoning_effort`（至少文档未提）。

#### 1.5 通义 Qwen / 千问（阿里云百炼 / DashScope）— `enable_thinking`

- 官方深度思考文档（2026 快照，`/model-studio/deep-thinking`）：
  - 混合思考模式模型：`enable_thinking` 布尔开关，`true`=先思考再回复，`false`=直接回复（**关闭思考**）。非 OpenAI 标准参数，Python SDK 走 `extra_body`，裸 JSON / Node 顶层。
  - 仅思考模式模型（`qwq-plus`/`qwq-32b`、`qwen3-*-thinking-*`、`deepseek-r1`、`kimi-k2-thinking`、MiniMax）：**无法关闭**。
  - 附加：`thinking_budget` 限制思考 token；Qwen3 开源混合模型支持提示词 `/no_think`、`/think` 指令动态开关。
  - 官方 FAQ 明说：混合思考模型（qwen3.6-plus、deepseek-v4-pro 等）设 `enable_thinking: false` 即可关闭；仅思考模型无法关闭。
- **百炼侧的分类非常有参考价值**（同一模型走百炼时的默认/可关性）：GLM（glm-5.1/5/4.7/4.6/4.5）混合思考默认开启；DeepSeek v4-pro/flash 混合思考默认开启、v3.x 混合思考默认关闭、deepseek-r1 仅思考；Kimi k2.6/k2.5 混合思考默认关闭、kimi-k2-thinking 仅思考。
- 关闭思考方案：`{"enable_thinking": false}`（仅对混合思考模型有效）。

#### 1.6 Kimi（Moonshot 月之暗面）— `reasoning_effort`

- 官方平台文档（2026 快照，`/docs/guide/chat/k2-thinking` 与快速开始）：最新 `kimi-k3` 用**请求顶层 `reasoning_effort`** 配置推理强度，支持 `"low" / "high" / "max"`，默认 `"max"`。
- `kimi-k2.6` / `kimi-k2.5` 支持"思考与非思考模式"（Moonshot 直连默认思考开启；百炼部署默认关闭）。`kimi-k2-thinking` 是仅思考变体。
- 关闭思考方案：换非 thinking 型号（`kimi-k2.6`/`kimi-k2`）+ 最低 `reasoning_effort: "low"`（K3 支持）。

#### 1.7 Anthropic（参考，本项目是 OpenAI 兼容接口，不适用）

- `thinking: {type: "enabled", budget_tokens: N}`（最低 1024）；关闭=不传 thinking 参数（Claude 3.7+/4.x Sonnet/Opus）。本项目走 `/chat/completions`，不适用；仅作为"thinking 对象形态"的参考。

---

### 2. "最安全跨提供商"参数分析

结论分两档：

**A 档（最安全 + 覆盖面最广）：`reasoning_effort: "low"`**
- 被 OpenAI（o1/o3/gpt-5）、Moonshot（kimi-k3/k2）、DeepSeek V4、Ark 原生识别/生效。
- 对不支持的模型/提供商：OpenAI 明确"仅推理模型支持、其余忽略"；DeepSeek V4 明确"不支持参数不报错、无效果"。
- 对 Zhipu / Qwen 这类不走 `reasoning_effort` 的：大概率作为未知字段被忽略（它们的 OpenAI 兼容网关宽容未知字段，与 DeepSeek 同族行为），不会 400。**置信度：高，但非绝对**。
- 值域注意：不要用 `medium`（DeepSeek/Moonshot 不认，可能被忽略或报错）；用 `low` 最通用；`none/minimal` 只有新版 OpenAI 推理模型认，作为"彻底关闭"的升级选项。

**B 档（针对中国厂商的"关闭"语义，命中率高但需按提供商分发）：**
- DeepSeek V4 / Zhipu GLM：`{"thinking": {"type": "disabled"}}`。
- Qwen/千问（混合思考模型）：`{"enable_thinking": false}`。
- Ark doubao / Moonshot kimi-k2-thinking / qwq / deepseek-r1：**仅思考模型无请求级关闭开关，只能换非 thinking 模型 ID**（模型 ID 层面解决）。

**不能同时乱发**：`thinking` 对象、`enable_thinking`、`reasoning_effort` 三者全发，多数兼容网关会忽略未知的，但存在（a）某些严格网关 400、（b）某厂商把 `thinking` 当保留字/半解析的风险。**方案上应"按提供商分发"，而不是一次全塞**。

---

### 3. 可行方案（结合项目约束，2-3 个）

#### 方案 A：配置里加"思考等级"下拉 + 按 baseUrl/模型 ID 自动映射参数（推荐）

- 在 `AssistantModelConfig` 增加字段（如 `reasoningEffort: 'auto'|'off'|'low'|'medium'|'high'`），UI 下拉。
- `HomeLazyLogService.structure()` 里根据该字段 + 模型 ID/baseUrl 自动拼装 body：
  - `off`（关闭思考）：按模型前缀分发——`deepseek-v4-*`→`thinking:{type:disabled}`；`glm-*`→`thinking:{type:disabled}`；`qwen3*`/`qwen-plus`→`enable_thinking:false`；`kimi-k3`→`reasoning_effort:"low"`（或换 ID）；`o1/o3/gpt-5`→`reasoning_effort:"none"`（新模型）或提示不支持；Ark（baseUrl 含 volces.com）→若模型带 thinking 关键字则提示换 ID，否则 `reasoning_effort:"low"`。
  - `low/medium/high`：统一发 `reasoning_effort`，DeepSeek/Moonshot 只认 low/high/max，medium 会退化为忽略（可接受）。
  - `auto`：保持现状不发。
- 优点：命中率高、逐提供商精确；缺点：维护一张模型前缀映射表。
- 附带修复：检测到推理模型（o1/o3/gpt-5、deepseek-v4 思考模式）时不发 `temperature`（避免 400 静默 fallback）。

#### 方案 B：懒人日志专属开关（最小改动）

- 只动 `HomeLazyLogService`，不扩展全局配置：加一个布尔 `disableThinking` 参数，`true` 时统一发 `reasoning_effort: "low"` + （针对 Zhipu/DeepSeek 再补 `thinking:{type:disabled}`）。
- 优点：改动小、不动 `AssistantModelConfig` 持久化结构、不动通用聊天；缺点：覆盖不全（Qwen 需要 `enable_thinking:false`），需要模型前缀判断才能做到"尽量生效"。
- 适合"需求 1 只要懒人日志能关思考"的最小验收。

#### 方案 C：只发最安全参数（纯 reasoning_effort，零映射）

- 开关打开时仅发 `reasoning_effort: "low"`，不做任何模型前缀分发。
- 优点：实现最简、跨提供商最不可能报错（A 档）；缺点：对 Zhipu GLM / Qwen / doubao thinking 无效（它们不认 `reasoning_effort`），"关闭思考"在这些模型上不生效，只能算"尽力而为"。
- 适合作为方案 A 的兜底降级（分发映射未命中时 fallback 到它）。

**推荐组合**：方案 A 为主 + 方案 C 兜底。未命中映射表时发 `reasoning_effort: "low"`（安全），命中时发对应厂商原生关闭参数。

---

## Caveats / Not Found

1. **Ark 细节未抓到正文**：`www.volcengine.com/docs/82379/*` 是客户端渲染 SPA，web.archive 也是 JS 壳。`reasoning_effort` 对 Ark 推理模型的支持、以及 `/api/coding/v3` 编程端点是否透传，**置信度中，建议实现后点"测试连接"实测**。Ark 的 doubao thinking 关闭只能靠换模型 ID，这条置信度高。
2. **"未知参数被忽略"不是绝对定律**：只有 DeepSeek V4 官方文档明确承诺忽略；OpenAI 对非推理模型忽略 `reasoning_effort` 有官方语义。其余（Zhipu/Qwen/Moonshot/Ark 及第三方网关）是"大概率忽略"，不排除个别严格网关 400。项目静默 fallback 行为会把这类 400 隐藏成降级结果，需要测试覆盖。
3. **DeepSeek 模型名 2026-07-24 废弃**：`deepseek-chat`/`deepseek-reasoner` 对应到 `deepseek-v4-flash` 的非思考/思考模式。若用户还在配旧名，建议在配置 UI/映射里给提示。
4. **仅思考模型无法关闭**：qwq-32b、deepseek-r1、kimi-k2-thinking、qwen3-*-thinking、MiniMax-M2.x 只能换模型 ID。
5. **`reasoning_effort: "none"/"minimal"` 兼容性**：仅新版 OpenAI 推理模型认；旧 o1/o3 与 DeepSeek/Moonshot 不认，不要默认发。
6. 没有实际调各厂商 API 做黑盒验证（无可用 API Key），以上均为官方文档/源码主源结论。
