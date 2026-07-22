# cc - Claude CLI 多配置切换工具

轻量级 PowerShell 工具，为 Claude CLI 提供多 API 配置管理和一键切换能力。

## 适用场景

- 拥有多个 Claude API 中转/代理服务
- 需要在不同 `ANTHROPIC_BASE_URL` + `ANTHROPIC_AUTH_TOKEN` 之间快速切换
- 不想每次手动改环境变量或配置文件

## 安装

```powershell
# 下载后在 cc-tool 目录中执行
.\install.ps1

# 重新加载 Profile
. $PROFILE
```

## 卸载

```powershell
.\uninstall.ps1
. $PROFILE
```

## 使用方法

### 添加配置

```powershell
cc add myapi
# 按提示输入 ANTHROPIC_BASE_URL、ANTHROPIC_AUTH_TOKEN
# 可选：输入该站支持的模型列表（逗号分隔，留空则跳过）
```

模型列表示例输入：`claude-opus-4-8[1m], claude-sonnet-4-5`

### 交互式启动（推荐）

```powershell
cc
```

输出示例：
```
  Select a profile:

  [1] myapi    - api.example.com
  [2] backup   - api2.example.com

  Enter number (1-2): 1

  Launching claude with profile: myapi
```

### 直接指定配置启动

```powershell
cc myapi
```

### YOLO 模式（跳过权限确认）

加 `-Yolo` 开关启动时会带上 `--dangerously-skip-permissions`，跳过所有工具调用的逐个确认：

```powershell
cc myapi -Yolo     # 指定配置 + YOLO
cc -Yolo           # 交互选单 + YOLO
```

> ⚠️ YOLO 模式下读写文件、执行命令都不再弹窗确认，请在可信目录中使用。

### 选择模型

若配置里存了 `models` 列表，启动时会自动处理：

- **多个模型** → 弹菜单让你选（数字选择，免手打 `claude-opus-4-8[1m]` 这类带特殊字符的模型名）
- **只有一个** → 自动使用，不打扰
- **没有 models 字段** → 跳过，使用中转站默认模型（老配置完全兼容）

选中后会带上 `--model <name>` 启动。输出示例：
```
  Select a model:

  [1] claude-opus-4-8[1m]
  [2] claude-sonnet-4-5

  Enter number (1-2): 1

  Launching claude with profile: myapi (model: claude-opus-4-8[1m])
```

### 继续上次会话

加 `-c`（或 `-Continue`）开关，带上 `--continue` 继续最近一次对话：

```powershell
cc myapi -c        # 指定配置 + 继续会话
cc -c              # 交互选单 + 继续会话
```

### 开关组合

`-c` 和 `-Yolo` 可自由组合：

```powershell
cc myapi -c -Yolo  # 继续会话 + YOLO
cc -c -Yolo        # 交互选单 + 继续会话 + YOLO
```


### 查看所有配置

```powershell
cc list
```

### 删除配置

```powershell
cc remove myapi
```

## 文件结构

```
~/.claude/
├── cc.ps1              # 主脚本（由 install.ps1 安装）
└── profiles/           # 配置目录
    ├── myapi.json
    └── backup.json
```

每个配置文件格式：
```json
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "sk-xxx",
    "ANTHROPIC_BASE_URL": "https://api.example.com"
  },
  "models": [
    "claude-opus-4-8[1m]",
    "claude-sonnet-4-5"
  ]
}
```

`env` 与 Claude CLI `--settings` 参数兼容；`models` 是本工具的扩展字段，Claude CLI 会静默忽略它，不影响启动。也可以手动创建/编辑 JSON 文件。


## 系统要求

- Windows + PowerShell 5.1+
- 已安装 [Claude CLI](https://docs.anthropic.com/en/docs/claude-code)

## 原理

利用 Claude CLI 的 `claude --settings <path>` 参数，将不同的 API 配置存储为独立的 JSON 文件，启动时加载指定配置。模型选择通过 `--model` 参数传入，会话延续通过 `--continue` 参数实现。
