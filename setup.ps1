# KKpinche API 多模型配置向导 - Windows 启动器
#
# 一键运行（复制粘贴到 PowerShell）:
#   irm https://raw.githubusercontent.com/kk43994/kkpinche-setup/master/setup.ps1 | iex
#
# 此脚本会自动检测 Bash 环境并启动配置向导

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "  KKpinche OpenClaw 配置向导 - Windows 启动器" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

# 下载 bash 脚本
$scriptUrl = "https://raw.githubusercontent.com/kk43994/kkpinche-setup/master/setup.sh"
$tmpScript = "$env:TEMP\kkpinche-setup.sh"

Write-Host "▶ " -ForegroundColor Blue -NoNewline
Write-Host "正在下载配置脚本..."

try {
    Invoke-WebRequest -Uri $scriptUrl -OutFile $tmpScript -UseBasicParsing
    Write-Host "✓ " -ForegroundColor Green -NoNewline
    Write-Host "脚本下载完成"
} catch {
    Write-Host "✗ " -ForegroundColor Red -NoNewline
    Write-Host "下载失败: $_"
    exit 1
}

# 查找 bash 环境
$bashPaths = @(
    # Git Bash
    "C:\Program Files\Git\bin\bash.exe",
    "C:\Program Files (x86)\Git\bin\bash.exe",
    # WSL
    "$env:SystemRoot\System32\bash.exe",
    # MSYS2
    "C:\msys64\usr\bin\bash.exe"
)

$bashExe = $null

# 优先检查 PATH 中的 bash
$bashInPath = Get-Command bash -ErrorAction SilentlyContinue
if ($bashInPath) {
    $bashExe = $bashInPath.Source
}

# 如果 PATH 中没有，逐个检查已知路径
if (-not $bashExe) {
    foreach ($path in $bashPaths) {
        if (Test-Path $path) {
            $bashExe = $path
            break
        }
    }
}

if (-not $bashExe) {
    Write-Host ""
    Write-Host "✗ " -ForegroundColor Red -NoNewline
    Write-Host "未找到 Bash 环境！"
    Write-Host ""
    Write-Host "请安装以下任一环境：" -ForegroundColor Yellow
    Write-Host "  1) Git for Windows (推荐): https://git-scm.com/download/win"
    Write-Host "  2) WSL: wsl --install"
    Write-Host ""
    exit 1
}

Write-Host "✓ " -ForegroundColor Green -NoNewline
Write-Host "找到 Bash: $bashExe"
Write-Host ""
Write-Host "▶ " -ForegroundColor Blue -NoNewline
Write-Host "正在启动配置向导..."
Write-Host ""

# 将 Windows 路径转换为 Unix 路径（如果是 Git Bash）
$unixPath = $tmpScript -replace '\\', '/' -replace '^(\w):', '/$1'
$unixPath = $unixPath.Substring(0,1) + $unixPath.Substring(1,1).ToLower() + $unixPath.Substring(2)

# 启动 bash 脚本
& $bashExe -l -c "bash '$unixPath'"

# 清理临时文件
Remove-Item $tmpScript -Force -ErrorAction SilentlyContinue
