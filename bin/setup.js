#!/usr/bin/env node
const readline = require('readline');
const { execSync, spawn } = require('child_process');
const os = require('os');

// Windows UTF-8 encoding fix
if (os.platform() === 'win32') {
  try { execSync('chcp 65001', { stdio: 'ignore' }); } catch {}
}

// ANSI colors
const RED = '\x1b[0;31m', GREEN = '\x1b[0;32m', YELLOW = '\x1b[1;33m';
const BLUE = '\x1b[0;34m', CYAN = '\x1b[0;36m', NC = '\x1b[0m', BOLD = '\x1b[1m';

const print = {
  header: (msg) => console.log(`\n${CYAN}${'━'.repeat(78)}\n  ${msg}\n${'━'.repeat(78)}${NC}`),
  step: (msg) => console.log(`\n${BLUE}▶${NC} ${BOLD}${msg}${NC}`),
  success: (msg) => console.log(`${GREEN}✓${NC} ${msg}`),
  error: (msg) => console.log(`${RED}✗${NC} ${msg}`),
  warning: (msg) => console.log(`${YELLOW}!${NC} ${msg}`)
};

const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
const ask = (q) => new Promise(resolve => rl.question(q, resolve));

let CLI_BIN = '';
let ENABLE_OPENAI = 0, ENABLE_CLAUDE = 0, ENABLE_GEMINI = 0;
let OPENAI_MODELS_JSON = '', CLAUDE_MODELS_JSON = '', GEMINI_MODELS_JSON = '';
let CLAUDE_PRIMARY_MODEL = '', CLAUDE_FALLBACK_MODELS = '';
let CLAUDE_MODEL_COUNT = 0;
const OPENAI_MODEL_COUNT = 12, GEMINI_MODEL_COUNT = 6;
let PRIMARY_MODEL = '', FALLBACK_MODELS = '';
let API_KEY = '';

// ──────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────

function run(cmd) {
  try {
    return execSync(cmd, { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] }).trim();
  } catch { return null; }
}

function isWin() { return os.platform() === 'win32'; }

// Escape JSON string for shell command argument
function shellJson(jsonStr) {
  if (isWin()) {
    // On Windows cmd, wrap in double quotes and escape inner double quotes
    // PowerShell and cmd handle this differently; use a temp approach
    // The safest approach: write to a temp file and read, but for openclaw
    // we can use the approach of escaping double-quotes with backslash
    // which works for most Node child_process execSync calls on Windows
    return `"${jsonStr.replace(/"/g, '\\"')}"`;
  }
  // On Unix, use single quotes (JSON doesn't contain single quotes)
  return `'${jsonStr}'`;
}

// ─────────────────────────────────────────────────────���────
// Step 1: Check openclaw installation
// ──────────────────────────────────────────────────────────

function checkClawdbot() {
  const candidates = isWin()
    ? ['openclaw', 'openclaw.cmd', 'clawdbot', 'clawdbot.cmd']
    : ['openclaw', 'clawdbot'];

  for (const cmd of candidates) {
    if (run(`${cmd} --version`) !== null) {
      CLI_BIN = cmd;
      return;
    }
  }

  print.error('openclaw 未安装或不在 PATH 中');
  console.log('\n请先安装 openclaw:\n  npm install -g openclaw\n');
  if (isWin()) {
    console.log('如果已安装但找不到，请确认 npm 全局目录在 PATH 中:');
    console.log('  npm prefix -g\n');
  }
  process.exit(1);
}

// ──────────────────────────────────────────────────────────
// Step 2: Select model types (multi-select)
// ──────────────────────────────────────────────────────────

async function selectModelTypes() {
  print.step('选择要配置的模型类型（支持多选）');
  console.log('');
  console.log('  1) OpenAI/Codex (GPT-5 系列，12个模型)');
  console.log('  2) Claude (Claude 4.6 系列，2-3个模型)');
  console.log('  3) Google Gemini (Gemini 2.5/3.0/3.1 系列，6个模型)');
  console.log(`\n${YELLOW}提示：可以选择多个，直接输入数字组合（如: 12 或 123 或 13）${NC}\n`);

  while (true) {
    let input = (await ask('请选择 [1 或 2 或 3，可多选，默认 2]: ')).trim();
    if (!input) input = '2';
    input = input.replace(/\s/g, '');

    const chars = input.split('');
    let valid = true;
    for (const c of chars) {
      if (!['1','2','3'].includes(c)) {
        print.error(`无效的字符: ${c}，只能输入 1、2、3`);
        valid = false;
        break;
      }
    }
    if (!valid) continue;

    const unique = [...new Set(chars)];
    unique.forEach(c => {
      if (c === '1') ENABLE_OPENAI = 1;
      if (c === '2') ENABLE_CLAUDE = 1;
      if (c === '3') ENABLE_GEMINI = 1;
    });
    break;
  }

  console.log('\n已选择的模型类型：');
  if (ENABLE_OPENAI) console.log(`  ${GREEN}•${NC} OpenAI/Codex (GPT-5 系列)`);
  if (ENABLE_CLAUDE) console.log(`  ${GREEN}•${NC} Claude (Claude 4.6 系列)`);
  if (ENABLE_GEMINI) console.log(`  ${GREEN}•${NC} Google Gemini (Gemini 2.5/3.0/3.1 系列)`);
}

