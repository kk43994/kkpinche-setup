#!/bin/bash
# KKpinche API 多模型配置向导 for Clawdbot/Moltbot/OpenClaw
#
# 一键运行（复制粘贴到终端）:
#   curl -fsSL https://raw.githubusercontent.com/kk43994/kkpinche-setup/master/setup.sh -o /tmp/claw.sh && bash /tmp/claw.sh
#
# 使用 wget（容器/Linux 备选）:
#   wget -qO /tmp/claw.sh https://raw.githubusercontent.com/kk43994/kkpinche-setup/master/setup.sh && bash /tmp/claw.sh

# 如果是 macOS 且用 bash 3.x 运行，自动切换到 zsh
if [ "$(uname)" = "Darwin" ] && [ -n "$BASH_VERSION" ]; then
    bash_major="${BASH_VERSION%%.*}"
    if [ "$bash_major" -lt 4 ] && [ -x /bin/zsh ] && [ -z "$CLAWDBOT_SETUP_RUNNING" ]; then
        export CLAWDBOT_SETUP_RUNNING=1
        exec /bin/zsh "$0" "$@"
    fi
fi

# 颜色定义
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
CYAN=$'\033[0;36m'
NC=$'\033[0m'
BOLD=$'\033[1m'

# 打印带颜色的消息
print_header() {
    echo ""
    echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "${CYAN}  $1${NC}"
    echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_step() {
    echo ""
    echo "${BLUE}▶${NC} ${BOLD}$1${NC}"
}

print_success() {
    echo "${GREEN}✓${NC} $1"
}

print_error() {
    echo "${RED}✗${NC} $1"
}

print_warning() {
    echo "${YELLOW}!${NC} $1"
}

# 检查 openclaw/clawdbot 是否安装
CLI_BIN=""
check_clawdbot() {
    if command -v openclaw > /dev/null 2>&1; then
        CLI_BIN="openclaw"
    elif command -v clawdbot > /dev/null 2>&1; then
        CLI_BIN="clawdbot"
    else
        print_error "openclaw 未安装或不在 PATH 中"
        echo ""
        echo "请先安装 openclaw:"
        echo "  npm install -g openclaw"
        echo ""
        exit 1
    fi
}

# 重启 openclaw/clawdbot
restart_clawdbot() {
    print_step "正在重启 $CLI_BIN..."

    # 检测当前运行模式
    RUNNING_MODE=""
    if pgrep -f "$CLI_BIN gateway" > /dev/null 2>&1; then
        RUNNING_MODE="gateway"
    elif pgrep -f "$CLI_BIN agent" > /dev/null 2>&1; then
        RUNNING_MODE="agent"
    fi

    if [ -z "$RUNNING_MODE" ]; then
        printf "  %s未检测到正在运行的 $CLI_BIN 进程%s\n" "$YELLOW" "$NC"
        echo ""
        echo "请手动启动 $CLI_BIN："
        printf "  %s$CLI_BIN agent%s      - 启动 Agent 模式\n" "$CYAN" "$NC"
        printf "  %s$CLI_BIN gateway%s   - 启动 Gateway 模式（支持 Telegram/Discord）\n" "$CYAN" "$NC"
        echo ""
        return
    fi

    # 停止现有进程
    printf "  停止 $CLI_BIN %s... " "$RUNNING_MODE"
    pkill -f "$CLI_BIN $RUNNING_MODE" 2>/dev/null || true
    sleep 2
    printf "%s✓%s\n" "$GREEN" "$NC"

    # 重新启动
    printf "  启动 $CLI_BIN %s... " "$RUNNING_MODE"
    nohup $CLI_BIN "$RUNNING_MODE" > /tmp/$CLI_BIN-restart.log 2>&1 &
    sleep 3

    # 检查是否启动成功
    if pgrep -f "$CLI_BIN $RUNNING_MODE" > /dev/null 2>&1; then
        printf "%s✓%s\n" "$GREEN" "$NC"
        echo ""
        printf "%s$CLI_BIN %s 已重启成功！%s\n" "$GREEN" "$RUNNING_MODE" "$NC"
    else
        printf "%s✗%s\n" "$RED" "$NC"
        echo ""
        print_warning "自动启动失败，请手动启动："
        printf "  %s$CLI_BIN %s%s\n" "$CYAN" "$RUNNING_MODE" "$NC"
    fi
    echo ""
}

# 选择模型类型
ENABLE_OPENAI=0
ENABLE_CLAUDE=0
ENABLE_GEMINI=0

select_model_types() {
    print_step "选择要配置的模型类型（支持多选）"
    echo ""
    echo "  1) OpenAI/Codex (GPT-5 系列，12个模型)"
    echo "  2) Claude (Claude 4.6 系列，2-3个模型)"
    echo "  3) Google Gemini (Gemini 2.5/3.0/3.1 系列，6个模型)"
    echo ""
    echo "${YELLOW}提示：可以选择多个，直接输入数字组合（如: 12 或 123 或 13）${NC}"
    echo ""

    while true; do
        echo -n "请选择 [1 或 2 或 3，可多选，默认 2]: "
        read TYPES_INPUT
        TYPES_INPUT=${TYPES_INPUT:-2}

        # 移除所有空格
        TYPES_INPUT=$(echo "$TYPES_INPUT" | tr -d ' ')

        # 验证输入 - 按字符逐个检查
        VALID=1
        CHECKED=""
        for ((i=0; i<${#TYPES_INPUT}; i++)); do
            TYPE="${TYPES_INPUT:$i:1}"
            case "$TYPE" in
                1|2|3)
                    # 去重
                    if [[ ! "$CHECKED" =~ $TYPE ]]; then
                        CHECKED="$CHECKED$TYPE"
                    fi
                    ;;
                *)
                    print_error "无效的字符: $TYPE，只能输入 1、2、3"
                    VALID=0
                    break
                    ;;
            esac
        done

        if [ "$VALID" = "0" ]; then
            continue
        fi

        # 设置标志 - 使用去重后的字符
        for ((i=0; i<${#CHECKED}; i++)); do
            TYPE="${CHECKED:$i:1}"
            case "$TYPE" in
                1) ENABLE_OPENAI=1 ;;
                2) ENABLE_CLAUDE=1 ;;
                3) ENABLE_GEMINI=1 ;;
            esac
        done

        break
    done

    # 显示选择结果
    echo ""
    echo "已选择的模型类型："
    [ "$ENABLE_OPENAI" = "1" ] && printf "  %s•%s OpenAI/Codex (GPT-5 系列)\n" "$GREEN" "$NC"
    [ "$ENABLE_CLAUDE" = "1" ] && printf "  %s•%s Claude (Claude 4.6 系列)\n" "$GREEN" "$NC"
    [ "$ENABLE_GEMINI" = "1" ] && printf "  %s•%s Google Gemini (Gemini 2.5/3.0/3.1 系列)\n" "$GREEN" "$NC"
}

# 生成 OpenAI 配置
OPENAI_MODELS_JSON=""
OPENAI_MODEL_COUNT=12

generate_openai_config() {
    OPENAI_MODELS_JSON='[
  {"id":"gpt-5","name":"GPT-5"},
  {"id":"gpt-5-codex","name":"GPT-5 Codex"},
  {"id":"gpt-5-codex-mini","name":"GPT-5 Codex Mini","maxTokens":8192},
  {"id":"gpt-5.1","name":"GPT-5.1"},
  {"id":"gpt-5.1-codex","name":"GPT-5.1 Codex"},
  {"id":"gpt-5.1-codex-mini","name":"GPT-5.1 Codex Mini","maxTokens":8192},
  {"id":"gpt-5.1-codex-max","name":"GPT-5.1 Codex Max","maxTokens":32768},
  {"id":"gpt-5.2","name":"GPT-5.2"},
  {"id":"gpt-5.2-codex","name":"GPT-5.2 Codex"},
  {"id":"gpt-5.3-codex","name":"GPT-5.3 Codex"},
  {"id":"gpt-5.3-codex-spark","name":"GPT-5.3 Codex Spark","input":["text"]},
  {"id":"gpt-5.4","name":"GPT-5.4"}
]'
}

# 生成 Gemini 配置
GEMINI_MODELS_JSON=""
GEMINI_MODEL_COUNT=6

generate_gemini_config() {
    GEMINI_MODELS_JSON='[
  {"id":"gemini-3.1-pro-preview","name":"Gemini 3.1 Pro Preview","reasoning":true,"input":["text","image"],"cost":{"input":0,"output":0,"cacheRead":0,"cacheWrite":0},"contextWindow":1048576,"maxTokens":8192},
  {"id":"gemini-3-pro-preview","name":"Gemini 3 Pro Preview","reasoning":true,"input":["text","image"],"cost":{"input":0,"output":0,"cacheRead":0,"cacheWrite":0},"contextWindow":1048576,"maxTokens":8192},
  {"id":"gemini-3-flash-preview","name":"Gemini 3 Flash Preview","reasoning":true,"input":["text","image"],"cost":{"input":0,"output":0,"cacheRead":0,"cacheWrite":0},"contextWindow":1048576,"maxTokens":8192},
  {"id":"gemini-2.5-pro","name":"Gemini 2.5 Pro","reasoning":true,"input":["text","image"],"cost":{"input":0,"output":0,"cacheRead":0,"cacheWrite":0},"contextWindow":1048576,"maxTokens":8192},
  {"id":"gemini-2.5-flash","name":"Gemini 2.5 Flash","reasoning":true,"input":["text","image"],"cost":{"input":0,"output":0,"cacheRead":0,"cacheWrite":0},"contextWindow":1048576,"maxTokens":8192},
  {"id":"gemini-2.5-flash-lite","name":"Gemini 2.5 Flash Lite","reasoning":true,"input":["text","image"],"cost":{"input":0,"output":0,"cacheRead":0,"cacheWrite":0},"contextWindow":1048576,"maxTokens":8192}
]'
}

