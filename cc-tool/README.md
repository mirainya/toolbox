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
# 按提示输入 ANTHROPIC_BASE_URL 和 ANTHROPIC_AUTH_TOKEN
```

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
  }
}
```

与 Claude CLI `--settings` 参数兼容，也可以手动创建/编辑 JSON 文件。

## 系统要求

- Windows + PowerShell 5.1+
- 已安装 [Claude CLI](https://docs.anthropic.com/en/docs/claude-code)

## 原理

利用 Claude CLI 的 `claude --settings <path>` 参数，将不同的 API 配置存储为独立的 JSON 文件，启动时加载指定配置。