// ───────────────────────────────��──────────────────────────
// Model JSON definitions
// ──────────────────────────────────────────────────────────

const OPENAI_MODELS = [
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
];

const GEMINI_MODELS = [
  {"id":"gemini-3.1-pro-preview","name":"Gemini 3.1 Pro Preview","reasoning":true,"input":["text","image"],"cost":{"input":0,"output":0,"cacheRead":0,"cacheWrite":0},"contextWindow":1048576,"maxTokens":8192},
  {"id":"gemini-3-pro-preview","name":"Gemini 3 Pro Preview","reasoning":true,"input":["text","image"],"cost":{"input":0,"output":0,"cacheRead":0,"cacheWrite":0},"contextWindow":1048576,"maxTokens":8192},
  {"id":"gemini-3-flash-preview","name":"Gemini 3 Flash Preview","reasoning":true,"input":["text","image"],"cost":{"input":0,"output":0,"cacheRead":0,"cacheWrite":0},"contextWindow":1048576,"maxTokens":8192},
  {"id":"gemini-2.5-pro","name":"Gemini 2.5 Pro","reasoning":true,"input":["text","image"],"cost":{"input":0,"output":0,"cacheRead":0,"cacheWrite":0},"contextWindow":1048576,"maxTokens":8192},
  {"id":"gemini-2.5-flash","name":"Gemini 2.5 Flash","reasoning":true,"input":["text","image"],"cost":{"input":0,"output":0,"cacheRead":0,"cacheWrite":0},"contextWindow":1048576,"maxTokens":8192},
  {"id":"gemini-2.5-flash-lite","name":"Gemini 2.5 Flash Lite","reasoning":true,"input":["text","image"],"cost":{"input":0,"output":0,"cacheRead":0,"cacheWrite":0},"contextWindow":1048576,"maxTokens":8192}
];

const CLAUDE_OPUS = {"id":"claude-opus-4-6","name":"Claude Opus 4.6","api":"anthropic-messages","reasoning":true,"input":["text","image"],"cost":{"input":0,"output":0,"cacheRead":0,"cacheWrite":0},"contextWindow":200000,"maxTokens":32000};
const CLAUDE_SONNET46 = {"id":"claude-sonnet-4-6","name":"Claude Sonnet 4.6","api":"anthropic-messages","reasoning":true,"input":["text","image"],"cost":{"input":0,"output":0,"cacheRead":0,"cacheWrite":0},"contextWindow":200000,"maxTokens":32000};
const CLAUDE_HAIKU = {"id":"claude-haiku-4-5-20251001","name":"Claude Haiku 4.5","api":"anthropic-messages","reasoning":true,"input":["text","image"],"cost":{"input":0,"output":0,"cacheRead":0,"cacheWrite":0},"contextWindow":200000,"maxTokens":32000};

// ──────────────────────────────────────────────────────────
// Config generation helpers
// ──────────────────────────────────────────────────────────

function generateOpenaiConfig() {
  OPENAI_MODELS_JSON = JSON.stringify(OPENAI_MODELS);
}

function generateGeminiConfig() {
  GEMINI_MODELS_JSON = JSON.stringify(GEMINI_MODELS);
}

// ──────────────────────────────────────────────────────────
// Step 3-5: Claude configuration
// ──────────────────────────────────────────────────────────

