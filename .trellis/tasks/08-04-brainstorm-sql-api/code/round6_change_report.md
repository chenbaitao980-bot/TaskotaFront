# 第六轮变更报告：三窗口症状（退出慢 / 便签消失 / 启动重影）编码落地

> 状态：**已编码落地 · 待实机验证**（本轮触及 L4 窗口/原生/时序层，未产出实机证据 → 不得以完成态收尾，见「六、待办」阻塞项）。
> 依据：`round6_diagnosis.md`（三根因 + Q1-Q4）+ `round6_change_plan.md`（F1-F6 文件级方案）+ 用户确认（R1+R2+R3 全做，R3-1 改正常窗口大小，R2-4 实施）。

## 一、变更摘要
- **任务**: 症状1 任务栏"退出"非实时 / 症状2 关主窗→点便签→再关→便签消失 / 症状3 启动一刹那重影
- **文件**: 6 个（Dart 4 + C++ runner 2），**改动 +96 / -11 行**（最小 diff）
- **根因集**: RC-1 退出竞态死代码（`await destroy(); exit(0)`，destroy Future 永不完成）；RC-2 便签窗"创建→首帧"无保护窗口期 + `_isTransitioning` 竞态早退 + 复用 `note.show()` 静默失败；RC-3 首帧 `SW_MAXIMIZE` + 无背景刷缩放残影 + restoreFullWindow z 序连爆
- **索引状态**: ✅ 索引可用（codegraph 运行中快照，改动前已核实）

### R1 根因修正（2026-08-04 实机复测，进程存活实证）
用户实测第一版 R1（`destroy().timeout(1s)` + `exit(0)`）：**窗口消失但进程仍存活、托盘图标残留**。任务管理器确认 Taskora.exe 进程仍在 → `exit(0)` 未被执行的根因**比原诊断更深一层**：
- **原诊断**：destroy 的 Future 永不完成 → exit(0) 死代码
- **实测修正**：`windowManager.destroy()` → PostQuitMessage → 主循环退出 → main() 返回 → **CRT 引擎 teardown 在便签第二引擎线程上挂起** → Dart 事件循环已死 → 后续 `exit(0)` 永不执行。窗口被 teardown 销毁（"窗口消失"），但进程被 teardown 卡住（"进程存活 + 托盘图标残留"）。
- **修复**：退出路径**不再 await destroy()**，直接 `exit(0)` 强制 ExitProcess 绕过 teardown 挂起；drift WAL 已落盘数据安全。同步写 `logs/task_exit.log` 打点（exit0 called）作实机证据——若下次仍存活且打点存在 ⇒ exit(0) 未终止，需走原生 ExitProcess 通道。

## 二、Spec 合规
| 规则 | 状态 |
|------|------|
| 无 trellis spec 目录 | —（跳过规范检查，按项目既有代码风格与注释规范执行） |
| 最小 diff / 不 scope creep | ✅ 仅改 round6_change_plan 列明的 6 文件 |
| 注释说"为什么" | ✅ 每处修复点均标注根因（如 R1 竞态、R2-1 无保护窗口期、R3-1 DWM 残影） |

## 三、质量门禁
| 检查项 | 结果 |
|--------|------|
| flutter analyze（4 个 Dart 改动文件） | ✅ 0 问题（13.3s） |
| 相关测试 floating_tab_controller_test.dart | ✅ 全部通过（R2/R3 控制器改动回归） |
| 相关测试 p0_perf_contract_test.dart | ✅ 全部通过 |
| 相关测试 single_instance_test.dart | ⚠️ 2 失败 = **环境冲突**（正在运行的 Taskora.exe PID 9996 占住单实例固定端口 49527，测试自身注释声明"测试环境无真实应用"）；**本改动未触碰 single_instance.dart**，非回归 |
| flutter build windows（含 C++ runner F5/F6） | ✅ 构建成功（52s，`Taskora.exe` 重新生成）。注：C++ 注释改 ASCII 规避 C4819（MSVC 代码页 936 无法表示中文），Dart 中文注释不受影响 |

