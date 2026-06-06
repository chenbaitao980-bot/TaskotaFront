# Taskora - 通知测试脚本
# 运行此脚本测试 Windows Toast 通知是否正常弹出
# 出现 "安全性警告" 时选择 "仍要运行" 即可

Add-Type -AssemblyName System.Windows.Forms

[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
$template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
$textNodes = $template.GetElementsByTagName("text")
$textNodes.Item(0).AppendChild($template.CreateTextNode("Taskora")) > $null
$textNodes.Item(1).AppendChild($template.CreateTextNode("这是通知测试，如果看到此消息说明通知功能正常")) > $null
$toast = [Windows.UI.Notifications.ToastNotification]::new($template)
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("Taskora").Show($toast)

Write-Host "通知已发送，请查看屏幕右下角"