async function generateClaudeConfig() {
  const MULTI_PROVIDER = (ENABLE_OPENAI || ENABLE_GEMINI) ? 1 : 0;
  let PACKAGE_TYPE, MODEL_CHOICE;

  if (MULTI_PROVIDER) {
    // Multi-provider mode: auto full package
    print.step('配置 Claude 模型');
    console.log('');
    console.log('检测到多模型配置，自动使用 Claude 全模型套餐 (Opus 4.6 + Sonnet 4.6 + Haiku 4.5)');
    PACKAGE_TYPE = 1;
    MODEL_CHOICE = 4;
  } else {
    // Step 3: Select Claude package type (single provider only)
    print.step('选择 Claude 套餐类型');
    console.log('');
    console.log('  1) Claude 全模型套餐 (Opus 4.6 + Sonnet 4.6 + Haiku 4.5)');
    console.log('  2) Sonnet Only 套餐 (Sonnet 4.6 + Haiku 4.5)');
    console.log('');

    while (true) {
      let input = (await ask('请选择 [1-2，默认 1]: ')).trim();
      PACKAGE_TYPE = parseInt(input || '1', 10);
      if (PACKAGE_TYPE === 1 || PACKAGE_TYPE === 2) break;
      print.error('请输入 1 或 2');
    }
  }

  // Step 4: Select Claude models (single provider only)
  if (!MULTI_PROVIDER) {
    if (PACKAGE_TYPE === 1) {
      // Full package model selection
      print.step('选择要配置的 Claude 模型');
      console.log('');
      console.log('  1) Claude Opus 4.6 (最强，推荐)');
      console.log('  2) Claude Sonnet 4.6 (新一代平衡)');
      console.log('  3) Claude Haiku 4.5 (快速)');
      console.log('  4) 全部配置 (推荐)');
      console.log('');

      while (true) {
        let input = (await ask('请选择 [1-4，默认 4]: ')).trim();
        MODEL_CHOICE = parseInt(input || '4', 10);
        if ([1,2,3,4].includes(MODEL_CHOICE)) break;
        print.error('请输入 1-4');
      }
    } else {
      // Sonnet Only package model selection
      print.step('选择要配置的 Claude 模型');
      console.log('');
      console.log('  1) Claude Sonnet 4.6 (新一代平衡，推荐)');
      console.log('  2) Claude Haiku 4.5 (快速)');
      console.log('  3) 全部配置 (推荐)');
      console.log('');

      let rawChoice;
      while (true) {
        let input = (await ask('请选择 [1-3，默认 3]: ')).trim();
        rawChoice = parseInt(input || '3', 10);
        if ([1,2,3].includes(rawChoice)) break;
        print.error('请输入 1-3');
      }

      // Map Sonnet Only options to unified MODEL_CHOICE
      // 1 -> 2 (Sonnet 4.6), 2 -> 3 (Haiku), 3 -> 5 (Sonnet Only all)
      const mapping = { 1: 2, 2: 3, 3: 5 };
      MODEL_CHOICE = mapping[rawChoice];
    }
  }

  // Generate model configuration based on MODEL_CHOICE
  let MULTI_MODEL = 0;
  let SONNET_ONLY = 0;
  let claudeModels;

  switch (MODEL_CHOICE) {
    case 1:
      claudeModels = [CLAUDE_OPUS];
      CLAUDE_PRIMARY_MODEL = 'kkpinche-claude/claude-opus-4-6';
      CLAUDE_FALLBACK_MODELS = '[]';
      CLAUDE_MODEL_COUNT = 1;
      break;
    case 2:
      claudeModels = [CLAUDE_SONNET46];
      CLAUDE_PRIMARY_MODEL = 'kkpinche-claude/claude-sonnet-4-6';
      CLAUDE_FALLBACK_MODELS = '[]';
      CLAUDE_MODEL_COUNT = 1;
      break;
    case 3:
      claudeModels = [CLAUDE_HAIKU];
      CLAUDE_PRIMARY_MODEL = 'kkpinche-claude/claude-haiku-4-5-20251001';
      CLAUDE_FALLBACK_MODELS = '[]';
      CLAUDE_MODEL_COUNT = 1;
      break;
    case 4:
      claudeModels = [CLAUDE_OPUS, CLAUDE_SONNET46, CLAUDE_HAIKU];
      MULTI_MODEL = 1;
      CLAUDE_PRIMARY_MODEL = 'kkpinche-claude/claude-opus-4-6';
      CLAUDE_FALLBACK_MODELS = JSON.stringify([
        'kkpinche-claude/claude-sonnet-4-6',
        'kkpinche-claude/claude-haiku-4-5-20251001'
      ]);
      CLAUDE_MODEL_COUNT = 3;
      break;
    case 5:
      // Sonnet Only all
      claudeModels = [CLAUDE_SONNET46, CLAUDE_HAIKU];
      MULTI_MODEL = 1;
      SONNET_ONLY = 1;
      CLAUDE_MODEL_COUNT = 2;
      break;
  }
  CLAUDE_MODELS_JSON = JSON.stringify(claudeModels);

  // Step 5: Select Claude primary model and fallback (multi-model + single provider)
  if (MULTI_MODEL && !MULTI_PROVIDER) {
    if (SONNET_ONLY) {
      // Sonnet Only primary model selection
      print.step('选择 Claude 主模型（日常使用）');
      console.log('');
      console.log('  1) Claude Sonnet 4.6  - 新一代平衡，推荐');
      console.log('  2) Claude Haiku 4.5   - 响应最快，适合简单任务');
      console.log('');

      let PRIMARY_CHOICE;
      while (true) {
        let input = (await ask('请选择主模型 [1-2，默认 1]: ')).trim();
        PRIMARY_CHOICE = parseInt(input || '1', 10);
        if ([1,2].includes(PRIMARY_CHOICE)) break;
        print.error('请输入 1-2');
      }

      if (PRIMARY_CHOICE === 1) CLAUDE_PRIMARY_MODEL = 'kkpinche-claude/claude-sonnet-4-6';
      else CLAUDE_PRIMARY_MODEL = 'kkpinche-claude/claude-haiku-4-5-20251001';

      // Sonnet Only fallback strategy
      print.step('选择 Claude 备用模型（主模型不可用时自动切换）');
      console.log('');
      console.log('  1) 按性能排序：Sonnet 4.6 → Haiku（推荐）');
      console.log('  2) 按速度排序：Haiku → Sonnet 4.6');
      console.log('  3) 不设置备用模型');
      console.log('');

      let FALLBACK_CHOICE;
      while (true) {
        let input = (await ask('请选择备用策略 [1-3，默认 1]: ')).trim();
        FALLBACK_CHOICE = parseInt(input || '1', 10);
        if ([1,2,3].includes(FALLBACK_CHOICE)) break;
        print.error('请输入 1-3');
      }

      if (FALLBACK_CHOICE === 3) {
        CLAUDE_FALLBACK_MODELS = '[]';
      } else if (FALLBACK_CHOICE === 1) {
        if (PRIMARY_CHOICE === 1) CLAUDE_FALLBACK_MODELS = JSON.stringify(['kkpinche-claude/claude-haiku-4-5-20251001']);
        else CLAUDE_FALLBACK_MODELS = JSON.stringify(['kkpinche-claude/claude-sonnet-4-6']);
      } else {
        // fallback 2 (by speed) - same result for 2-model set
        if (PRIMARY_CHOICE === 1) CLAUDE_FALLBACK_MODELS = JSON.stringify(['kkpinche-claude/claude-haiku-4-5-20251001']);
        else CLAUDE_FALLBACK_MODELS = JSON.stringify(['kkpinche-claude/claude-sonnet-4-6']);
      }
    } else {
      // Full package primary model selection
      print.step('选择 Claude 主模型（日常使用）');
      console.log('');
      console.log('  1) Claude Opus 4.6    - 最强大，适合复杂任务');
      console.log('  2) Claude Sonnet 4.6  - 新一代平衡，推荐');
      console.log('  3) Claude Haiku 4.5   - 响应最快，适合简单任务');
      console.log('');

      let PRIMARY_CHOICE;
      while (true) {
        let input = (await ask('请选择主模型 [1-3，默认 1]: ')).trim();
        PRIMARY_CHOICE = parseInt(input || '1', 10);
        if ([1,2,3].includes(PRIMARY_CHOICE)) break;
        print.error('请输入 1-3');
      }

      const primaryMap = {
        1: 'kkpinche-claude/claude-opus-4-6',
        2: 'kkpinche-claude/claude-sonnet-4-6',
        3: 'kkpinche-claude/claude-haiku-4-5-20251001'
      };
      CLAUDE_PRIMARY_MODEL = primaryMap[PRIMARY_CHOICE];

      // Full package fallback strategy
      print.step('选择 Claude 备用模型（主模型不可用时自动切换）');
      console.log('');
      console.log('  1) 按性能排序：Opus → Sonnet 4.6 → Haiku（推荐）');
      console.log('  2) 按速度排序：Haiku → Sonnet 4.6 → Opus');
      console.log('  3) 不设置备用模型');
      console.log('');

      let FALLBACK_CHOICE;
      while (true) {
        let input = (await ask('请选择备用策略 [1-3，默认 1]: ')).trim();
        FALLBACK_CHOICE = parseInt(input || '1', 10);
        if ([1,2,3].includes(FALLBACK_CHOICE)) break;
        print.error('请输入 1-3');
      }

      if (FALLBACK_CHOICE === 3) {
        CLAUDE_FALLBACK_MODELS = '[]';
      } else if (FALLBACK_CHOICE === 1) {
        // By performance: Opus → Sonnet → Haiku (exclude primary)
        const perfOrder = [
          'kkpinche-claude/claude-opus-4-6',
          'kkpinche-claude/claude-sonnet-4-6',
          'kkpinche-claude/claude-haiku-4-5-20251001'
        ];
        CLAUDE_FALLBACK_MODELS = JSON.stringify(perfOrder.filter(m => m !== CLAUDE_PRIMARY_MODEL));
      } else {
        // By speed: Haiku → Sonnet → Opus (exclude primary)
        const speedOrder = [
          'kkpinche-claude/claude-haiku-4-5-20251001',
          'kkpinche-claude/claude-sonnet-4-6',
          'kkpinche-claude/claude-opus-4-6'
        ];
        CLAUDE_FALLBACK_MODELS = JSON.stringify(speedOrder.filter(m => m !== CLAUDE_PRIMARY_MODEL));
      }
    }
  }
}

