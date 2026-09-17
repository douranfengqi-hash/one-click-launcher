# 给 AI 的提示词模板（复制下面整段，粘贴给任意 AI 助手）

> 用法：把本文件内容整段复制给你的 AI（Cursor / Claude Code / WorkBuddy / ChatGPT 等），
> 它会自动帮你把这份启动器改造成适合你自己电脑的版本。

---

我需要一个 Windows 上的「一键打开多个软件」启动器，避免每天手动点一堆桌面快捷方式，
并且要解决「每次启动都弹 UAC（你要允许此应用对你的设备进行更改吗）」的问题。

请先阅读这份启动器的实现（仓库：`<把仓库地址填在这里>`，或直接读我给你的这些文件）：
`README.md`、`apps.json`、`launcher.ps1`、`setup-admin.ps1`、`run-hidden.vbs`、`run-elevated.vbs`。

然后请按以下步骤帮我：

1. **摸清我电脑上的实际软件**
   - 扫描我的桌面（`[Environment]::GetFolderPath('Desktop')`）和公共桌面 `C:\Users\Public\Desktop`
   - 列出所有 `.lnk` 和 `.url` 快捷方式的**名称 + 真实目标路径**
     （`.lnk` 用 `WScript.Shell` 的 `CreateShortcut` 读 `TargetPath`/`Arguments`；
      `.url` 是文本文件，读 `URL=` 那一行，可能是 `steam://` 这类协议）
   - 也可以直接运行仓库里的 `scan-shortcuts.ps1` 生成草稿

2. **问我确认需求**：要打开哪些软件、启动顺序、每步间隔几秒、
   哪些软件启动时会弹 UAC（= 需要 `needAdmin: true`）。

3. **生成 `apps.json`**（字段说明见 README）：
   - 需要免 UAC 的软件必须是 `type: "exe"` 且 `needAdmin: true`，`target` 指向真正的 exe
   - 路径能用环境变量就用（`%ProgramFiles%`、`%ProgramFiles(x86)%`、`%USERPROFILE%`）
   - Steam 游戏注意：`steam://rungameid/xxx` 会由 Steam 启动，绕不过 UAC；
     要改成直接指向游戏 exe（在 `steamapps\common\<游戏名>\` 下），
     并把 Steam 客户端本身放到清单第一位（`steam://open/main`，间隔 6~8 秒）

4. **提示我完成安装**：双击 `setup.cmd` 并在 UAC 点一次「是」，
   然后双击桌面快捷方式测试；如果某条显示 FAIL，
   读同目录的 `setup.log` 定位问题。

## 修改脚本时必须遵守的硬性约束

1. **本仓库的 `.ps1` 一律保持纯 ASCII**（提示语用英文），这样任何编码环境下都不会乱码。
   如果你确实要加中文提示，必须保存为 **UTF-8 with BOM**：
   Windows PowerShell 5.1（PowerShell 6/7 之前）读取无 BOM 的 UTF-8 文件时会按本地 ANSI 编码
   解析，中文全部变乱码，路径和任务名会错乱、脚本直接失效。
   如果工具只能写出无 BOM 的 UTF-8，请补一句转换：
   ```powershell
   $raw = [System.IO.File]::ReadAllText($path, [System.Text.UTF8Encoding]::new($false))
   [System.IO.File]::WriteAllText($path, $raw, [System.Text.UTF8Encoding]::new($true))
   ```
2. 需要在源码里表示中文默认值（例如「一键启动」）时，用码点构造，保持源码 ASCII：
   `-join [char[]](0x4E00,0x952E,0x542F,0x52A8)`。
3. **`.vbs` 文件必须保持纯 ASCII**，不要写中文（VBS 引擎对 UTF-8 支持很差）。
   需要路径时用 `FileSystemObject.GetParentFolderName(WScript.ScriptFullName)` 动态获取，
   或用 `shell.ExpandEnvironmentStrings("%USERPROFILE%")` 展开，不要写死绝对路径。
4. **读 JSON 配置时显式指定编码**：`Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json`，
   否则中文一样会乱码。
5. 计划任务的**触发器要设在过去的时间**（例如 `(Get-Date).AddDays(-365)`），
   这样任务只保留「手动 `schtasks /Run` 触发」的能力，不会开机/定时自动运行。
6. 需要管理员权限的一步（注册计划任务、写公共桌面）用
   `Shell.Application` 的 `ShellExecute ... "runas"` 触发**单次** UAC，
   不要要求用户关闭 UAC。
7. 运行环境是 **Windows 10/11 + Windows PowerShell 5.1**，
   不要使用 PowerShell 7 专属语法（`??`、三元运算符 `?:`、`-Parallel` 等）。

## 交付标准

- 我的桌面上出现一个图标，双击后所有软件按顺序打开；
- 标记为 `needAdmin: true` 的软件全程不弹 UAC；
- 过程中不修改系统安全设置、不装第三方软件；
- 不满意可以一键卸载（`uninstall.cmd`）。
