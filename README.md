# Codex 历史记录侧边栏修复脚本

这是一套可分享的 Windows 脚本，用来修复 Codex 桌面端在切换 `provider` 之后，侧边栏历史会话突然“像没了一样”的情况。

## 适用场景

如果你遇到的是下面这种情况，这套脚本通常有帮助：

- 历史聊天其实还在，但左侧列表突然只剩很少几条
- 切换过 `provider` 之后，旧会话列表消失
- 重新打开 Codex 后，有时能看到，有时又看不到

这套脚本修的是“线程的 `model_provider` 与当前 provider 不一致，导致列表显示受过滤影响”这一类问题。

它不是数据恢复工具。如果数据库里的历史真的已经被删除，这个脚本无法凭空找回。

## 已做的脱敏处理

这份分享版没有写死任何个人用户名、个人目录或业务项目路径。

脚本按下面顺序定位 Codex 数据目录：

1. 你手动传入的 `-CodexHome`
2. 环境变量 `CODEX_HOME`
3. 默认路径 `%USERPROFILE%\\.codex`

也就是说，别人拿到这套脚本后，不需要把脚本里改成你的用户名路径。

## 文件说明

- `repair-codex-history.ps1`
  - 主脚本
- `repair-codex-history.cmd`
  - 双击可运行的稳妥版
- `repair-codex-history-refresh.cmd`
  - 双击可运行的强制刷新版

## 使用方法

### 方法一：直接双击

推荐先双击：

- `repair-codex-history.cmd`

它会：

- 自动读取当前机器的 Codex 配置
- 备份 `state_5.sqlite`
- 把有用户消息的线程统一修正到当前 `model_provider`

这个版本不会主动重启 Codex 后端，所以更稳，不容易把界面瞬间切到报错页。

### 方法二：需要立即刷新界面时

如果修完后你想立刻强制刷新，可以双击：

- `repair-codex-history-refresh.cmd`

这个版本会尝试重启 Codex 的 `app-server`。执行时界面可能会短暂出现报错页，随后恢复；如果没有自动恢复，点一下“重新加载”或者手动重开 Codex 即可。

## PowerShell 手动运行示例

### 用当前配置里的 provider 修复

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\repair-codex-history.ps1
```

### 指定 provider 修复

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\repair-codex-history.ps1 -Provider right_code
```

### 指定自定义 Codex 数据目录

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\repair-codex-history.ps1 -CodexHome D:\Somewhere\.codex
```

### 修完后顺手重启后端

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\repair-codex-history.ps1 -RestartBackend
```

## 脚本实际做了什么

脚本会执行下面这些动作：

1. 定位 `config.toml` 和 `state_5.sqlite`
2. 读取当前 `model_provider`
3. 先备份数据库，备份文件名形如：

```text
state_5.sqlite.provider-fix-20260421-153000.bak
```

4. 更新 `threads` 表，把满足下面条件的线程改成当前 provider：

- `has_user_event = 1`
- `model_provider` 为空
- 或 `model_provider` 与当前 provider 不同

5. 输出修复前后的 provider 分布

## 关于 `disable_response_storage`

如果脚本检测到 `config.toml` 里是：

```toml
disable_response_storage = true
```

它会给出警告。

这通常不是“切换 provider 后侧边栏历史不见了”的主因，但一般也不建议长期开着，因为它可能增加后续持久化不完整、排查困难之类的风险。

## 运行要求

- Windows
- 已安装 Codex 桌面端
- 本机有 Python，且 `python` 或 `py` 可以在命令行里直接运行

## 风险说明

- 脚本会先自动备份数据库，再进行修改
- `refresh` 版本会主动重启 Codex 后端，界面短暂闪成报错页是正常现象
- 如果你的问题根本不是 provider 过滤导致的，这个脚本可能不会带来明显变化

## 分享建议

如果你要把这套脚本发给别人，建议连同整个目录一起发，让对方至少拿到：

- `repair-codex-history.ps1`
- `repair-codex-history.cmd`
- `repair-codex-history-refresh.cmd`
- `README.md`
