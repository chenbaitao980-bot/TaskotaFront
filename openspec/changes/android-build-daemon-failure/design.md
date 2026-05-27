# 设计：android-build-daemon-failure

## 需求澄清依据
排查移动端打包失败，先定位 Kotlin daemon 编译异常根因；范围限于构建配置/日志定位与必要最小修复；不做无关重构；以能稳定复现并解释/修复构建失败为验收

## 方案
执行本次最小改动，不扩大范围。

## 回归测试
- 用例文件：`regression-tests/cases/android-build-daemon-failure.md`
- 运行记录：`regression-tests/runs/android-build-daemon-failure.json`
