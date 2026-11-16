#!/usr/bin/env bash
# 一鍵建立開發環境（macOS / Linux / server）
#
#   ./bootstrap.sh            安裝並套用設定
#   ./bootstrap.sh --dry-run  只印出會做的事，不實際執行
#   ./bootstrap.sh --backup   把這台電腦目前的 GUI app 設定匯出到 repo（舊電腦上跑）
#
# 可以重複執行：已裝好的會略過，原本的設定檔會備份成 *.bak.<時間>。
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"
DRY_RUN=0
STAMP="$(date +%Y%m%d-%H%M%S)"
ZPLUGINS="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m  ✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  !\033[0m %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }
run()  { if (( DRY_RUN )); then printf '  + %s\n' "$*"; else "$@"; fi; }

vscode_user_dir() {
  if [[ $OS == Darwin ]]; then echo "$HOME/Library/Application Support/Code/User"
  else echo "${XDG_CONFIG_HOME:-$HOME/.config}/Code/User"; fi
}

code_cli() {
  if have code; then echo code
  elif [[ -x "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]]; then
    echo "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
  fi
}

# 建 symlink；目標已存在且不是同一個連結時先備份
link() {
  local src="$1" dst="$2"
  [[ -e $src ]] || { warn "找不到 $src，略過"; return; }
  if [[ -L $dst && "$(readlink "$dst")" == "$src" ]]; then ok "$dst 已連結"; return; fi
  run mkdir -p "$(dirname "$dst")"
  if [[ -e $dst || -L $dst ]]; then run mv "$dst" "$dst.bak.$STAMP"; warn "已備份舊的 $dst"; fi
  run ln -s "$src" "$dst"; ok "$dst -> $src"
}

# 複製（給會自己覆寫設定檔、不適合 symlink 的 GUI app）
place() {
  local src="$1" dst="$2"
  [[ -e $src ]] || return 0
  run mkdir -p "$(dirname "$dst")"
  if [[ -e $dst ]]; then run mv "$dst" "$dst.bak.$STAMP"; warn "已備份舊的 $dst"; fi
  run cp -R "$src" "$dst"; ok "$dst（複製）"
}

# ---------------------------------------------------------------- macOS
install_macos() {
  log "macOS：Xcode Command Line Tools"
  if xcode-select -p >/dev/null 2>&1; then ok "已安裝"
  else run xcode-select --install; warn "請完成 CLT 安裝視窗後再重新執行本腳本"; exit 1; fi

  log "macOS：Homebrew"
  if ! have brew; then
    run /bin/bash -c '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [[ -x $b ]] && eval "$($b shellenv)"; done
  fi
  have brew && ok "$(brew --version | head -1)"

  log "macOS：brew bundle（CLI + GUI app + 字型 + App Store）"
  if ! run brew bundle --file="$DOTFILES/Brewfile"; then
    warn "部分套件安裝失敗（常見原因：App Store 未登入，RunCat 裝不起來）。其他已完成，可稍後重跑。"
  fi
}

# ---------------------------------------------------------------- Linux / server
install_linux() {
  local SUDO=""
  if (( EUID != 0 )); then
    if have sudo; then SUDO="sudo"; else warn "沒有 sudo，略過系統套件，只裝到 ~/.local/bin"; fi
  fi

  local pm="" pkgs=()
  if   have apt-get; then pm=apt;    pkgs=(zsh git curl unzip fzf ripgrep bat fd-find eza btop jq)
  elif have dnf;     then pm=dnf;    pkgs=(zsh git curl unzip fzf ripgrep bat fd-find eza btop jq)
  elif have pacman;  then pm=pacman; pkgs=(zsh git curl unzip fzf ripgrep bat fd eza btop jq lazygit git-delta)
  fi

  if [[ -n $pm && ( -n $SUDO || $EUID -eq 0 ) ]]; then
    log "Linux：系統套件（$pm）"
    [[ $pm == apt ]] && run $SUDO apt-get update -qq
    for p in "${pkgs[@]}"; do   # 逐一安裝，舊版發行版缺某個套件也不會整批失敗
      case $pm in
        apt)    run $SUDO apt-get install -y -qq "$p" >/dev/null 2>&1 ;;
        dnf)    run $SUDO dnf install -y -q "$p"      >/dev/null 2>&1 ;;
        pacman) run $SUDO pacman -S --needed --noconfirm "$p" >/dev/null 2>&1 ;;
      esac && ok "$p" || warn "$p 無法從 $pm 安裝（略過）"
    done
  elif [[ -z $pm ]]; then
    warn "不認得的套件管理器，請自行安裝 zsh / git / curl"
  fi

  mkdir -p "$HOME/.local/bin"
  export PATH="$HOME/.local/bin:$PATH"

  log "Linux：使用者層級工具（~/.local/bin，不需 sudo）"
  if have starship; then ok "starship"
  else run sh -c 'curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"'; fi

  if have zoxide; then ok "zoxide"
  else run sh -c 'curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh'; fi

  if have fzf; then ok "fzf"
  else
    run git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
    run "$HOME/.fzf/install" --bin
    run ln -sf "$HOME/.fzf/bin/fzf" "$HOME/.local/bin/fzf"
  fi
}

