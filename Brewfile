# ===== macOS 專用：brew bundle --file=Brewfile =====

# --- CLI（跨平台，Linux 由 bootstrap.sh 另外安裝）---
brew "git"
brew "starship"      # prompt（取代 Powerlevel10k）
brew "zoxide"        # 聰明的 cd
brew "fzf"           # 模糊搜尋，Ctrl-R 歷史
brew "eza"           # 現代 ls
brew "bat"           # 有高亮的 cat
brew "ripgrep"       # rg
brew "fd"            # 現代 find
brew "git-delta"     # 好看的 git diff
brew "lazygit"
brew "btop"
brew "jq"
brew "tlrc"          # tldr
brew "mas"           # 從 App Store 安裝 app 用

# --- 終端機 ---
cask "ghostty"       # 主要終端機，設定在 config/ghostty/config

# --- 字型（Starship/eza 圖示需要 Nerd Font）---
cask "font-meslo-lg-nerd-font"
cask "font-jetbrains-mono-nerd-font"

# --- 開發 ---
cask "visual-studio-code"
cask "herdr-app"     # Herdr：跑 coding agent 的桌面 app（herdr-core / hc 由 bootstrap.sh 另外裝）
brew "ccusage"       # 從 Claude Code 本機紀錄算 token / 估算花費（ccusage daily、ccusage blocks）

# --- 系統小工具（Mac 專屬）---
cask "linearmouse"
cask "karabiner-elements"

# App Store（需要先登入 App Store）
# 原本的 RunCat 已下架，現在架上的是 RunCat Neo
mas "RunCat Neo", id: 6757801838
