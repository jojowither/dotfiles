# dotfiles

換電腦／開新 server 時一鍵建立初始開發環境。

```bash
git clone <你的 repo> ~/dotfiles && cd ~/dotfiles
./bootstrap.sh --dry-run   # 先看會做什麼
./bootstrap.sh
```

**設定是用「複製」的，不是連結。** repo 只是新環境的起點：設定檔複製過去之後，每台各自修改、各自發展，改了不會影響 repo 或別台；安裝程式自己往 `~/.zshrc` 加東西也只影響那一台。

| 指令 | 用途 |
|---|---|
| `./bootstrap.sh` | 裝工具、複製設定。這台已經有的設定檔不覆蓋，所以可以放心重跑 |
| `./bootstrap.sh --diff` | repo 更新後，看這台和 repo 哪些設定不一樣、差在哪，再自己決定要不要手動跟上 |
| `./bootstrap.sh --force` | 和 repo 不同的設定檔也用 repo 版本覆蓋（舊的備份成 `*.bak.<時間>`） |
| `./bootstrap.sh --backup` | 反過來：某台試出喜歡的設定，存回 repo 當下一台的初始設定。之後先 `git diff` 挑過再 commit |

之前用舊版（symlink）裝過的電腦：`git pull` 後重跑一次 `./bootstrap.sh`，連結會自動換成複製，內容不變。

## 盤點

| 類別 | 工具 | Mac | Linux 桌機 | Server | 怎麼裝 |
|---|---|:-:|:-:|:-:|---|
| Shell | zsh + autosuggestions / syntax-highlighting / completions | ✓ | ✓ | ✓ | git clone（取代 Oh My Zsh） |
| Prompt | Starship（取代 Powerlevel10k） | ✓ | ✓ | ✓ | brew / 官方腳本，裝到 `~/.local/bin` |
| CLI | fzf、zoxide、ripgrep、fd、bat、eza、btop、jq | ✓ | ✓ | ✓ | brew / apt·dnf·pacman |
| CLI | lazygit、git-delta、tldr | ✓ | △ | △ | Mac: brew；Linux 只有 pacman 會自動裝 |
| 終端機 | Ghostty | ✓ | — | — | brew cask |
| Agent | Herdr app | ✓ | — | — | brew cask `herdr-app` |
| Agent | herdr-core（`hc`） | ✓ | ✓ | ✓ | 官方腳本，裝到 `~/.local/bin`，之後由 Herdr 自動更新 |
| Agent | Claude Code（`claude`） | ✓ | ✓ | ✓ | 官方 native installer，裝到 `~/.local/bin`，會自動更新 |
| Agent | Claude plugins：mattpocock-skills | ✓ | ✓ | ✓ | `claude/plugins.txt`，裝好後自動更新 |
| 字型 | JetBrainsMono / Meslo Nerd Font | ✓ | — | — | brew cask（server 不需要，字型由本機終端負責） |
| 編輯器 | VS Code + 插件 | ✓ | ✓ | — | cask；插件清單在 `vscode/extensions.txt` |
| 系統 | LinearMouse、Karabiner-Elements | ✓ | — | — | brew cask，設定從 `mac/` 複製回去 |
| 系統 | RunCat Neo | ✓ | — | — | App Store（`mas`，需先登入） |

VS Code 插件：rainbow-csv、drawio、markdown-preview-enhanced、material-icon-theme、pdf。

## 檔案

以下設定都會複製到右邊的位置：

```
bootstrap.sh            主腳本（自動判斷 macOS / Linux，可重複執行）
Brewfile                Mac 套件清單
zsh/.zshrc              → ~/.zshrc
config/starship.toml    → ~/.config/starship.toml
config/ghostty/config   → ~/.config/ghostty/config（Mac）
vscode/                 插件清單＋（backup 後）settings / keybindings
mac/                    Karabiner、LinearMouse 設定（用 --backup 從某台匯出；綁的是那台的鍵盤和滑鼠型號）
claude/statusline.py    → ~/.claude/statusline.py（並寫進 ~/.claude/settings.json 的 statusLine）
claude/CLAUDE.md        → ~/.claude/CLAUDE.md 所有專案共用的 Claude 習慣（含何時提醒用哪個 skill）
claude/plugins.txt      Claude Code plugins 清單，bootstrap 用 claude plugin install 安裝
herdr/mods/status-bar   → ~/.config/herdr-app/mods/ 底部狀態列：分支、agent、Claude 用量、reset 時間、用完預估
herdr/mods/agents-plus  → ~/.config/herdr-app/mods/ 內建 agents 列表的複製版（複製自 Herdr agents mod 0.1.16，Herdr 更新後可能要重新同步），多一行：模型 · ctx % · +改動行數
herdr/themes/           → ~/.config/herdr-app/themes/ Catppuccin Mocha
herdr/layouts/mine.json → ~/.config/herdr-app/layouts/ 主題、字型、狀態列都設在這裡
```

