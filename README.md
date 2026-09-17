# 一键启动器 · One-Click App Launcher (Windows)

一个桌面图标，按顺序自动打开你每天都要用的所有软件。
其中需要管理员权限的软件（那些每次启动都问「你要允许此应用对你的设备进行更改吗？」的），
**设置一次之后不再弹 UAC 确认框**。

- 纯 Windows 原生方案（PowerShell + 计划任务），无需安装任何第三方软件
- **不修改系统安全设置**，UAC 依然保持开启，只是让指定软件的启动走合法的高权限通道
- 软件清单写在 `apps.json` 里，加软件、改顺序、调间隔都只改这一个文件
- 配置和管理脚本都可以直接交给 AI 修改（见下方「让 AI 帮你改」）

---

## 效果

```
双击桌面「一键启动」
  → Steam            （先把 Steam 客户端拉起来，后面的 Steam 游戏要用）
  → VBridger
  → 酷狗音乐          （原本弹 UAC → 现在直接开）
  → Studio One 6     （原本弹 UAC → 现在直接开）
  → VTube Studio     （原本弹 UAC → 现在直接开）
  → 梅花机器人
  → 哔哩哔哩直播姬    （原本弹 UAC → 现在直接开）
全程 0 次 UAC 询问
```

---

## 原理（想搞懂的话看这里）

| 启动方式 | 会不会弹 UAC |
| --- | --- |
| 直接双击 `C:\Program Files\...\某软件.exe`（该程序要求管理员权限） | 会弹 |
| 用 `steam://rungameid/xxx` 启动 Steam 游戏 | 会弹（由 Steam 拉起游戏，游戏自己请求提权） |
| **通过「以最高权限运行」的计划任务启动该 exe** | **不弹** |

关键点：计划任务由 Windows 任务计划程序服务触发，进程直接拿到管理员令牌，
不需要向用户申请同意，所以 UAC 窗口根本不会出现。

本项目的做法：

1. `setup.cmd` 运行一次（只需要批准**这一次** UAC），把 `apps.json` 中
   `"needAdmin": true` 的软件各注册成一个计划任务（`OneClick_<id>`，以最高权限运行）。
   任务的触发器设在过去时间 —— 也就是说任务**永远不会自动运行**，只能被手动触发。
2. 每次双击桌面「一键启动」，`launcher.ps1` 就按顺序启动软件：
   `needAdmin` 的走计划任务（无 UAC），其余的按系统默认方式启动。
3. 万一某个任务没注册成功，会自动降级为直接启动（可能弹一次 UAC），不影响其他软件。

---

## 快速开始

1. 把这个文件夹复制到电脑上任意位置（例如 `D:\Tools\one-click-launcher`）。
   放在非系统盘、路径不含特殊字符更稳。
2. **先改 `apps.json`**，填上你要打开的软件（参考下面「apps.json 字段说明」，
   或者先运行一次 `scan-shortcuts.ps1` 自动生成草稿）。
3. 双击 **`setup.cmd`** → UAC 弹窗点「是」（只有这一次）。
   弹出的窗口会逐条显示结果，正常应全是 `OK: ...`。
4. 桌面出现「一键启动」图标即设置完成。双击它测试。

> 想卸载：双击 `uninstall.cmd`，会删掉所有 `OneClick_*` 计划任务和桌面快捷方式，
> 文件夹直接删掉即可，不留痕迹。

---

## apps.json 字段说明

顶层字段：

| 字段 | 必填 | 说明 |
| --- | --- | --- |
| `shortcutName` | 否 | 桌面快捷方式名称，默认「一键启动」 |
| `iconSource` | 否 | 快捷方式图标，格式 `"路径,索引"`，如 `"D:\\livehime\\livehime.exe,0"` |
| `defaultDelaySeconds` | 否 | 默认步进间隔秒数，默认 3 |
| `apps` | 是 | 软件清单数组，**按数组顺序启动** |

每个软件对象：

