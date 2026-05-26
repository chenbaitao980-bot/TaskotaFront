@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set DB_PATH=%USERPROFILE%\Documents\smart_assistant.db
set DB_JOURNAL=%DB_PATH%-journal

echo ╔════════════════════════════════╗
echo ║ SmartAssistant 数据清空工具  ║
echo ╚════════════════════════════════╝
echo.

if not exist "%DB_PATH%" (
    echo [✓] 数据库文件不存在，无需清空。
    goto :end
)

echo [→] 找到数据库: %DB_PATH%
echo.

choice /c YN /m "确认清空所有任务和项目数据？"

if errorlevel 2 goto :cancel
if errorlevel 1 goto :clear

:cancel
echo [×] 已取消。
goto :end

:clear
del /f /q "%DB_PATH%" >nul 2>&1
del /f /q "%DB_JOURNAL%" >nul 2>&1

if exist "%DB_PATH%" (
    echo [×] 删除失败，请关闭 SmartAssistant 后重试。
    goto :end
)

echo [✓] 数据已清空。
echo [→] 下次启动 App 将自动创建新数据库（含"未分类"项目）。
echo.

:end
pause