// ──────────────────────────────────────────────────────────
// Step 6: Input API Key
// ───────────────────────────────���──────────────────────────

async function inputApiKey() {
  print.step('请输入你的 API Key');
  console.log(`${YELLOW}(API Key 以 cr_ 开头，共 67 位，可在 https://dashboard.kkpinche.ai 获取)${NC}`);
  console.log('');

  while (true) {
    const key = (await ask('API Key: ')).trim();

    if (!key) {
      print.error('API Key 不能为空，请重新输入');
      continue;
    }

    if (!key.startsWith('cr_')) {
      print.error('API Key 格式有误，应以 cr_ 开头，请重新检查 API Key');
      continue;
    }

    if (key.length !== 67) {
      print.error(`API Key 格式有误，请重新检查 API Key（应为 67 位，当前 ${key.length} 位）`);
      continue;
    }

    const suffix = key.slice(3);
    if (!/^[0-9a-fA-F]{64}$/.test(suffix)) {
      print.error('API Key 格式有误，请重新检查 API Key');
      continue;
    }

    API_KEY = key;
    break;
  }
}

// ──────────────────────────────────────────────────────────
// Step 8-9: Select global primary model + fallbacks
// ──────────────────────────────────────────────────────────

async function selectPrimaryModel() {
  print.step('选择全局主模型');
  console.log('');
  console.log('从所有已配置的模型中选择一个作为默认主模型：');
  console.log('');

  const MODEL_OPTIONS = []; // array of { label, id }
  let opusIndex = -1;

  // OpenAI models
  if (ENABLE_OPENAI) {
    console.log(`${BOLD}OpenAI/Codex 系列：${NC}`);
    const openaiEntries = [
      { label: 'GPT-5', id: 'kkpinche-openai/gpt-5' },
      { label: 'GPT-5 Codex (推荐)', id: 'kkpinche-openai/gpt-5-codex' },
      { label: 'GPT-5 Codex Mini', id: 'kkpinche-openai/gpt-5-codex-mini' },
      { label: 'GPT-5.1', id: 'kkpinche-openai/gpt-5.1' },
      { label: 'GPT-5.1 Codex', id: 'kkpinche-openai/gpt-5.1-codex' },
      { label: 'GPT-5.1 Codex Mini', id: 'kkpinche-openai/gpt-5.1-codex-mini' },
      { label: 'GPT-5.1 Codex Max', id: 'kkpinche-openai/gpt-5.1-codex-max' },
      { label: 'GPT-5.2', id: 'kkpinche-openai/gpt-5.2' },
      { label: 'GPT-5.2 Codex', id: 'kkpinche-openai/gpt-5.2-codex' },
      { label: 'GPT-5.3 Codex', id: 'kkpinche-openai/gpt-5.3-codex' },
      { label: 'GPT-5.3 Codex Spark', id: 'kkpinche-openai/gpt-5.3-codex-spark' },
      { label: 'GPT-5.4 (最新)', id: 'kkpinche-openai/gpt-5.4' }
    ];
    for (const e of openaiEntries) {
      MODEL_OPTIONS.push(e);
      console.log(`  ${MODEL_OPTIONS.length}) ${e.label}`);
    }
    console.log('');
  }

  // Claude models
  if (ENABLE_CLAUDE) {
    console.log(`${BOLD}Claude 系列：${NC}`);
    if (CLAUDE_MODELS_JSON.includes('claude-opus')) {
      MODEL_OPTIONS.push({ label: 'Claude Opus 4.6 (最强推理能力)', id: 'kkpinche-claude/claude-opus-4-6' });
      opusIndex = MODEL_OPTIONS.length;
      console.log(`  ${MODEL_OPTIONS.length}) Claude Opus 4.6 (最强推理能力)`);
    }
    if (CLAUDE_MODELS_JSON.includes('claude-sonnet-4-6')) {
      MODEL_OPTIONS.push({ label: 'Claude Sonnet 4.6 (新一代平衡)', id: 'kkpinche-claude/claude-sonnet-4-6' });
      console.log(`  ${MODEL_OPTIONS.length}) Claude Sonnet 4.6 (新一代平衡)`);
    }
    if (CLAUDE_MODELS_JSON.includes('claude-haiku')) {
      MODEL_OPTIONS.push({ label: 'Claude Haiku 4.5 (快速响应)', id: 'kkpinche-claude/claude-haiku-4-5-20251001' });
      console.log(`  ${MODEL_OPTIONS.length}) Claude Haiku 4.5 (快速响应)`);
    }
    console.log('');
  }

  // Gemini models
  if (ENABLE_GEMINI) {
    console.log(`${BOLD}Google Gemini 系列：${NC}`);
    const geminiEntries = [
      { label: 'Gemini 3.1 Pro Preview (最新)', id: 'google/gemini-3.1-pro-preview' },
      { label: 'Gemini 3 Pro Preview', id: 'google/gemini-3-pro-preview' },
      { label: 'Gemini 3 Flash Preview', id: 'google/gemini-3-flash-preview' },
      { label: 'Gemini 2.5 Pro', id: 'google/gemini-2.5-pro' },
      { label: 'Gemini 2.5 Flash', id: 'google/gemini-2.5-flash' },
      { label: 'Gemini 2.5 Flash Lite', id: 'google/gemini-2.5-flash-lite' }
    ];
    for (const e of geminiEntries) {
      MODEL_OPTIONS.push(e);
      console.log(`  ${MODEL_OPTIONS.length}) ${e.label}`);
    }
    console.log('');
  }

  const MAX_CHOICE = MODEL_OPTIONS.length;
  const DEFAULT_CHOICE = opusIndex > 0 ? opusIndex : 1;

  // If only Claude enabled and already chose primary, skip
  if (ENABLE_CLAUDE && !ENABLE_OPENAI && !ENABLE_GEMINI && CLAUDE_PRIMARY_MODEL) {
    PRIMARY_MODEL = CLAUDE_PRIMARY_MODEL;
    FALLBACK_MODELS = CLAUDE_FALLBACK_MODELS;
    return;
  }

  let PRIMARY_CHOICE;
  while (true) {
    let input = (await ask(`请选择主模型 [1-${MAX_CHOICE}，默认 ${DEFAULT_CHOICE}]: `)).trim();
    PRIMARY_CHOICE = parseInt(input || String(DEFAULT_CHOICE), 10);
    if (PRIMARY_CHOICE >= 1 && PRIMARY_CHOICE <= MAX_CHOICE) {
      PRIMARY_MODEL = MODEL_OPTIONS[PRIMARY_CHOICE - 1].id;
      break;
    }
    print.error(`请输入 1-${MAX_CHOICE}`);
  }

  // Step 9: Ask about fallback models
  print.step('是否设置备用模型？');
  console.log('');
  console.log('  1) 是，设置备用模型（推荐）');
  console.log('  2) 否，不设置备用模型');
  console.log('');

  let FALLBACK_OPTION;
  while (true) {
    let input = (await ask('请选择 [1-2，默认 1]: ')).trim();
    FALLBACK_OPTION = parseInt(input || '1', 10);
    if ([1,2].includes(FALLBACK_OPTION)) break;
    print.error('请输入 1 或 2');
  }

  if (FALLBACK_OPTION === 2) {
    FALLBACK_MODELS = '[]';
    return;
  }

  // Auto-include all other models as fallbacks
  const fallbackList = MODEL_OPTIONS
    .filter((_, i) => i !== PRIMARY_CHOICE - 1)
    .map(m => m.id);

  FALLBACK_MODELS = fallbackList.length > 0 ? JSON.stringify(fallbackList) : '[]';
}

