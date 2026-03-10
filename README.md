# KKpinche OpenClaw 配置脚本

一键配置 OpenClaw 使用 KKpinche API 多模型服务。

## 支持的模型

- **OpenAI/Codex**: GPT-5 系列（12个模型）
- **Claude**: Claude 4.6 系列（Opus/Sonnet/Haiku）
- **Google Gemini**: Gemini 2.5/3.0/3.1 系列（6个模型）

## 一键安装

### Linux / macOS

复制以下命令到终端执行：

```bash
curl -fsSL https://raw.githubusercontent.com/kk43994/kkpinche-setup/master/setup.sh -o /tmp/claw.sh && bash /tmp/claw.sh
```

或使用 wget：

```bash
wget -qO /tmp/claw.sh https://raw.githubusercontent.com/kk43994/kkpinche-setup/master/setup.sh && bash /tmp/claw.sh
```

### Windows

在 **PowerShell** 中执行：

```powershell
irm https://raw.githubusercontent.com/kk43994/kkpinche-setup/master/setup.ps1 | iex
```

> 注意：需要先安装 [Git for Windows](https://git-scm.com/download/win) 或 WSL

### 安装说明

1. 运行上述命令后，脚本会自动检测 OpenClaw 安装
2. 根据提示选择要配置的模型类型（OpenAI/Claude/Gemini）
3. 输入你的 API Key（以 `cr_` 开头）
4. 选择主模型和备用模型
5. 配置完成后可选择自动重启 OpenClaw

## 加入社区

Discord: https://discord.gg/JFYQJrqzEZ