| 字段 | 必填 | 说明 |
| --- | --- | --- |
| `name` | 是 | 显示名称（也用于计划任务名，建议简短，中英文均可） |
| `id` | 否 | 计划任务名后缀，默认取 `name`；建议用英文，任务名即 `OneClick_<id>` |
| `type` | 是 | `exe` 可执行文件 / `url` 协议或网址（`steam://`、`https://`）/ `lnk` 快捷方式 |
| `target` | 是 | 路径或 URL，**支持环境变量**：`%ProgramFiles%`、`%ProgramFiles(x86)%`、`%USERPROFILE%` |
| `arguments` | 否 | 启动参数 |
| `needAdmin` | 否 | `true` 时走提权计划任务（不弹 UAC）。默认 `false` |
| `workingDirectory` | 否 | 启动时的工作目录。默认 = 该 exe 所在文件夹（**建议保持默认**，见下方 FAQ） |
| `delayAfterSeconds` | 否 | 这一项启动后等待多少秒再启动下一项 |
| `enabled` | 否 | `false` 可临时跳过该软件 |

注意事项：

- **只有 `type: "exe"` 才能免 UAC**。`steam://` 之类的协议启动是由 Steam 客户端拉起游戏的，
  游戏自身的提权请求绕不过去，所以这类程序要改成直接指向它的 exe，
  并把 Steam 客户端放在清单第一位先启动（示例见 `examples/vtuber-live-setup.json`）。
- 改了 `apps.json` 后，普通软件改完立即生效；**新增/修改了 `needAdmin: true` 的软件，
  需要重新双击 `setup.cmd` 一次**，把新的提权任务注册进去。
- JSON 里用双反斜杠写路径：`"C:\\Program Files\\App\\App.exe"`，或者用正斜杠 `"C:/Program Files/App/App.exe"`。

---

## 让 AI 帮你改（复制给任意 AI 助手）

`AI-PROMPT.md` 里有一段可以直接粘贴给 AI 的提示词。核心流程：

1. 让 AI 扫描你桌面的快捷方式，列出真实目标路径；
2. 告诉 AI 你要打开哪些、顺序、哪些启动时会弹 UAC；
3. AI 生成 `apps.json`；
4. 你双击 `setup.cmd` 完成一次注册，然后测试。

给 AI 写代码时必须注意的四条（否则会踩坑）：

- **`.ps1` 本仓库保持纯 ASCII（英文提示语）**。如果你想加中文提示，必须保存为
  **UTF-8 with BOM**，否则 Windows PowerShell 5.1 会把中文读成乱码，
  导致路径、任务名全部错乱（`$PSVersionTable` 里是 5.1 就是老版本 PowerShell）。
- 需要中文默认字符串（例如「一键启动」）时，用码点构造，源码才能保持 ASCII：
  `-join [char[]](0x4E00,0x952E,0x542F,0x52A8)`。
- **`.vbs` 必须保持纯 ASCII**（本仓库的 VBS 里没有任何中文），路径用
  `FileSystemObject` / `WScript.Shell` 在运行时解析，不要写死。
- 读 JSON 一定要 `Get-Content -Raw -Encoding UTF8`，否则 `apps.json` 里的中文软件名会乱码。

---

## 常见问题

**Q：双击桌面图标没反应？**
A：先检查 `apps.json` 是否为合法 JSON（用 VS Code 打开看有没有报错），
再确认脚本文件没有被编辑器改成带中文的 UTF-8 无 BOM 编码（本仓库脚本是纯 ASCII，
若你加了中文，必须存成 UTF-8 with BOM）。启动器是隐藏窗口运行的，
想看过程可以在命令行手动跑：
`powershell -NoProfile -ExecutionPolicy Bypass -File .\launcher.ps1`

**Q：某个软件还是弹 UAC？**
A：三个可能：
1. 它的 `type` 不是 `exe`（比如写成了 `steam://` 或 `.lnk`）；
2. `needAdmin` 没设成 `true`，或者新增后没有重新运行 `setup.cmd`；
3. 这个 exe 是「引导程序」，真正的程序是它启动的另一个进程（比如某些软件的
   launcher.exe / updater.exe），那种情况要把 `target` 改成真正的程序 exe。

**Q：`setup.cmd` 窗口一闪就没了 / 显示 FAIL？**
A：`setup-admin.ps1` 会把每一步结果写进同目录的 `setup.log`，打开看哪一条是 FAIL。