# 生成 Claude 配置（保持原有逻辑）
CLAUDE_MODELS_JSON=""
CLAUDE_PRIMARY_MODEL=""
CLAUDE_FALLBACK_MODELS=""
CLAUDE_MODEL_COUNT=0

generate_claude_config() {
    # 检查是否是多模型配置（同时选择了其他类型）
    MULTI_PROVIDER=0
    if [ "$ENABLE_OPENAI" = "1" ] || [ "$ENABLE_GEMINI" = "1" ]; then
        MULTI_PROVIDER=1
    fi

    # 如果是多模型配置，自动使用全模型套餐
    if [ "$MULTI_PROVIDER" = "1" ]; then
        print_step "配置 Claude 模型"
        echo ""
        echo "检测到多模型配置，自动使用 Claude 全模型套餐 (Opus 4.6 + Sonnet 4.6 + Haiku 4.5)"
        PACKAGE_TYPE=1
        MODEL_CHOICE=4
    else
        # 单独选择 Claude 时，才询问套餐类型
        print_step "选择 Claude 套餐类型"
        echo ""
        echo "  1) Claude 全模型套餐 (Opus 4.6 + Sonnet 4.6 + Haiku 4.5)"
        echo "  2) Sonnet Only 套餐 (Sonnet 4.6 + Haiku 4.5)"
        echo ""

        while true; do
            echo -n "请选择 [1-2，默认 1]: "
            read PACKAGE_TYPE
            PACKAGE_TYPE=${PACKAGE_TYPE:-1}

            case "$PACKAGE_TYPE" in
                1|2) break ;;
                *) print_error "请输入 1 或 2" ;;
            esac
        done
    fi

    # 根据套餐类型显示不同的模型选择（多模型配置时跳过）
    if [ "$MULTI_PROVIDER" = "0" ]; then
        if [ "$PACKAGE_TYPE" = "1" ]; then
        # 全模型套餐
        print_step "选择要配置的 Claude 模型"
        echo ""
        echo "  1) Claude Opus 4.6 (最强，推荐)"
        echo "  2) Claude Sonnet 4.6 (新一代平衡)"
        echo "  3) Claude Haiku 4.5 (快速)"
        echo "  4) 全部配置 (推荐)"
        echo ""

        while true; do
            echo -n "请选择 [1-4，默认 4]: "
            read MODEL_CHOICE
            MODEL_CHOICE=${MODEL_CHOICE:-4}

            case "$MODEL_CHOICE" in
                1|2|3|4) break ;;
                *) print_error "请输入 1-4" ;;
            esac
        done
    else
        # Sonnet Only 套餐
        print_step "选择要配置的 Claude 模型"
        echo ""
        echo "  1) Claude Sonnet 4.6 (新一代平衡，推荐)"
        echo "  2) Claude Haiku 4.5 (快速)"
        echo "  3) 全部配置 (推荐)"
        echo ""

        while true; do
            echo -n "请选择 [1-3，默认 3]: "
            read MODEL_CHOICE
            MODEL_CHOICE=${MODEL_CHOICE:-3}

            case "$MODEL_CHOICE" in
                1|2|3) break ;;
                *) print_error "请输入 1-3" ;;
            esac
        done
        # 映射 Sonnet Only 选项到统一的 MODEL_CHOICE
        # 1 -> 2 (Sonnet 4.6), 2 -> 3 (Haiku), 3 -> 5 (Sonnet Only all)
        case "$MODEL_CHOICE" in
            1) MODEL_CHOICE=2 ;;  # Sonnet 4.6
            2) MODEL_CHOICE=3 ;;  # Haiku
            3) MODEL_CHOICE=5 ;;  # Sonnet 4.6 + Haiku
        esac
    fi
    fi

    # 生成模型配置
    OPUS='{"id":"claude-opus-4-6","name":"Claude Opus 4.6","api":"anthropic-messages","reasoning":true,"input":["text","image"],"cost":{"input":0,"output":0,"cacheRead":0,"cacheWrite":0},"contextWindow":200000,"maxTokens":32000}'
    SONNET46='{"id":"claude-sonnet-4-6","name":"Claude Sonnet 4.6","api":"anthropic-messages","reasoning":true,"input":["text","image"],"cost":{"input":0,"output":0,"cacheRead":0,"cacheWrite":0},"contextWindow":200000,"maxTokens":32000}'
    HAIKU='{"id":"claude-haiku-4-5-20251001","name":"Claude Haiku 4.5","api":"anthropic-messages","reasoning":true,"input":["text","image"],"cost":{"input":0,"output":0,"cacheRead":0,"cacheWrite":0},"contextWindow":200000,"maxTokens":32000}'

    MULTI_MODEL=0
    SONNET_ONLY=0
    case $MODEL_CHOICE in
        1)
            CLAUDE_MODELS_JSON="[$OPUS]"
            CLAUDE_PRIMARY_MODEL="kkpinche-claude/claude-opus-4-6"
            CLAUDE_FALLBACK_MODELS="[]"
            CLAUDE_MODEL_COUNT=1
            ;;
        2)
            CLAUDE_MODELS_JSON="[$SONNET46]"
            CLAUDE_PRIMARY_MODEL="kkpinche-claude/claude-sonnet-4-6"
            CLAUDE_FALLBACK_MODELS="[]"
            CLAUDE_MODEL_COUNT=1
            ;;
        3)
            CLAUDE_MODELS_JSON="[$HAIKU]"
            CLAUDE_PRIMARY_MODEL="kkpinche-claude/claude-haiku-4-5-20251001"
            CLAUDE_FALLBACK_MODELS="[]"
            CLAUDE_MODEL_COUNT=1
            ;;
        4)
            CLAUDE_MODELS_JSON="[$OPUS,$SONNET46,$HAIKU]"
            MULTI_MODEL=1
            CLAUDE_PRIMARY_MODEL="kkpinche-claude/claude-opus-4-6"
            CLAUDE_FALLBACK_MODELS='["kkpinche-claude/claude-sonnet-4-6","kkpinche-claude/claude-haiku-4-5-20251001"]'
            CLAUDE_MODEL_COUNT=3
            ;;
        5)
            # Sonnet Only 套餐的全部配置
            CLAUDE_MODELS_JSON="[$SONNET46,$HAIKU]"
            MULTI_MODEL=1
            SONNET_ONLY=1
            CLAUDE_MODEL_COUNT=2
            ;;
    esac

    # 选择主模型（仅当配置了多个模型时，且是单独配置 Claude）
    if [ "$MULTI_MODEL" = "1" ] && [ "$MULTI_PROVIDER" = "0" ]; then
        print_step "选择 Claude 主模型（日常使用）"
        echo ""
        if [ "$SONNET_ONLY" = "1" ]; then
            # Sonnet Only 套餐
            echo "  1) Claude Sonnet 4.6  - 新一代平衡，推荐"
            echo "  2) Claude Haiku 4.5   - 响应最快，适合简单任务"
            echo ""

            while true; do
                echo -n "请选择主模型 [1-2，默认 1]: "
                read PRIMARY_CHOICE
                PRIMARY_CHOICE=${PRIMARY_CHOICE:-1}

                case "$PRIMARY_CHOICE" in
                    1|2) break ;;
                    *) print_error "请输入 1-2" ;;
                esac
            done

            case $PRIMARY_CHOICE in
                1) CLAUDE_PRIMARY_MODEL="kkpinche-claude/claude-sonnet-4-6" ;;
                2) CLAUDE_PRIMARY_MODEL="kkpinche-claude/claude-haiku-4-5-20251001" ;;
            esac

            # Sonnet Only 备用模型
            print_step "选择 Claude 备用模型（主模型不可用时自动切换）"
            echo ""
            echo "  1) 按性能排序：Sonnet 4.6 → Haiku（推荐）"
            echo "  2) 按速度排序：Haiku → Sonnet 4.6"
            echo "  3) 不设置备用模型"
            echo ""

            while true; do
                echo -n "请选择备用策略 [1-3，默认 1]: "
                read FALLBACK_CHOICE
                FALLBACK_CHOICE=${FALLBACK_CHOICE:-1}

                case "$FALLBACK_CHOICE" in
                    1|2|3) break ;;
                    *) print_error "请输入 1-3" ;;
                esac
            done

            case $FALLBACK_CHOICE in
                1)
                    case $PRIMARY_CHOICE in
                        1) CLAUDE_FALLBACK_MODELS='["kkpinche-claude/claude-haiku-4-5-20251001"]' ;;
                        2) CLAUDE_FALLBACK_MODELS='["kkpinche-claude/claude-sonnet-4-6"]' ;;
                    esac
                    ;;
                2)
                    case $PRIMARY_CHOICE in
                        1) CLAUDE_FALLBACK_MODELS='["kkpinche-claude/claude-haiku-4-5-20251001"]' ;;
                        2) CLAUDE_FALLBACK_MODELS='["kkpinche-claude/claude-sonnet-4-6"]' ;;
                    esac
                    ;;
                3)
                    CLAUDE_FALLBACK_MODELS="[]"
                    ;;
            esac
        else
            # 全模型套餐
            echo "  1) Claude Opus 4.6    - 最强大，适合复杂任务"
            echo "  2) Claude Sonnet 4.6  - 新一代平衡，推荐"
            echo "  3) Claude Haiku 4.5   - 响应最快，适合简单任务"
            echo ""

            while true; do
                echo -n "请选择主模型 [1-3，默认 1]: "
                read PRIMARY_CHOICE
                PRIMARY_CHOICE=${PRIMARY_CHOICE:-1}

                case "$PRIMARY_CHOICE" in
                    1|2|3) break ;;
                    *) print_error "请输入 1-3" ;;
                esac
            done

            case $PRIMARY_CHOICE in
                1) CLAUDE_PRIMARY_MODEL="kkpinche-claude/claude-opus-4-6" ;;
                2) CLAUDE_PRIMARY_MODEL="kkpinche-claude/claude-sonnet-4-6" ;;
                3) CLAUDE_PRIMARY_MODEL="kkpinche-claude/claude-haiku-4-5-20251001" ;;
            esac

            # 全模型备用模型
            print_step "选择 Claude 备用模型（主模型不可用时自动切换）"
            echo ""
            echo "  1) 按性能排序：Opus → Sonnet 4.6 → Haiku（推荐）"
            echo "  2) 按速度排序：Haiku → Sonnet 4.6 → Opus"
            echo "  3) 不设置备用模型"
            echo ""

            while true; do
                echo -n "请选择备用策略 [1-3，默认 1]: "
                read FALLBACK_CHOICE
                FALLBACK_CHOICE=${FALLBACK_CHOICE:-1}

                case "$FALLBACK_CHOICE" in
                    1|2|3) break ;;
                    *) print_error "请输入 1-3" ;;
                esac
            done

            case $FALLBACK_CHOICE in
                1)
                    case $PRIMARY_CHOICE in
                        1) CLAUDE_FALLBACK_MODELS='["kkpinche-claude/claude-sonnet-4-6","kkpinche-claude/claude-haiku-4-5-20251001"]' ;;
                        2) CLAUDE_FALLBACK_MODELS='["kkpinche-claude/claude-opus-4-6","kkpinche-claude/claude-haiku-4-5-20251001"]' ;;
                        3) CLAUDE_FALLBACK_MODELS='["kkpinche-claude/claude-opus-4-6","kkpinche-claude/claude-sonnet-4-6"]' ;;
                    esac
                    ;;
                2)
                    case $PRIMARY_CHOICE in
                        1) CLAUDE_FALLBACK_MODELS='["kkpinche-claude/claude-haiku-4-5-20251001","kkpinche-claude/claude-sonnet-4-6"]' ;;
                        2) CLAUDE_FALLBACK_MODELS='["kkpinche-claude/claude-haiku-4-5-20251001","kkpinche-claude/claude-opus-4-6"]' ;;
                        3) CLAUDE_FALLBACK_MODELS='["kkpinche-claude/claude-sonnet-4-6","kkpinche-claude/claude-opus-4-6"]' ;;
                    esac
                    ;;
                3)
                    CLAUDE_FALLBACK_MODELS="[]"
                    ;;
            esac
        fi
    fi
}