// ──────────────────────────────────────────────────────────
// Step 10: Apply configuration
// ──────────────────────────────────────────────────────────

function applyConfig() {
  print.step('应用配置...');
  console.log('');

  // Set models.mode to merge
  process.stdout.write('  设置模型合并模式... ');
  if (run(`${CLI_BIN} config set models.mode merge`) !== null) {
    console.log(`${GREEN}✓${NC}`);
  } else {
    console.log(`${YELLOW}跳过${NC}`);
  }

  // Configure OpenAI
  if (ENABLE_OPENAI) {
    process.stdout.write('  设置 OpenAI/Codex 配置... ');
    const openaiConfig = JSON.stringify({
      baseUrl: 'https://api.gptclubapi.xyz/openai',
      apiKey: API_KEY,
      api: 'openai-responses',
      models: JSON.parse(OPENAI_MODELS_JSON)
    });
    const result = run(`${CLI_BIN} config set models.providers.kkpinche-openai --json ${shellJson(openaiConfig)}`);
    if (result !== null) {
      console.log(`${GREEN}✓${NC}`);
    } else {
      console.log(`${RED}✗${NC}`);
      print.error('设置 OpenAI 配置失败');
      process.exit(1);
    }
  }

  // Configure Claude
  if (ENABLE_CLAUDE) {
    process.stdout.write('  设置 Claude 配置... ');
    const claudeConfig = JSON.stringify({
      baseUrl: 'https://api.gptclubapi.xyz/api',
      apiKey: API_KEY,
      models: JSON.parse(CLAUDE_MODELS_JSON)
    });
    const result = run(`${CLI_BIN} config set models.providers.kkpinche-claude --json ${shellJson(claudeConfig)}`);
    if (result !== null) {
      console.log(`${GREEN}✓${NC}`);
    } else {
      console.log(`${RED}✗${NC}`);
      print.error('设置 Claude 配置失败');
      process.exit(1);
    }
  }

  // Configure Gemini
  if (ENABLE_GEMINI) {
    process.stdout.write('  设置 Gemini 配置... ');
    const geminiConfig = JSON.stringify({
      baseUrl: 'https://api.gptclubapi.xyz/gemini/v1beta',
      apiKey: API_KEY,
      api: 'google-generative-ai',
      models: JSON.parse(GEMINI_MODELS_JSON)
    });
    const result = run(`${CLI_BIN} config set models.providers.google --json ${shellJson(geminiConfig)}`);
    if (result !== null) {
      console.log(`${GREEN}✓${NC}`);
    } else {
      console.log(`${RED}✗${NC}`);
      print.error('设置 Gemini 配置失败');
      process.exit(1);
    }
  }

  // Set primary model
  process.stdout.write('  设置主模型... ');
  if (run(`${CLI_BIN} config set agents.defaults.model.primary "${PRIMARY_MODEL}"`) !== null) {
    console.log(`${GREEN}✓${NC}`);
  } else {
    console.log(`${RED}✗${NC}`);
    print.error('设置主模型失败');
    process.exit(1);
  }

  // Set fallback models
  if (FALLBACK_MODELS && FALLBACK_MODELS !== '[]') {
    process.stdout.write('  设置备用模型... ');
    if (run(`${CLI_BIN} config set agents.defaults.model.fallbacks --json ${shellJson(FALLBACK_MODELS)}`) !== null) {
      console.log(`${GREEN}✓${NC}`);
    } else {
      console.log(`${YELLOW}跳过${NC}`);
    }
  }

  // Set models allowlist (agents.defaults.models)
  process.stdout.write('  设置模型允许列表... ');
  const allowlist = {};
  if (ENABLE_OPENAI) {
    const openaiIds = ['gpt-5','gpt-5-codex','gpt-5-codex-mini','gpt-5.1','gpt-5.1-codex','gpt-5.1-codex-mini','gpt-5.1-codex-max','gpt-5.2','gpt-5.2-codex','gpt-5.3-codex','gpt-5.3-codex-spark','gpt-5.4'];
    for (const mid of openaiIds) allowlist[`kkpinche-openai/${mid}`] = {};
  }
  if (ENABLE_CLAUDE) {
    if (CLAUDE_MODELS_JSON.includes('claude-opus')) allowlist['kkpinche-claude/claude-opus-4-6'] = {};
    if (CLAUDE_MODELS_JSON.includes('claude-sonnet-4-6')) allowlist['kkpinche-claude/claude-sonnet-4-6'] = {};
    if (CLAUDE_MODELS_JSON.includes('claude-haiku')) allowlist['kkpinche-claude/claude-haiku-4-5-20251001'] = {};
  }
  if (ENABLE_GEMINI) {
    const geminiIds = ['gemini-3.1-pro-preview','gemini-3-pro-preview','gemini-3-flash-preview','gemini-2.5-pro','gemini-2.5-flash','gemini-2.5-flash-lite'];
    for (const mid of geminiIds) allowlist[`google/${mid}`] = {};
  }

  const allowlistJson = JSON.stringify(allowlist);
  if (run(`${CLI_BIN} config set agents.defaults.models --json ${shellJson(allowlistJson)}`) !== null) {
    console.log(`${GREEN}✓${NC}`);
  } else {
    console.log(`${YELLOW}跳过${NC}`);
  }
}