**Q：用了一段时间后，启动器文件夹里突然多出一大堆别的软件的文件？**
A：这是**工作目录**问题，也是本项目最容易踩的坑（v1 就踩过）。少数软件（自带更新器的、
绿色版/便携版启动器）解析自己的路径时用的是「当前目录」而不是自身 exe 位置。
如果启动它时不指定工作目录，它就会继承本启动器文件夹作为当前目录，
于是它的更新器会把整个新版本解压到 `one-click-launcher` 里面 —— 几百 MB 的文件凭空出现。

本仓库的脚本已经默认把工作目录设成**该 exe 自己所在的文件夹**（`launcher.ps1`
用 `Start-Process -WorkingDirectory`，`setup-admin.ps1` 用任务的 `WorkingDirectory`），
正常不会再发生。如果某个软件仍然乱写，就在 `apps.json` 里给它单独指定：
```json
{ "name": "某软件", "type": "exe", "target": "D:\\SomeApp\\launcher.exe",
  "workingDirectory": "D:\\SomeApp", "needAdmin": false }
```
排查方法：在可疑软件启动后，按住 Shift 右键该文件夹 → 「在此处打开 PowerShell」，
用 `Get-ChildItem | Sort-Object CreationTime -Descending | Select -First 10`
看有没有一批「创建时间几乎相同、修改时间却各不相同」的文件 —— 那就是被整目录复制进来的。

**Q：想开机自动启动？**
A：把桌面「一键启动」快捷方式复制到 `shell:startup`（Win+R 输入即可打开该文件夹）。
建议不要这么做，会让开机变慢；需要时手动点一下更可控。

**Q：软件启动太慢 / 顺序不对？**
A：调 `apps.json` 里的 `delayAfterSeconds`（单项）和 `defaultDelaySeconds`（全局），
比如 Steam、Adobe 系、DAW 这类大软件给 5~8 秒。

**Q：安全吗？**
A：这是 Windows 官方的机制（任务计划程序的「以最高权限运行」）。
可以随时用 `uninstall.cmd` 撤销。唯一需要留意的是：计划任务名统一带 `OneClick_` 前缀，
在「任务计划程序」里可以直接搜到并检查。

---

## 文件结构

```
one-click-launcher/
├── apps.json              # 软件清单（你主要改这个）
├── launcher.ps1           # 启动器主逻辑
├── setup-admin.ps1        # 注册提权计划任务 + 创建桌面快捷方式（管理员，跑一次）
├── uninstall.ps1          # 卸载：删除任务和快捷方式
├── scan-shortcuts.ps1     # 扫描桌面快捷方式，生成 apps.json 草稿
├── run-hidden.vbs         # 隐藏窗口运行 ps1（桌面快捷方式调用它）
├── run-elevated.vbs       # 以管理员运行 ps1（setup.cmd / uninstall.cmd 调用它）
├── setup.cmd              # 一键安装入口
├── uninstall.cmd          # 一键卸载入口
├── AI-PROMPT.md           # 给 AI 的提示词模板
└── examples/
    └── vtuber-live-setup.json   # 示例：VTuber/直播环境（7 个软件）
```

---

## 已知限制

- 仅支持 Windows 10 / 11（依赖 PowerShell 5.1+ 与任务计划程序）。
- 被"引导程序"二次拉起的软件可能需要特殊处理（见常见问题）。
- 部分带反作弊的在线游戏**不建议**用管理员权限启动（可能被判定异常），
  这类游戏请保持 `needAdmin: false`。
- 环境变量替换只支持 Windows 标准变量，不支持自定义变量语法。

## English (short)

A tiny Windows launcher: one desktop shortcut opens all your daily apps in order, and apps
that normally trigger a UAC prompt are launched through a "run with highest privileges"
scheduled task, so no UAC popup appears. Pure PowerShell + Task Scheduler, nothing to install,
nothing about your security settings is changed. Edit `apps.json`, run `setup.cmd` once,
then double-click the shortcut. See `AI-PROMPT.md` to let an AI adapt it to your own machine.

## License

MIT — 见 [LICENSE](LICENSE)。随意修改、分发。
