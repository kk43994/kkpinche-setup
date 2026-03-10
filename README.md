# KKpinche OpenClaw 配置脚本

一键配置 OpenClaw 使用 KKpinche API 多模型服务。

## 支持的模型

- **OpenAI/Codex**: GPT-5 系列（12个模型）
- **Claude**: Claude 4.6 系列（Opus/Sonnet/Haiku）
- **Google Gemini**: Gemini 2.5/3.0/3.1 系列（6个模型）

## 一键配置（全平台通用）

确保已安装 OpenClaw（`npm install -g openclaw`），然后运行：

```
npx kkpinche-setup
```

Windows、macOS、Linux 通用，无需额外安装。

### 使用步骤

1. 运行 `npx kkpinche-setup`
2. 根据提示选择要配置的模型类型（OpenAI/Claude/Gemini，支持多选）
3. 输入你的 API Key（以 `cr_` 开头，请联系微信 zkh120416890 获取）
4. 选择主模型和备用模型
5. 配置完成后可选择自动重启 OpenClaw

## 加入社区

Discord: https://discord.gg/JFYQJrqzEZ
