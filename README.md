# dotfiles

換電腦／開新 server 時一鍵重建開發環境。

```bash
git clone <你的 repo> ~/dotfiles && cd ~/dotfiles
./bootstrap.sh --dry-run   # 先看會做什麼
./bootstrap.sh
```

舊電腦上先跑 `./bootstrap.sh --backup`，把 Karabiner / LinearMouse / VS Code 設定匯出進 repo，再 commit。

## 盤點

| 類別 | 工具 | Mac | Linux 桌機 | Server | 怎麼裝 |
|---|---|:-:|:-:|:-:|---|
| Shell | zsh + autosuggestions / syntax-highlighting / completions | ✓ | ✓ | ✓ | git clone（取代 Oh My Zsh） |
| Prompt | Starship（取代 Powerlevel10k） | ✓ | ✓ | ✓ | brew / 官方腳本，裝到 `~/.local/bin` |
| CLI | fzf、zoxide、ripgrep、fd、bat、eza、btop、jq | ✓ | ✓ | ✓ | brew / apt·dnf·pacman |
| CLI | lazygit、git-delta、tldr | ✓ | △ | △ | Mac: brew；Linux 只有 pacman 會自動裝 |
| 終端機 | Ghostty（推薦）、iTerm2（現用） | ✓ | — | — | brew cask |
| Agent | Herdr app | ✓ | — | — | brew cask `herdr-app` |
| Agent | herdr-core（`hc`） | ✓ | ✓ | ✓ | 官方腳本，裝到 `~/.local/bin`，之後由 Herdr 自動更新 |
| 字型 | JetBrainsMono / Meslo Nerd Font | ✓ | — | — | brew cask（server 不需要，字型由本機終端負責） |
| 編輯器 | VS Code + 插件 | ✓ | ✓ | — | cask；插件清單在 `vscode/extensions.txt` |
| 系統 | LinearMouse、Karabiner-Elements | ✓ | — | — | brew cask，設定從 `mac/` 複製回去 |
| 系統 | RunCat Neo | ✓ | — | — | App Store（`mas`，需先登入） |

VS Code 插件：rainbow-csv、drawio、markdown-preview-enhanced、material-icon-theme、pdf。

## 檔案

```
bootstrap.sh            主腳本（自動判斷 macOS / Linux，可重複執行）
Brewfile                Mac 套件清單
zsh/.zshrc              → ~/.zshrc（symlink）
config/starship.toml    → ~/.config/starship.toml
config/ghostty/config   → ~/.config/ghostty/config（Mac）
vscode/                 插件清單＋（backup 後）settings / keybindings
mac/                    Karabiner、LinearMouse 設定（backup 後產生）
claude/statusline.py    → ~/.claude/statusline.py（symlink，並寫進 ~/.claude/settings.json 的 statusLine）
herdr/mods/status-bar   → ~/.config/herdr-app/mods/（symlink）底部狀態列：分支、agent、Claude 用量
herdr/themes/           → ~/.config/herdr-app/themes/（symlink）Catppuccin Mocha
herdr/layouts/mine.json → ~/.config/herdr-app/layouts/（複製）主題、字型、狀態列都設在這裡
```

## Herdr

- 第一次在新電腦打開 Herdr 後，按 `⌘⇧L` 切到 **mine** 版面：Catppuccin Mocha 主題、MesloLGS Nerd Font、自訂狀態列。
- 狀態列右側的 Claude 用量和 Claude Code 的 `/usage` 一樣（目前 session、本週）。來源是 `claude/statusline.py`：它是 Claude Code 的 status line，每次更新時把官方的 `rate_limits` 存到 `~/.cache/claude-usage/rate_limits.json`，狀態列每 20 秒讀一次。所以要有 Claude Code 在跑、送過訊息，數字才會更新；只有 Pro / Max 訂閱才有這份資料。
- 提醒：Dock 圖示的紅色數字是在等你的 agent 數；用量超過 80%、95% 各跳一次通知。agent 卡住或做完的音效和通知是 Herdr 內建的（Settings → Alerts）。
- 改狀態列：改 `herdr/mods/status-bar/main.js` 後跑 `herdr-app check ~/.config/herdr-app/mods/status-bar`。因為是 symlink，Herdr 不會自動重新載入：按兩次 `⌘⇧L`（切到別的版面再切回 mine）就會套用。

## 機器專屬設定

不想進 repo 的東西（API key、nvm、某台機器才有的 PATH）放 `~/.zshrc.local`，`.zshrc` 會自動載入。例如目前這台：

```zsh
export PATH="$HOME/.gemini/antigravity/bin:$PATH"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
```

## 從 Oh My Zsh + p10k 遷移

第一次在現有電腦上跑時，舊的 `~/.zshrc` 會被備份成 `~/.zshrc.bak.<時間>`。確定沒問題後可移除：
`rm -rf ~/.oh-my-zsh ~/.p10k.zsh`。原本 OMZ `git` 插件常用的 alias（`gst`、`gco`、`gp`…）已內建在 `.zshrc`。
