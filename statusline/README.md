# statusline

Claude Code 自定义状态栏脚本（Windows PowerShell）。

## 效果预览

```
🤖 Claude Opus 4 | 📊 23.5% (47k/200k) | 💬 in:42k out:5.2k | 🎯 hit:89% | 💰 $0.32
🔧 3r/7c(Read:4) | ✏ +45 -12 | ⏱ 2m30s(API:65%) | 🌿 main | 📁 C:\U~\m~\p~\toolbox
```

两行状态信息：

| 行 | 内容 |
|----|------|
| 第一行 | 模型名称 · 上下文使用率 · Token 统计 · 缓存命中率 · 费用 |
| 第二行 | 工具调用统计 · 代码改动行数 · 会话时长 · Git 分支 · 当前目录 |

## 特性

- 上下文使用率颜色分级（绿 ≤50% → 黄 ≤80% → 红 >80%）
- 路径智能缩写（`C:\Users\mirai\projects\toolbox` → `C:\U~\m~\p~\toolbox`）
- 直接读取 `.git/HEAD` 获取分支名，无需调用 git 命令
- 解析 transcript 文件统计工具调用次数及最常用工具

## 安装

1. 将 `statusline.ps1` 复制到 `~/.claude/` 目录：

```powershell
Copy-Item statusline.ps1 $env:USERPROFILE\.claude\
```

2. 编辑 `~/.claude/settings.json`，添加 statusline 配置：

```json
{
  "statusline": {
    "command": "powershell -ExecutionPolicy Bypass -File C:/Users/<你的用户名>/.claude/statusline.ps1"
  }
}
```

3. 重启 Claude Code 即可生效。

## 要求

- Windows PowerShell 5.1+ 或 PowerShell 7+
- Claude Code CLI
