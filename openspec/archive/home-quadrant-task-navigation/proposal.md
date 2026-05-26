# home-quadrant-task-navigation

## 需求澄清摘要
首页四象限任务点击定位时间轴+子任务切换+父任务展示

## 为什么
提升首页任务操作效率：四象限点击无反馈、子任务无法直接切换查看、缺少父任务上下文。

## 影响面
仅改 `lib/presentation/pages/home/home_page.dart`，只影响 `_HomeContent` 组件内部交互逻辑，不影响其他页面或数据层。

## 业务规范关系
- 命中的主 spec：无
- 关系判断：New Capability
- 推荐动作：MODIFIED

## 验收
- [x] 四象限点击任一项验证时间轴滚动和详情切换
- [x] 子任务点击验证切换
- [x] 有父任务时验证展示并可点击切换
