# Regression Cases: timeline-sync-fixes

## Test Environment
- App: SmartAssistant (Flutter)
- Test type: static check plus manual UI verification
- Last command: `flutter analyze`

## Cases

### TC1: 时间轴左右滚动
1. 打开时间轴视图
2. 点击左右滚动按钮
3. Expected: 时间轴按需左右滚动，滚动流畅无卡顿

### TC2: 任务创建后时间轴同步
1. 在任务页面创建一个新任务（设置时间）
2. 切换到时间轴视图
3. Expected: 时间轴自动定位到新任务所在的时间节点

### TC3: 任务详情显示项目标签
1. 打开一个有项目归属的任务
2. Expected: 任务详情页顶部显示所属项目名称/标签

### TC4: 检查项缓存失效后自动加载
1. 打开一个包含检查项的任务
2. 使缓存失效（如切换页面再回来）
3. Expected: 检查项自动重新加载

### TC5: 选中任务展示子任务树
1. 打开一个有子任务的任务
2. Expected: 子任务树展开显示

## Pass Criteria
- All manual cases pass.
- flutter analyze exits with code 0.