// ──────────────────────────────────────────────────────────
// Step 11: Verify configuration
// ───────────────────────────────────────────────────��──────

function verifyConfig() {
  print.step('验证配置...');
  console.log('');

  let verifyOk = true;

  if (ENABLE_OPENAI) {
    process.stdout.write('  检查 OpenAI 配置... ');
    if (run(`${CLI_BIN} config get models.providers.kkpinche-openai`) !== null) {
      console.log(`${GREEN}✓${NC}`);
    } else {
      console.log(`${RED}✗${NC}`);
      verifyOk = false;
    }
  }

  if (ENABLE_CLAUDE) {
    process.stdout.write('  检查 Claude 配置... ');
    if (run(`${CLI_BIN} config get models.providers.kkpinche-claude`) !== null) {
      console.log(`${GREEN}✓${NC}`);
    } else {
      console.log(`${RED}✗${NC}`);
      verifyOk = false;
    }
  }

  if (ENABLE_GEMINI) {
    process.stdout.write('  检查 Gemini 配置... ');
    if (run(`${CLI_BIN} config get models.providers.google`) !== null) {
      console.log(`${GREEN}✓${NC}`);
    } else {
      console.log(`${RED}✗${NC}`);
      verifyOk = false;
    }
  }

  process.stdout.write('  检查主模型配置... ');
  const currentPrimary = run(`${CLI_BIN} config get agents.defaults.model.primary`);
  if (currentPrimary !== null && currentPrimary.trim() === PRIMARY_MODEL) {
    console.log(`${GREEN}✓${NC}`);
  } else {
    console.log(`${RED}✗${NC}`);
    verifyOk = false;
  }

  console.log('');

  if (!verifyOk) {
    print.warning(`部分配置验证失败，请运行 ${CLI_BIN} doctor 检查详细信息`);
    console.log('');
  } else {
    print.success('所有配置验证通过！');
    console.log('');
  }
}

