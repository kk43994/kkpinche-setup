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

# 方式1：优先使用 WSL
$hasWSL = Get-Command wsl.exe -ErrorAction SilentlyContinue
if ($hasWSL) {
    # 用 wsl wslpath 转换路径
    $unixPath = & wsl.exe wslpath -a "$tmpScript" 2>$null
    if ($unixPath) {
        $unixPath = $unixPath.Trim()
        Write-Host "✓ " -ForegroundColor Green -NoNewline
        Write-Host "使用 WSL 运行"
        Write-Host ""
        Write-Host "▶ " -ForegroundColor Blue -NoNewline
        Write-Host "正在启动配置向导..."
        Write-Host ""
        & wsl.exe bash "$unixPath"
        Remove-Item $tmpScript -Force -ErrorAction SilentlyContinue
        exit $LASTEXITCODE
    }
}

# 方式2：使用 Git Bash
$gitBashPaths = @(
    "C:\Program Files\Git\bin\bash.exe",
    "C:\Program Files (x86)\Git\bin\bash.exe"
)

$gitBash = $null
foreach ($path in $gitBashPaths) {
    if (Test-Path $path) {
        $gitBash = $path
        break
    }
}

# 也从 PATH 中找 Git Bash（排除 system32 的 WSL bash）
if (-not $gitBash) {
    $allBash = Get-Command bash -All -ErrorAction SilentlyContinue
    foreach ($b in $allBash) {
        if ($b.Source -notlike "*System32*" -and $b.Source -notlike "*system32*") {
            $gitBash = $b.Source
            break
        }
    }
}

if ($gitBash) {
    # Git Bash 路径：C:\Users\... -> /c/Users/...
    $unixPath = $tmpScript -replace '\\', '/'
    if ($unixPath -match '^(\w):(.*)') {
        $unixPath = '/' + $Matches[1].ToLower() + $Matches[2]
    }
    Write-Host "✓ " -ForegroundColor Green -NoNewline
    Write-Host "使用 Git Bash: $gitBash"
    Write-Host ""
    Write-Host "▶ " -ForegroundColor Blue -NoNewline
    Write-Host "正在启动配置向导..."
    Write-Host ""
    & $gitBash -l -c "bash '$unixPath'"
    Remove-Item $tmpScript -Force -ErrorAction SilentlyContinue
    exit $LASTEXITCODE
}

# 都没找到
Write-Host ""
Write-Host "✗ " -ForegroundColor Red -NoNewline
Write-Host "未找到可用的 Bash 环境！"
Write-Host ""
Write-Host "请安装以下任一环境：" -ForegroundColor Yellow
Write-Host "  1) Git for Windows (推荐): https://git-scm.com/download/win"
Write-Host "  2) WSL: wsl --install"
Write-Host ""
Remove-Item $tmpScript -Force -ErrorAction SilentlyContinue
exit 1
