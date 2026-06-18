# calendar layout height optimization

## Goal

压缩日历页顶部头部区域的垂直占高，并提高 Windows 桌面端默认窗口高度，让周视图时间网格能一次显示更多内容，改善当前头部过高、主体区过少的问题。

## Requirements

* 缩小日历页顶部头部区域的视觉高度，优先调整 AppBar、头部工具控件、周标题行和周日期条的上下留白。
* 保持现有信息架构与操作入口不变，不删除项目筛选、节假日国家切换、周/月切换、天数下拉、缩放按钮和今日按钮。
* 提高 Windows 默认启动窗口高度，让周视图下方时间轴展示更多任务块。
* 修改后桌面端日历仍保持清晰，不出现按钮换行、遮挡或点击热区过小。

## Acceptance Criteria

* [ ] 同样窗口宽度下，顶部区域明显更紧凑。
* [ ] 周视图主体区可见高度增加，能多显示一段可感知的时间内容。
* [ ] 顶部所有控制按钮仍保持单行可用。
* [ ] Windows 启动后的默认窗口高度高于当前版本。

## Out of Scope

* 不修改任务数据逻辑、拖拽逻辑、节假日逻辑。
* 不重构日历页整体交互结构。
* 不处理与本次高度优化无关的视觉风格调整。

## Technical Notes

* Main UI file: `lib/presentation/pages/calendar/calendar_page.dart`
* Windows startup window size: `windows/runner/main.cpp`
* Repo uses Flutter desktop/mobile shared calendar UI.