// ──────────────────────────────────────────────────────────
// Step 12: Show completion summary
// ──────────────────────────────────────────────────────────

function showSummary() {
  print.header('🎉 配置完成！');
  console.log('');
  console.log('已配置:');

  if (ENABLE_OPENAI) {
    console.log(`  ${GREEN}•${NC} OpenAI/Codex: https://api.gptclubapi.xyz/openai (${OPENAI_MODEL_COUNT}个模型)`);
  }
  if (ENABLE_CLAUDE) {
    console.log(`  ${GREEN}•${NC} Claude: https://api.gptclubapi.xyz/api (${CLAUDE_MODEL_COUNT}个模型)`);
  }
  if (ENABLE_GEMINI) {
    console.log(`  ${GREEN}•${NC} Gemini: https://api.gptclubapi.xyz/gemini/v1beta (${GEMINI_MODEL_COUNT}个模型)`);
  }
  console.log(`  ${GREEN}•${NC} API Key: ${API_KEY.substring(0, 15)}...`);
  console.log(`  ${GREEN}•${NC} 主模型: ${PRIMARY_MODEL}`);

  if (FALLBACK_MODELS && FALLBACK_MODELS !== '[]') {
    console.log(`  ${GREEN}•${NC} 备用模型: ${FALLBACK_MODELS}`);
  }

  console.log('');
  console.log('');
  console.log(`${YELLOW}Discord社区地址:${NC}`);
  console.log(`${CYAN}https://discord.gg/JFYQJrqzEZ${NC}`);
  console.log('');
  console.log(`${YELLOW}提示：首次使用建议运行 ${CLI_BIN} doctor 检查配置${NC}`);
  console.log('');
}

// ──────────────────────────────────────────────────────────
// Step 13: Optionally restart openclaw
// ──────────────────────────────────────────────────────────

function detectRunningMode() {
  if (isWin()) {
    // On Windows, use tasklist to detect
    const tasks = run('tasklist /FO CSV /NH') || '';
    // Check for openclaw/clawdbot processes
    if (tasks.includes(CLI_BIN)) {
      // Try to detect mode from wmic or just check process exists
      const wmicResult = run(`wmic process where "name like '%node%'" get commandline 2>NUL`) || '';
      if (wmicResult.includes(`${CLI_BIN} gateway`)) return 'gateway';
      if (wmicResult.includes(`${CLI_BIN} agent`)) return 'agent';
      // Fallback: check with PowerShell
      const psResult = run(`powershell -Command "Get-Process | Where-Object {$_.CommandLine -like '*${CLI_BIN}*'} | Select-Object CommandLine | Format-List"`) || '';
      if (psResult.includes('gateway')) return 'gateway';
      if (psResult.includes('agent')) return 'agent';
    }
    return '';
  } else {
    // Unix: use pgrep
    if (run(`pgrep -f "${CLI_BIN} gateway"`) !== null) return 'gateway';
    if (run(`pgrep -f "${CLI_BIN} agent"`) !== null) return 'agent';
    return '';
  }
}

function killProcess(mode) {
  if (isWin()) {
    // On Windows, use taskkill
    run(`taskkill /F /FI "WINDOWTITLE eq ${CLI_BIN}" 2>NUL`);
    // Also try killing node processes running the CLI
    run(`powershell -Command "Get-Process node -ErrorAction SilentlyContinue | Where-Object {$_.CommandLine -like '*${CLI_BIN} ${mode}*'} | Stop-Process -Force -ErrorAction SilentlyContinue"`);
  } else {
    run(`pkill -f "${CLI_BIN} ${mode}"`);
  }
}