# 选择主模型（从所有已启用的类型中选择）
PRIMARY_MODEL=""
FALLBACK_MODELS=""

select_primary_model() {
    print_step "选择全局主模型"
    echo ""
    echo "从所有已配置的模型中选择一个作为默认主模型："
    echo ""

    # 构建模型列表
    declare -a MODEL_OPTIONS
    declare -a MODEL_IDS
    OPUS_INDEX=""
    INDEX=1

    # OpenAI 系列 - 显示所有 12 个模型
    if [ "$ENABLE_OPENAI" = "1" ]; then
        echo "${BOLD}OpenAI/Codex 系列：${NC}"

        MODEL_OPTIONS[$INDEX]="GPT-5"
        MODEL_IDS[$INDEX]="kkpinche-openai/gpt-5"
        echo "  $INDEX) ${MODEL_OPTIONS[$INDEX]}"
        INDEX=$((INDEX + 1))

        MODEL_OPTIONS[$INDEX]="GPT-5 Codex (推荐)"
        MODEL_IDS[$INDEX]="kkpinche-openai/gpt-5-codex"
        echo "  $INDEX) ${MODEL_OPTIONS[$INDEX]}"
        INDEX=$((INDEX + 1))

        MODEL_OPTIONS[$INDEX]="GPT-5 Codex Mini"
        MODEL_IDS[$INDEX]="kkpinche-openai/gpt-5-codex-mini"
        echo "  $INDEX) ${MODEL_OPTIONS[$INDEX]}"
        INDEX=$((INDEX + 1))

        MODEL_OPTIONS[$INDEX]="GPT-5.1"
        MODEL_IDS[$INDEX]="kkpinche-openai/gpt-5.1"
        echo "  $INDEX) ${MODEL_OPTIONS[$INDEX]}"
        INDEX=$((INDEX + 1))

        MODEL_OPTIONS[$INDEX]="GPT-5.1 Codex"
        MODEL_IDS[$INDEX]="kkpinche-openai/gpt-5.1-codex"
        echo "  $INDEX) ${MODEL_OPTIONS[$INDEX]}"
        INDEX=$((INDEX + 1))

        MODEL_OPTIONS[$INDEX]="GPT-5.1 Codex Mini"
        MODEL_IDS[$INDEX]="kkpinche-openai/gpt-5.1-codex-mini"
        echo "  $INDEX) ${MODEL_OPTIONS[$INDEX]}"
        INDEX=$((INDEX + 1))

        MODEL_OPTIONS[$INDEX]="GPT-5.1 Codex Max"
        MODEL_IDS[$INDEX]="kkpinche-openai/gpt-5.1-codex-max"
        echo "  $INDEX) ${MODEL_OPTIONS[$INDEX]}"
        INDEX=$((INDEX + 1))

        MODEL_OPTIONS[$INDEX]="GPT-5.2"
        MODEL_IDS[$INDEX]="kkpinche-openai/gpt-5.2"
        echo "  $INDEX) ${MODEL_OPTIONS[$INDEX]}"
        INDEX=$((INDEX + 1))

        MODEL_OPTIONS[$INDEX]="GPT-5.2 Codex"
        MODEL_IDS[$INDEX]="kkpinche-openai/gpt-5.2-codex"
        echo "  $INDEX) ${MODEL_OPTIONS[$INDEX]}"
        INDEX=$((INDEX + 1))

        MODEL_OPTIONS[$INDEX]="GPT-5.3 Codex"
        MODEL_IDS[$INDEX]="kkpinche-openai/gpt-5.3-codex"
        echo "  $INDEX) ${MODEL_OPTIONS[$INDEX]}"
        INDEX=$((INDEX + 1))

        MODEL_OPTIONS[$INDEX]="GPT-5.3 Codex Spark"
        MODEL_IDS[$INDEX]="kkpinche-openai/gpt-5.3-codex-spark"
        echo "  $INDEX) ${MODEL_OPTIONS[$INDEX]}"
        INDEX=$((INDEX + 1))

        MODEL_OPTIONS[$INDEX]="GPT-5.4 (最新)"
        MODEL_IDS[$INDEX]="kkpinche-openai/gpt-5.4"
        echo "  $INDEX) ${MODEL_OPTIONS[$INDEX]}"
        INDEX=$((INDEX + 1))

        echo ""
    fi

    # Claude 系列
    if [ "$ENABLE_CLAUDE" = "1" ]; then
        echo "${BOLD}Claude 系列：${NC}"

        # 根据套餐显示可用模型
        if echo "$CLAUDE_MODELS_JSON" | grep -q "claude-opus"; then
            MODEL_OPTIONS[$INDEX]="Claude Opus 4.6 (最强推理能力)"
            MODEL_IDS[$INDEX]="kkpinche-claude/claude-opus-4-6"
            OPUS_INDEX=$INDEX
            echo "  $INDEX) ${MODEL_OPTIONS[$INDEX]}"
            INDEX=$((INDEX + 1))
        fi

        if echo "$CLAUDE_MODELS_JSON" | grep -q "claude-sonnet-4-6"; then
            MODEL_OPTIONS[$INDEX]="Claude Sonnet 4.6 (新一代平衡)"
            MODEL_IDS[$INDEX]="kkpinche-claude/claude-sonnet-4-6"
            echo "  $INDEX) ${MODEL_OPTIONS[$INDEX]}"
            INDEX=$((INDEX + 1))
        fi


        if echo "$CLAUDE_MODELS_JSON" | grep -q "claude-haiku"; then
            MODEL_OPTIONS[$INDEX]="Claude Haiku 4.5 (快速响应)"
            MODEL_IDS[$INDEX]="kkpinche-claude/claude-haiku-4-5-20251001"
            echo "  $INDEX) ${MODEL_OPTIONS[$INDEX]}"
            INDEX=$((INDEX + 1))
        fi
        echo ""
    fi

    # Gemini 系列 - 显示所有 6 个模型
    if [ "$ENABLE_GEMINI" = "1" ]; then
        echo "${BOLD}Google Gemini 系列：${NC}"

        MODEL_OPTIONS[$INDEX]="Gemini 3.1 Pro Preview (最新)"
        MODEL_IDS[$INDEX]="google/gemini-3.1-pro-preview"
        echo "  $INDEX) ${MODEL_OPTIONS[$INDEX]}"
        INDEX=$((INDEX + 1))

        MODEL_OPTIONS[$INDEX]="Gemini 3 Pro Preview"
        MODEL_IDS[$INDEX]="google/gemini-3-pro-preview"
        echo "  $INDEX) ${MODEL_OPTIONS[$INDEX]}"
        INDEX=$((INDEX + 1))

        MODEL_OPTIONS[$INDEX]="Gemini 3 Flash Preview"
        MODEL_IDS[$INDEX]="google/gemini-3-flash-preview"
        echo "  $INDEX) ${MODEL_OPTIONS[$INDEX]}"
        INDEX=$((INDEX + 1))

        MODEL_OPTIONS[$INDEX]="Gemini 2.5 Pro"
        MODEL_IDS[$INDEX]="google/gemini-2.5-pro"
        echo "  $INDEX) ${MODEL_OPTIONS[$INDEX]}"
        INDEX=$((INDEX + 1))

        MODEL_OPTIONS[$INDEX]="Gemini 2.5 Flash"
        MODEL_IDS[$INDEX]="google/gemini-2.5-flash"
        echo "  $INDEX) ${MODEL_OPTIONS[$INDEX]}"
        INDEX=$((INDEX + 1))

        MODEL_OPTIONS[$INDEX]="Gemini 2.5 Flash Lite"
        MODEL_IDS[$INDEX]="google/gemini-2.5-flash-lite"
        echo "  $INDEX) ${MODEL_OPTIONS[$INDEX]}"
        INDEX=$((INDEX + 1))

        echo ""
    fi

    MAX_CHOICE=$((INDEX - 1))
    # 默认选择 Opus 4.6（如果可用），否则选第一个
    if [ -n "$OPUS_INDEX" ]; then
        DEFAULT_CHOICE=$OPUS_INDEX
    else
        DEFAULT_CHOICE=1
    fi

    # 如果只启用了 Claude 且已经选择了主模型，使用该主模型
    if [ "$ENABLE_CLAUDE" = "1" ] && [ "$ENABLE_OPENAI" = "0" ] && [ "$ENABLE_GEMINI" = "0" ] && [ -n "$CLAUDE_PRIMARY_MODEL" ]; then
        PRIMARY_MODEL="$CLAUDE_PRIMARY_MODEL"
        FALLBACK_MODELS="$CLAUDE_FALLBACK_MODELS"
        return
    fi

    while true; do
        echo -n "请选择主模型 [1-$MAX_CHOICE，默认 $DEFAULT_CHOICE]: "
        read PRIMARY_CHOICE
        PRIMARY_CHOICE=${PRIMARY_CHOICE:-$DEFAULT_CHOICE}

        if [ "$PRIMARY_CHOICE" -ge 1 ] && [ "$PRIMARY_CHOICE" -le "$MAX_CHOICE" ]; then
            PRIMARY_MODEL="${MODEL_IDS[$PRIMARY_CHOICE]}"
            break
        else
            print_error "请输入 1-$MAX_CHOICE"
        fi
    done

    # 询问是否设置备用模型
    print_step "是否设置备用模型？"
    echo ""
    echo "  1) 是，设置备用模型（推荐）"
    echo "  2) 否，不设置备用模型"
    echo ""

    while true; do
        echo -n "请选择 [1-2，默认 1]: "
        read FALLBACK_OPTION
        FALLBACK_OPTION=${FALLBACK_OPTION:-1}

        case "$FALLBACK_OPTION" in
            1|2) break ;;
            *) print_error "请输入 1 或 2" ;;
        esac
    done

    if [ "$FALLBACK_OPTION" = "2" ]; then
        FALLBACK_MODELS="[]"
        return
    fi

    # 设置备用模型（自动选择其他可用模型）
    FALLBACK_LIST=""
    for i in $(seq 1 $MAX_CHOICE); do
        if [ "$i" != "$PRIMARY_CHOICE" ]; then
            if [ -z "$FALLBACK_LIST" ]; then
                FALLBACK_LIST="\"${MODEL_IDS[$i]}\""
            else
                FALLBACK_LIST="$FALLBACK_LIST,\"${MODEL_IDS[$i]}\""
            fi
        fi
    done

    if [ -n "$FALLBACK_LIST" ]; then
        FALLBACK_MODELS="[$FALLBACK_LIST]"
    else
        FALLBACK_MODELS="[]"
    fi
}