## 四、反模式检查
| 反模式 | 检查结果 |
|--------|---------|
| 散落定义 | ✅ `_closeRequestId`/`_lastSummary` 单点定义，唯一读写点已核对 |
| 链路断裂 | ✅ restore 代际、note 自隐、hideToTray 三处交互时序复核闭环 |
| 静默失败 | ✅ 便签 show 失败日志含异常 code（`failed to find target window` 可定位 H1） |
| 层级归因错 | ✅ 三症状均归因为 L4 窗口/原生/时序层，修复也在该层（非 Flutter 绘制层打补丁） |
| 完成态冒充 | ✅ 本报告用「已编码落地 · 待实机验证」，无"已修复/已完成"措辞 |

## 五、行为验证
| 契约 | 输入 | 预期 | 层级 | 结果 |
|------|------|------|------|------|
| A (R1) | 托盘点"退出" | destroy 有 1s 上限 + exit(0)，进程 ≤1.5s 退出 | L4 实机 | ⚠️ 待实测 |
| B (R2-1) | note 任意阶段收 WM_CLOSE | setPreventClose 提前生效 + onWindowClose 兜底只隐藏不销毁引擎 | L4 实机 | ⚠️ 待实测 |
| C (R2-2) | `_isTransitioning` 时 showMain | 主窗照常 show + 清 `_dismissedUntilRestore`（代际 `_closeRequestId++` 打断 hideToTray） | L2 推理 + L4 | ⚠️ 结构已落地，实机验证竞态复现 |
| D (R3-2) | 窗口已聚焦时 restoreFullWindow | `isFocused()` 为 true → 跳过 TOPMOST 双切，消除 z 序连爆 | L2 结构 + L4 | ⚠️ 待实测 |
| E (R3-3) | 第二实例启动 | C++ 单实例 `SW_SHOW` 非最大化唤醒首实例 | L4 实机 | ⚠️ 待实测 |

**语义验证说明**：本轮 4 个 Dart 文件 analyze 通过（类型/签名/API 全绿），`floating_tab_controller_test` + `p0_perf_contract_test` 通过；契约 A/B/C/D/E 均落在 L4 窗口/时序/原生层，无头环境不可执行 → 记入阻塞待办（强制规则 #20）。

## 六、待办（阻塞）
- [ ] **⚠️ L4 实机验证（阻塞，未清除不得宣称完成）**：
  1. **退出**：重建后托盘点"退出"，确认进程 ≤1.5s 退出；读 flog「退出: 用户点击」→「退出: 进程 exit(0)」时间差；并确认用户点的是**托盘"退出"**还是**任务栏"关闭"**（后者=隐藏到托盘，H4 预期行为）
  2. **便签消失**：复现关主窗→点便签→再关主窗，读 `Documents/logs/task_*.log`：应见「便签窗 show 成功 windowId=...」；若仍见「show 失败 code=failed to find target window」⇒ H1 未根治，需回滚排查；若「无候选，复用上次摘要=false」⇒ R2-4 未兜住
  3. **重影**：录屏慢放"打开一刹那"，确认无 A（最大化缩放残影）/B（z 序闪烁）/C（二实例跳变）
- [ ] **环境冲突登记**：`single_instance_test.dart` 在 Taskora.exe 运行时必然失败（占端口 49527），属测试环境假设被违反，非本改动回归；后续可在关闭应用后单独重跑确认
- [ ] **R2-4 副作用观察**：完成任务后若仍弹旧便签摘要，实机确认 H3 不成立后回滚 R2-4（保留 R2-1/2/3）

## 七、实机验证契约（交付用户逐条执行）
1. 重建 → 启动 → 托盘图标右键 → 点"退出" → 计时确认 ≤1.5s 退出（对比改前"等很久"）
2. 有便签时：关闭主窗 → 点便签 → 再关闭主窗 → **便签应再次显示**（对比改前消失）
3. 启动瞬间录屏慢放 → 无重影/闪烁（对比改前"一刹那重影"）
4. 确认启动窗口为正常尺寸 1280×860 非全屏（R3-1 产品影响）