function startProcess(mode) {
  if (isWin()) {
    try {
      const child = spawn('cmd', ['/c', 'start', '/B', CLI_BIN, mode], {
        detached: true,
        stdio: 'ignore',
        windowsHide: true
      });
      child.unref();
    } catch { /* ignore */ }
  } else {
    try {
      const child = spawn(CLI_BIN, [mode], {
        detached: true,
        stdio: ['ignore', 'ignore', 'ignore']
      });
      child.unref();
    } catch { /* ignore */ }
  }
}

async function restartClawdbot() {
  print.step(`正在重启 ${CLI_BIN}...`);

  const runningMode = detectRunningMode();

  if (!runningMode) {
    console.log(`  ${YELLOW}未检测到正在运行的 ${CLI_BIN} 进程${NC}`);
    console.log('');
    console.log(`请手动启动 ${CLI_BIN}：`);
    console.log(`  ${CYAN}${CLI_BIN} agent${NC}      - 启动 Agent 模式`);
    console.log(`  ${CYAN}${CLI_BIN} gateway${NC}   - 启动 Gateway 模式（支持 Telegram/Discord）`);
    console.log('');
    return;
  }

  // Stop existing process
  process.stdout.write(`  停止 ${CLI_BIN} ${runningMode}... `);
  killProcess(runningMode);
  // Wait 2 seconds
  await new Promise(r => setTimeout(r, 2000));
  console.log(`${GREEN}✓${NC}`);

  // Restart
  process.stdout.write(`  启动 ${CLI_BIN} ${runningMode}... `);
  startProcess(runningMode);
  // Wait 3 seconds
  await new Promise(r => setTimeout(r, 3000));

  // Check if started successfully
  const newMode = detectRunningMode();
  if (newMode === runningMode) {
    console.log(`${GREEN}✓${NC}`);
    console.log('');
    console.log(`${GREEN}${CLI_BIN} ${runningMode} 已重启成功！${NC}`);
  } else {
    console.log(`${RED}✗${NC}`);
    console.log('');
    print.warning('自动启动失败，请手动启动：');
    console.log(`  ${CYAN}${CLI_BIN} ${runningMode}${NC}`);
  }
  console.log('');
}

// ──────────────────────────────────────────────────────────
// Main flow
// ──────────────────────────────────────────────────────────

async function main() {
  // Clear screen (ignore errors)
  try { process.stdout.write('\x1Bc'); } catch {}

  print.header('🦞openclaw KKpinche API 多模型配置向导');
  console.log('');
  console.log('本向导将帮助你在你的🦞openclaw中配置 KKpinche 的多模型 API 服务。');
  console.log('支持 OpenAI/Codex、Claude、Google Gemini 三种模型类型。');
  console.log('你需要准备好你的 API Key（以 cr_ 开头）。');
  console.log('');

  // Step 1: Check openclaw installation
  print.step('检查 openclaw 安装...');
  checkClawdbot();
  const cliVersion = (run(`${CLI_BIN} --version`) || '').split('\n')[0];
  print.success(`已安装: openclaw (${cliVersion})`);

  // Step 2: Select model types
  await selectModelTypes();

  // Step 3-5: Claude configuration (before API key, matches original flow)
  if (ENABLE_CLAUDE) {
    await generateClaudeConfig();
  }

  // Step 6: Input API Key
  await inputApiKey();

  // Step 7: Generate model configs
  print.step('生成模型配置...');
  console.log('');

  if (ENABLE_OPENAI) {
    generateOpenaiConfig();
    print.success('OpenAI/Codex 配置已生成');
  }

  if (ENABLE_CLAUDE) {
    print.success('Claude 配置已生成');
  }

  if (ENABLE_GEMINI) {
    generateGeminiConfig();
    print.success('Gemini 配置已生成');
  }

  // Step 8-9: Select primary model
  await selectPrimaryModel();

  // Step 10: Apply config
  applyConfig();

  // Step 11: Verify config
  verifyConfig();

  // Step 12: Show summary
  showSummary();

  // Step 13: Optionally restart
  print.step(`是否立即重启 ${CLI_BIN} 使配置生效？`);
  console.log('');
  console.log(`  1) 是，自动重启 ${CLI_BIN}`);
  console.log('  2) 否，稍后我自己重启');
  console.log('');

  let restartChoice;
  while (true) {
    let input = (await ask('请选择 [1-2，默认 1]: ')).trim();
    restartChoice = parseInt(input || '1', 10);
    if ([1,2].includes(restartChoice)) break;
    print.error('请输入 1 或 2');
  }

  if (restartChoice === 1) {
    await restartClawdbot();
  } else {
    console.log('');
    console.log(`配置已保存，请重启 ${CLI_BIN} 使配置生效：`);
    console.log(`  ${CYAN}${CLI_BIN} agent${NC}      - 启动 Agent 模式`);
    console.log(`  ${CYAN}${CLI_BIN} gateway${NC}   - 启动 Gateway 模式（支持 Telegram/Discord）`);
    console.log('');
  }

  console.log(`${GREEN}配置向导已完成，祝你使用愉快！${NC}`);
  console.log('');

  rl.close();
}

main().catch(err => {
  console.error(`${RED}发生错误: ${err.message}${NC}`);
  rl.close();
  process.exit(1);
});
