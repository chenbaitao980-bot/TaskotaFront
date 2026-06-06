# Reasonix 全局记忆预执行钩子安装脚本
# 每次 Codex 新线程启动时，将此钩子注入 AGENTS.md 执行

param(
    [switch]$Install,
    [switch]$Status,
    [switch]$Uninstall
)

$PluginPath = "E:\claude\project2\smart_assistant\.codex-plugin"
$SkillPath = Join-Path $PluginPath "skills\pre-execution-hook\SKILL.md"
$AgentFile = "E:\claude\project2\smart_assistant\.agents\AGENTS.md"

function Show-Status {
    if (Test-Path $SkillPath) {
        Write-Host "✅ 钩子技能文件存在: $SkillPath"
        $content = Get-Content $SkillPath -Raw
        $lineCount = ($content -split "`n").Count
        Write-Host "   共 $lineCount 行, $(($content -split "`n" | Where-Object { $_ -match '^### ' -or $_ -match '^## ' }).Count) 个章节"
    } else {
        Write-Host "❌ 钩子技能文件不存在"
    }
    if (Test-Path $PluginPath\.codex-plugin\plugin.json) {
        Write-Host "✅ 插件清单存在"
    } else {
        Write-Host "❌ 插件清单不存在"
    }
}

switch ($true) {
    $Install {
        if (-not (Test-Path $AgentFile)) {
            New-Item -ItemType File -Path $AgentFile -Force | Out-Null
        }
        Add-Content -Path $AgentFile -Value "`n# Pre-Execution Hook (auto-loaded from .reasonix)`n" -NoNewline
        Write-Host "✅ 钩子已安装"
    }
    $Uninstall {
        Write-Host "ℹ 卸载需要手动删除插件目录"
    }
    default {
        Show-Status
    }
}
