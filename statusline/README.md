# statusline

Claude Code 自定义状态栏脚本（Windows PowerShell）。

## 效果预览

```
🤖 Claude Opus 4 ⚡max 🚀 | 📊 23.5% (47k/200k) | 💬 in:42k out:5.2k | 🎯 hit:89% ⏳3m12s | 💰 $0.32
🔧 3r/7c(Read:4) | ✏ +45 -12 | ⏱ 2m30s(API:65%) | 🌿 main 🔀#1234 ✓ | 📁 C:\U~\m~\p~\toolbox
🚦 5h:34% 7d:62% | 👾 ◐Search for tests(12s) [2/3] | ✅ ▸写测试 2/5
```

2-3 行动态状态信息：

| 行 | 内容 |
|----|------|
| 第一行 | 模型名称+Effort+快速模式 · 上下文使用率 · Token 统计 · 缓存命中率+TTL · 费用 |
| 第二行 | 工具调用统计 · 代码改动行数 · 会话时长 · Git 分支+PR · 当前目录 |
| 第三行（动态） | Rate Limit 配额 · Agent 状态 · TODO 进度 |

第三行在无数据时自动隐藏。

## 特性

- **Effort Level** — 模型名后显示当前思考力度（⚡max/xhigh/high/medium/low）
- **Fast Mode** — 开启 `/fast` 快速模式时显示 🚀
- **Prompt Cache TTL** — 缓存剩余时间倒计时（5分钟 TTL）
- **Rate Limit** — 5小时/7天配额使用率，颜色分级预警
- **PR 徽章** — 当前分支的 PR 号 + 评审状态（✓通过/✗待改/✎草稿/○待审）
- **Agent 状态** — 运行中的 subagent 描述、耗时、完成进度 [done/total]
- **TODO 进度** — 当前执行中的任务名 + 完成数/总数
- 上下文使用率颜色分级（绿 ≤50% → 黄 ≤80% → 红 >80%）
- 路径智能缩写（`C:\Users\mirai\projects\toolbox` → `C:\U~\m~\p~\toolbox`）
- 直接读取 `.git/HEAD` 获取分支名，无需调用 git 命令
- 解析 transcript 文件统计工具调用、Agent、TODO 状态

## 颜色分级

| 指标 | 绿色 | 黄色 | 红色 |
|------|------|------|------|
| 上下文 | ≤50% | 50-80% | >80% |
| Cache TTL | >3min | 1-3min | <1min |
| Rate Limit | <60% | 60-80% | >80% |
| Effort | high | max/xhigh | — |
| PR 评审 | approved ✓ | pending ○ | changes_requested ✗ |

## 安装

1. 将 `statusline.ps1` 复制到 `~/.claude/` 目录：

```powershell
Copy-Item statusline.ps1 $env:USERPROFILE\.claude\
```

2. 编辑 `~/.claude/settings.json`，添加 statusLine 配置：

```json
{
  "statusLine": {
    "type": "command",
    "command": "powershell -ExecutionPolicy Bypass -File C:/Users/<你的用户名>/.claude/statusline.ps1",
    "refreshInterval": 3
  }
}
```

> `refreshInterval`（秒）让状态栏定时刷新。因为脚本含**缓存 TTL 倒计时**和 **Agent 耗时**等时间敏感数据，会话空闲时事件驱动不触发，加上它才能保证倒计时和后台 subagent 状态实时更新。不需要可省略。

3. 重启 Claude Code 即可生效。

## 要求

- Windows PowerShell 5.1+ 或 PowerShell 7+
- Claude Code CLI