## Herdr

- 第一次在新電腦打開 Herdr 後，按 `⌘⇧L` 切到 **mine** 版面：Catppuccin Mocha 主題、MesloLGS Nerd Font、自訂狀態列。
- 狀態列右側的 Claude 用量和 Claude Code 的 `/usage` 一樣（目前 session、本週）。來源是 `claude/statusline.py`：它是 Claude Code 的 status line，每次更新時把官方的 `rate_limits` 存到 `~/.cache/claude-usage/rate_limits.json`，狀態列每 20 秒讀一次。所以要有 Claude Code 在跑、送過訊息，數字才會更新；只有 Pro / Max 訂閱才有這份資料。
- 用完預估：依最近的用量速度推算。撐得到 reset 顯示 `on track`，撐不到顯示 `limit ~14:20`；取樣不夠（5h 少於 10 分鐘、week 少於 2 小時）就不顯示。取樣存在 `~/.cache/claude-usage/history.json`。
- Agents 列表：每個 Claude agent 下面多一行 `Opus 5.5 · ctx 42% · +120 −30`（ctx ≥60% 黃、≥80% 紅）。靠 Herdr 設在終端機裡的 `$HC_TERMINAL_ID` 對應，所以只有在 Herdr 裡跑的 Claude 才有；資料在 `~/.cache/claude-usage/agents/`。
- 提醒：Dock 圖示的紅色數字是在等你的 agent 數；用量超過 80%、95% 各跳一次通知。agent 卡住或做完的音效和通知是 Herdr 內建的（Settings → Alerts）。
- Herdr 一律裝最新版。`agents-plus` 和 `mine.json` 是從 0.1.16 複製的：bootstrap 和 `--diff` 最後會檢查自訂 mod 在目前版本能不能載入，版本不同也會提醒，新版內建若有新功能要自己合併。
- 改狀態列：直接改這台的 `~/.config/herdr-app/mods/status-bar/main.js`，Herdr 會自動重新載入；跑 `herdr-app check ~/.config/herdr-app/mods/status-bar` 可檢查有沒有寫錯。想讓下一台也用，再 `./bootstrap.sh --backup` 存回 repo。

## Claude Code skills（mattpocock-skills）

- 有些 skill 會自動觸發（`tdd`、`diagnosing-bugs`、`code-review`、`pr`…），有些要自己打指令。手動的那些，`claude/CLAUDE.md` 會請 Claude 在適合的時候提醒你。
- 每個 repo 第一次用之前跑一次 `/setup-matt-pocock-skills`（設定 issue tracker、標籤、文件位置）。

| 時機 | 指令 |
|---|---|
| 開始做新功能、需求還模糊 | `/grill-with-docs`（非程式：`/grill-me`） |
| 討論完，整理成規格 / 拆工作 | `/to-spec` → `/to-tickets` → `/implement` |
| 超大工作，跨好幾個 session | `/wayfinder` |
| 程式越來越亂 | `/improve-codebase-architecture` |
| 換 session 接手 / 做完回顧 | `/handoff`、`/retro` |
| 不知道用哪個 | `/ask-matt` |

## 機器專屬設定

`~/.zshrc` 是各台自己的檔案，直接改就好。只有 API key 這類不能進 repo 的東西建議放 `~/.zshrc.local`（`.zshrc` 會自動載入），之後跑 `--backup` 存回 repo 時才不會被一起帶進去。例如：

```zsh
export OPENAI_API_KEY="..."                # API key
export PATH="$HOME/some-tool/bin:$PATH"     # 只有這台才裝的工具
export HTTPS_PROXY="http://proxy.example:8080"  # 公司網路
```
