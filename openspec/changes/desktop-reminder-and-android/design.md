# 桌面端提醒 + Android 打包设计

## 1. 提醒功能设计

### 1.1 Schedule 模型扩展
在现有 Schedule 实体上添加提醒相关字段：

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `remindBeforeMinutes` | int | 15 | 提前多少分钟提醒 |
| `reminderEnabled` | bool | true | 是否启用提醒 |
| `isRepeating` | bool | false | 是否重复提醒 |
| `repeatInterval` | int? | null | 重复间隔（分钟），如5分钟 |
| `reminderType` | String | 'once' | 'once' 或 'repeat' |

### 1.2 通知升级方案
- 添加 `flutter_local_notifications` 依赖，在各平台发 OS 级通知
- Windows: 使用 flutter_local_notifications（测试是否可行）/ 备选：直接使用系统Toast
- Android: 标准 flutter_local_notifications + 通知渠道
- 保留现有 Timer 机制作为内存备份

### 1.3 提醒窗口UI
在 create_schedule_dialog 中新增：
- 开关：是否启用提醒（默认开启）
- 下拉选择：提前时间（5/10/15/30分钟，1/2小时，1天）
- 开关：一次性/重复提醒
- 如果是重复：选择重复间隔（每5/10/15/30分钟）

## 2. Android 打包

### 2.1 构建准备
- 配置 Android 签名（debug现有，release需要生成keystore）
- 在 android/app/build.gradle.kts 中配置 applicationId 等参数
- 确保通知权限在 AndroidManifest.xml 中声明

### 2.2 云数据同步
- 已有 Supabase 作为后端，Schedule 数据已经在云端
- 扩展 schedules 表添加 reminder 字段
- 两端共用同一套 Supabase 数据，天然同步

## 3. 架构影响
- 改动的文件：~6个核心文件 + 构建配置
- 不影响现有业务逻辑（提醒是附加功能）
- 不影响Task/Checklist等其他模块
- 影响范围：低到中

## 4. 依赖变更
- 新增：flutter_local_notifications ^18.0.0
- 新增：android_alarm_manager（备选，用于定时精确触发）