# ---------------------------------------------------------------- 共用
# herdr-core（hc）：agent 實際跑在這個背景服務裡，關掉 app 也不會停。
# Mac 的 Herdr app 由 Brewfile 裝；server 只裝 core，從 Mac 用 `hc machine add` 連過來。
# 裝好之後由 Herdr 自己更新，這裡只負責第一次安裝。
install_herdr_core() {
  log "herdr-core（hc）"
  if have herdr-core || [[ -x $HOME/.local/bin/herdr-core ]]; then ok "herdr-core 已安裝"; return; fi
  run mkdir -p "$HOME/.local/bin"
  run sh -c 'curl -fsSL https://releases.herdr.dev/core/install.sh | HC_INSTALL_DIR="$HOME/.local/bin" sh' \
    || warn "herdr-core 安裝失敗；Mac 上第一次打開 Herdr 時它也會提示安裝"
}

install_zsh_plugins() {
  log "zsh 插件（取代 Oh My Zsh）"
  local repo name
  for repo in zsh-users/zsh-autosuggestions zsh-users/zsh-syntax-highlighting zsh-users/zsh-completions; do
    name="${repo#*/}"
    if [[ -d $ZPLUGINS/$name/.git ]]; then
      run git -C "$ZPLUGINS/$name" pull -q --ff-only && ok "$name（已更新）"
    else
      run mkdir -p "$ZPLUGINS"
      run git clone -q --depth 1 "https://github.com/$repo.git" "$ZPLUGINS/$name" && ok "$name"
    fi
  done
}

link_configs() {
  log "連結設定檔"
  link "$DOTFILES/zsh/.zshrc"          "$HOME/.zshrc"
  link "$DOTFILES/config/starship.toml" "${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml"

  if [[ $OS == Darwin ]]; then
    link  "$DOTFILES/config/ghostty/config"  "$HOME/.config/ghostty/config"
    place "$DOTFILES/mac/karabiner"          "$HOME/.config/karabiner"
    place "$DOTFILES/mac/linearmouse.json"   "$HOME/.config/linearmouse/linearmouse.json"
  fi

  local vsdir; vsdir="$(vscode_user_dir)"
  place "$DOTFILES/vscode/settings.json"    "$vsdir/settings.json"
  place "$DOTFILES/vscode/keybindings.json" "$vsdir/keybindings.json"
}

install_vscode_extensions() {
  local code; code="$(code_cli)"
  if [[ -z $code ]]; then warn "找不到 VS Code（code 指令），略過插件"; return; fi
  log "VS Code 插件"
  local installed ext
  installed="$("$code" --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')"
  while IFS= read -r ext; do
    [[ -z $ext || $ext == \#* ]] && continue
    if grep -qx "$(tr '[:upper:]' '[:lower:]' <<<"$ext")" <<<"$installed"; then ok "$ext"
    else run "$code" --install-extension "$ext" --force >/dev/null && ok "$ext（新安裝）"; fi
  done < "$DOTFILES/vscode/extensions.txt"
}

set_default_shell() {
  local zsh_path; zsh_path="$(command -v zsh || true)"
  [[ -z $zsh_path ]] && { warn "zsh 未安裝，無法設為預設 shell"; return; }
  if [[ "$(basename "${SHELL:-}")" == zsh ]]; then ok "預設 shell 已是 zsh"; return; fi
  log "把預設 shell 改成 zsh"
  run chsh -s "$zsh_path" || warn "chsh 失敗，請手動執行：chsh -s $zsh_path"
}

# ---------------------------------------------------------------- 匯出（舊電腦上跑）
backup() {
  log "匯出這台電腦的設定到 $DOTFILES"
  local code; code="$(code_cli)"
  if [[ -n $code ]]; then
    run sh -c "\"$code\" --list-extensions > \"$DOTFILES/vscode/extensions.txt\""
    ok "vscode/extensions.txt"
  fi
  local vsdir; vsdir="$(vscode_user_dir)"
  for f in settings.json keybindings.json; do
    [[ -f $vsdir/$f ]] && run cp "$vsdir/$f" "$DOTFILES/vscode/$f" && ok "vscode/$f"
  done
  if [[ $OS == Darwin ]]; then
    if [[ -d $HOME/.config/karabiner ]]; then
      run rm -rf "$DOTFILES/mac/karabiner"
      run mkdir -p "$DOTFILES/mac/karabiner"
      run cp "$HOME/.config/karabiner/karabiner.json" "$DOTFILES/mac/karabiner/" && ok "mac/karabiner/karabiner.json"
      [[ -d $HOME/.config/karabiner/assets ]] && run cp -R "$HOME/.config/karabiner/assets" "$DOTFILES/mac/karabiner/"
    fi
    [[ -f $HOME/.config/linearmouse/linearmouse.json ]] && \
      run cp "$HOME/.config/linearmouse/linearmouse.json" "$DOTFILES/mac/" && ok "mac/linearmouse.json"
  fi
  log "完成。記得 git commit 後推上去。"
}

# ---------------------------------------------------------------- main
usage() { sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; }

DO_BACKUP=0
for arg in "$@"; do
  case $arg in
    --dry-run) DRY_RUN=1 ;;
    --backup)  DO_BACKUP=1 ;;
    -h|--help) usage; exit 0 ;;
    *) warn "未知參數：$arg"; usage; exit 1 ;;
  esac
done

(( DRY_RUN )) && log "DRY RUN：只顯示動作，不會改任何東西"
if (( DO_BACKUP )); then backup; exit 0; fi

case $OS in
  Darwin) install_macos ;;
  Linux)  install_linux ;;
  *) warn "不支援的系統：$OS"; exit 1 ;;
esac
install_herdr_core
install_zsh_plugins
link_configs
install_vscode_extensions
set_default_shell

log "全部完成！開新的終端機視窗（或執行 exec zsh）就會套用。"
[[ $OS == Darwin ]] && echo "   Ghostty/iTerm2 的字型請選 JetBrainsMono Nerd Font 或 MesloLGS Nerd Font。"
