# android-build-daemon-failure

## 需求澄清摘要
排查移动端打包失败，先定位 Kotlin daemon 编译异常根因；范围限于构建配置/日志定位与必要最小修复；不做无关重构；以能稳定复现并解释/修复构建失败为验收

## 为什么
当前 Android 打包在 Kotlin daemon compilation 阶段失败，需定位根因并恢复构建。

## 影响面
未提供影响面；实施前需要用 context plan / impact 补齐。

## 业务规范关系
- 命中的主 spec：无
- 关系判断：New Capability
- 推荐动作：MODIFIED

## 验收
- [ ] 完成本次最小改动
- [ ] 回归测试最近一次运行通过