# 主配置流程
main() {
    # 清屏（忽略错误）
    clear 2>/dev/null || true
    print_header "🦞openclaw KKpinche API 多模型配置向导"

    echo ""
    echo "本向导将帮助你在你的🦞openclaw中配置 KKpinche 的多模型 API 服务。"
    echo "支持 OpenAI/Codex、Claude、Google Gemini 三种模型类型。"
    echo "你需要准备好你的 API Key（以 cr_ 开头）。"
    echo ""

    # 检查 openclaw/clawdbot
    print_step "检查 openclaw 安装..."
    check_clawdbot
    CLI_VERSION=$($CLI_BIN --version 2>&1 | head -1)
    print_success "已安装: openclaw ($CLI_VERSION)"

    # 选择模型类型
    select_model_types

    # 输入 API Key
    print_step "请输入你的 API Key"
    echo "${YELLOW}(API Key 以 cr_ 开头，共 67 位，请联系微信 zkh120416890 获取)${NC}"
    echo ""

    while true; do
        echo -n "API Key: "
        read API_KEY

        # 验证格式
        if [ -z "$API_KEY" ]; then
            print_error "API Key 不能为空，请重新输入"
            continue
        fi

        # 检查是否以 cr_ 开头
        case "$API_KEY" in
            cr_*)
                # 检查长度是否为 67 位 (cr_ + 64位十六进制)
                KEY_LEN=${#API_KEY}
                if [ "$KEY_LEN" -ne 67 ]; then
                    print_error "API Key 格式有误，请重新检查 API Key（应为 67 位，当前 $KEY_LEN 位）"
                    continue
                fi
                # 检查 cr_ 后面是否都是十六进制字符
                KEY_SUFFIX="${API_KEY#cr_}"
                if ! echo "$KEY_SUFFIX" | grep -qE '^[0-9a-fA-F]{64}$'; then
                    print_error "API Key 格式有误，请重新检查 API Key"
                    continue
                fi
                ;;
            *)
                print_error "API Key 格式有误，应以 cr_ 开头，请重新检查 API Key"
                continue
                ;;
        esac

        break
    done

    # 生成配置
    print_step "生成模型配置..."
    echo ""

    # 生成各类型配置
    if [ "$ENABLE_OPENAI" = "1" ]; then
        generate_openai_config
        print_success "OpenAI/Codex 配置已生成"
    fi

    if [ "$ENABLE_CLAUDE" = "1" ]; then
        generate_claude_config
        print_success "Claude 配置已生成"
    fi

    if [ "$ENABLE_GEMINI" = "1" ]; then
        generate_gemini_config
        print_success "Gemini 配置已生成"
    fi

    # 选择主模型
    select_primary_model

    # 应用配置
    print_step "应用配置..."
    echo ""

    # 设置 models.mode 为 merge
    printf "  设置模型合并模式... "
    if $CLI_BIN config set models.mode merge > /dev/null 2>&1; then
        printf "%s✓%s\n" "$GREEN" "$NC"
    else
        printf "%s跳过%s\n" "$YELLOW" "$NC"
    fi

    # 配置 OpenAI
    if [ "$ENABLE_OPENAI" = "1" ]; then
        printf "  设置 OpenAI/Codex 配置... "
        OPENAI_CONFIG="{\"baseUrl\":\"https://api.gptclubapi.xyz/openai\",\"apiKey\":\"$API_KEY\",\"api\":\"openai-responses\",\"models\":$OPENAI_MODELS_JSON}"
        CONFIG_ERR=$($CLI_BIN config set models.providers.kkpinche-openai --json "$OPENAI_CONFIG" 2>&1)
        if [ $? -eq 0 ]; then
            printf "%s✓%s\n" "$GREEN" "$NC"
        else
            printf "%s✗%s\n" "$RED" "$NC"
            print_error "设置 OpenAI 配置失败"
            echo "  错误详情: $CONFIG_ERR"
            exit 1
        fi
    fi

    # 配置 Claude
    if [ "$ENABLE_CLAUDE" = "1" ]; then
        printf "  设置 Claude 配置... "
        CLAUDE_CONFIG="{\"baseUrl\":\"https://api.gptclubapi.xyz/api\",\"apiKey\":\"$API_KEY\",\"models\":$CLAUDE_MODELS_JSON}"
        CONFIG_ERR=$($CLI_BIN config set models.providers.kkpinche-claude --json "$CLAUDE_CONFIG" 2>&1)
        if [ $? -eq 0 ]; then
            printf "%s✓%s\n" "$GREEN" "$NC"
        else
            printf "%s✗%s\n" "$RED" "$NC"
            print_error "设置 Claude 配置失败"
            echo "  错误详情: $CONFIG_ERR"
            exit 1
        fi
    fi

    # 配置 Gemini
    if [ "$ENABLE_GEMINI" = "1" ]; then
        printf "  设置 Gemini 配置... "
        GEMINI_CONFIG="{\"baseUrl\":\"https://api.gptclubapi.xyz/gemini/v1beta\",\"apiKey\":\"$API_KEY\",\"api\":\"google-generative-ai\",\"models\":$GEMINI_MODELS_JSON}"
        CONFIG_ERR=$($CLI_BIN config set models.providers.google --json "$GEMINI_CONFIG" 2>&1)
        if [ $? -eq 0 ]; then
            printf "%s✓%s\n" "$GREEN" "$NC"
        else
            printf "%s✗%s\n" "$RED" "$NC"
            print_error "设置 Gemini 配置失败"
            echo "  错误详情: $CONFIG_ERR"
            exit 1
        fi
    fi

    # 设置主模型
    printf "  设置主模型... "
    if $CLI_BIN config set agents.defaults.model.primary "$PRIMARY_MODEL" > /dev/null 2>&1; then
        printf "%s✓%s\n" "$GREEN" "$NC"
    else
        printf "%s✗%s\n" "$RED" "$NC"
        print_error "设置主模型失败"
        exit 1
    fi

    # 设置备用模型
    if [ "$FALLBACK_MODELS" != "[]" ] && [ -n "$FALLBACK_MODELS" ]; then
        printf "  设置备用模型... "
        if $CLI_BIN config set agents.defaults.model.fallbacks --json "$FALLBACK_MODELS" > /dev/null 2>&1; then
            printf "%s✓%s\n" "$GREEN" "$NC"
        else
            printf "%s跳过%s\n" "$YELLOW" "$NC"
        fi
    fi

    # 设置模型允许列表（agents.defaults.models），确保所有模型出现在 /model status 中
    printf "  设置模型允许列表... "
    MODELS_ALLOWLIST="{"
    FIRST_ENTRY=1
    if [ "$ENABLE_OPENAI" = "1" ]; then
        for mid in gpt-5 gpt-5-codex gpt-5-codex-mini gpt-5.1 gpt-5.1-codex gpt-5.1-codex-mini gpt-5.1-codex-max gpt-5.2 gpt-5.2-codex gpt-5.3-codex gpt-5.3-codex-spark gpt-5.4; do
            [ "$FIRST_ENTRY" = "0" ] && MODELS_ALLOWLIST="$MODELS_ALLOWLIST,"
            MODELS_ALLOWLIST="$MODELS_ALLOWLIST\"kkpinche-openai/$mid\":{}"
            FIRST_ENTRY=0
        done
    fi
    if [ "$ENABLE_CLAUDE" = "1" ]; then
        if echo "$CLAUDE_MODELS_JSON" | grep -q "claude-opus"; then
            [ "$FIRST_ENTRY" = "0" ] && MODELS_ALLOWLIST="$MODELS_ALLOWLIST,"
            MODELS_ALLOWLIST="$MODELS_ALLOWLIST\"kkpinche-claude/claude-opus-4-6\":{}"
            FIRST_ENTRY=0
        fi
        if echo "$CLAUDE_MODELS_JSON" | grep -q "claude-sonnet-4-6"; then
            [ "$FIRST_ENTRY" = "0" ] && MODELS_ALLOWLIST="$MODELS_ALLOWLIST,"
            MODELS_ALLOWLIST="$MODELS_ALLOWLIST\"kkpinche-claude/claude-sonnet-4-6\":{}"
            FIRST_ENTRY=0
        fi
        if echo "$CLAUDE_MODELS_JSON" | grep -q "claude-haiku"; then
            [ "$FIRST_ENTRY" = "0" ] && MODELS_ALLOWLIST="$MODELS_ALLOWLIST,"
            MODELS_ALLOWLIST="$MODELS_ALLOWLIST\"kkpinche-claude/claude-haiku-4-5-20251001\":{}"
            FIRST_ENTRY=0
        fi
    fi
    if [ "$ENABLE_GEMINI" = "1" ]; then
        for mid in gemini-3.1-pro-preview gemini-3-pro-preview gemini-3-flash-preview gemini-2.5-pro gemini-2.5-flash gemini-2.5-flash-lite; do
            [ "$FIRST_ENTRY" = "0" ] && MODELS_ALLOWLIST="$MODELS_ALLOWLIST,"
            MODELS_ALLOWLIST="$MODELS_ALLOWLIST\"google/$mid\":{}"
            FIRST_ENTRY=0
        done
    fi
    MODELS_ALLOWLIST="$MODELS_ALLOWLIST}"
    if $CLI_BIN config set agents.defaults.models --json "$MODELS_ALLOWLIST" > /dev/null 2>&1; then
        printf "%s✓%s\n" "$GREEN" "$NC"
    else
        printf "%s跳过%s\n" "$YELLOW" "$NC"
    fi

    # 验证配置
    print_step "验证配置..."
    echo ""

    VERIFY_OK=1

    # 验证 provider 配置
    if [ "$ENABLE_OPENAI" = "1" ]; then
        printf "  检查 OpenAI 配置... "
        if $CLI_BIN config get models.providers.kkpinche-openai > /dev/null 2>&1; then
            printf "%s✓%s\n" "$GREEN" "$NC"
        else
            printf "%s✗%s\n" "$RED" "$NC"
            VERIFY_OK=0
        fi
    fi

    if [ "$ENABLE_CLAUDE" = "1" ]; then
        printf "  检查 Claude 配置... "
        if $CLI_BIN config get models.providers.kkpinche-claude > /dev/null 2>&1; then
            printf "%s✓%s\n" "$GREEN" "$NC"
        else
            printf "%s✗%s\n" "$RED" "$NC"
            VERIFY_OK=0
        fi
    fi

    if [ "$ENABLE_GEMINI" = "1" ]; then
        printf "  检查 Gemini 配置... "
        if $CLI_BIN config get models.providers.google > /dev/null 2>&1; then
            printf "%s✓%s\n" "$GREEN" "$NC"
        else
            printf "%s✗%s\n" "$RED" "$NC"
            VERIFY_OK=0
        fi
    fi

    # 验证主模型
    printf "  检查主模型配置... "
    CURRENT_PRIMARY=$($CLI_BIN config get agents.defaults.model.primary 2>&1)
    if [ "$CURRENT_PRIMARY" = "$PRIMARY_MODEL" ]; then
        printf "%s✓%s\n" "$GREEN" "$NC"
    else
        printf "%s✗%s\n" "$RED" "$NC"
        VERIFY_OK=0
    fi

    echo ""

    if [ "$VERIFY_OK" = "0" ]; then
        print_warning "部分配置验证失败，请运行 $CLI_BIN doctor 检查详细信息"
        echo ""
    else
        print_success "所有配置验证通过！"
        echo ""
    fi

    # 完成
    print_header "🎉 配置完成！"

    echo ""
    echo "已配置:"
    if [ "$ENABLE_OPENAI" = "1" ]; then
        printf "  %s•%s OpenAI/Codex: https://api.gptclubapi.xyz/openai (%d个模型)\n" "$GREEN" "$NC" "$OPENAI_MODEL_COUNT"
    fi
    if [ "$ENABLE_CLAUDE" = "1" ]; then
        printf "  %s•%s Claude: https://api.gptclubapi.xyz/api (%d个模型)\n" "$GREEN" "$NC" "$CLAUDE_MODEL_COUNT"
    fi
    if [ "$ENABLE_GEMINI" = "1" ]; then
        printf "  %s•%s Gemini: https://api.gptclubapi.xyz/gemini/v1beta (%d个模型)\n" "$GREEN" "$NC" "$GEMINI_MODEL_COUNT"
    fi
    printf "  %s•%s API Key: %.15s...\n" "$GREEN" "$NC" "$API_KEY"
    printf "  %s•%s 主模型: %s\n" "$GREEN" "$NC" "$PRIMARY_MODEL"
    if [ "$FALLBACK_MODELS" != "[]" ] && [ -n "$FALLBACK_MODELS" ]; then
        printf "  %s•%s 备用模型: %s\n" "$GREEN" "$NC" "$FALLBACK_MODELS"
    fi
    echo ""
    echo ""
    printf "%sDiscord社区地址:%s\n" "$YELLOW" "$NC"
    printf "%shttps://discord.gg/JFYQJrqzEZ%s\n" "$CYAN" "$NC"
    echo ""
    printf "%s提示：首次使用建议运行 $CLI_BIN doctor 检查配置%s\n" "$YELLOW" "$NC"
    echo ""

    # 询问是否重启
    print_step "是否立即重启 $CLI_BIN 使配置生效？"
    echo ""
    echo "  1) 是，自动重启 $CLI_BIN"
    echo "  2) 否，稍后我自己重启"
    echo ""

    while true; do
        echo -n "请选择 [1-2，默认 1]: "
        read RESTART_CHOICE
        RESTART_CHOICE=${RESTART_CHOICE:-1}

        case "$RESTART_CHOICE" in
            1|2) break ;;
            *) print_error "请输入 1 或 2" ;;
        esac
    done

    if [ "$RESTART_CHOICE" = "1" ]; then
        restart_clawdbot
    else
        echo ""
        echo "配置已保存，请重启 $CLI_BIN 使配置生效："
        printf "  %s$CLI_BIN agent%s      - 启动 Agent 模式\n" "$CYAN" "$NC"
        printf "  %s$CLI_BIN gateway%s   - 启动 Gateway 模式（支持 Telegram/Discord）\n" "$CYAN" "$NC"
        echo ""
    fi

    printf "%s配置向导已完成，祝你使用愉快！%s\n" "$GREEN" "$NC"
    echo ""
}

# 运行主流程
main
