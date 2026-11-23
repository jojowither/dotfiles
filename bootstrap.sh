#!/usr/bin/env bash
# 一鍵建立開發環境（macOS / Linux / server）
#
#   ./bootstrap.sh            安裝工具，把 repo 的設定「複製」到這台（已有的檔案不覆蓋）
#   ./bootstrap.sh --force    同上，但和 repo 不同的設定檔也用 repo 版本覆蓋（舊的備份成 *.bak.<時間>）
#   ./bootstrap.sh --diff     列出這台和 repo 哪些設定不一樣、差在哪（不改任何東西）
#   ./bootstrap.sh --backup   反過來：把這台的設定存回 repo，當作下一台的初始設定
#   ./bootstrap.sh --dry-run  只印出會做的事，不實際執行（可和上面任一個一起用）
#
# repo 是新環境的初始設定；複製過去之後由各台自己維護，彼此不會互相影響。
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"
DRY_RUN=0
FORCE=0
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

# 比較時忽略 Herdr 自動產生的型別檔
same() { diff -rq -x '*.d.ts' -x jsconfig.json -x .DS_Store "$1" "$2" >/dev/null 2>&1; }
# 是不是舊做法留下的、指向 repo 的 symlink
linked() { [[ -L $1 && "$(readlink "$1")" == "$DOTFILES"/* ]]; }

# 把 repo 的設定複製到這台。這台已經有、而且內容不同時保留這台的版本（除非 --force）
place() {
  local src="$1" dst="$2"
  [[ -e $src ]] || return 0
  if linked "$dst"; then
    run rm "$dst"; run cp -R "$src" "$dst"; ok "${dst}（原本連結到 repo，改成複製）"; return
  fi
  if [[ ! -e $dst ]]; then
    run mkdir -p "$(dirname "$dst")"; run cp -R "$src" "$dst"; ok "${dst}（新增）"; return
  fi
  if same "$src" "$dst"; then ok "${dst}（和 repo 相同）"; return; fi
  if (( FORCE )); then
    run mv "$dst" "$dst.bak.$STAMP"; run cp -R "$src" "$dst"
    warn "${dst}：已用 repo 版本覆蓋，舊的在 $dst.bak.$STAMP"
  else
    ok "${dst}（這台改過，保留；--diff 看差異）"
  fi
}

# 所有設定檔：「repo 內路徑|這台的路徑」，安裝、--diff、--backup 共用這份清單
config_pairs() {
  local cfg="${XDG_CONFIG_HOME:-$HOME/.config}" m
  echo "zsh/.zshrc|$HOME/.zshrc"
  echo "config/starship.toml|$cfg/starship.toml"
  echo "claude/statusline.py|$HOME/.claude/statusline.py"
  echo "claude/CLAUDE.md|$HOME/.claude/CLAUDE.md"
  if [[ $OS == Darwin ]]; then
    echo "config/ghostty/config|$HOME/.config/ghostty/config"
    echo "mac/karabiner/karabiner.json|$HOME/.config/karabiner/karabiner.json"
    [[ -e $DOTFILES/mac/karabiner/assets || -d $HOME/.config/karabiner/assets ]] && \
      echo "mac/karabiner/assets|$HOME/.config/karabiner/assets"
    echo "mac/linearmouse.json|$HOME/.config/linearmouse/linearmouse.json"
    local herdr="$HOME/.config/herdr-app"
    for m in "$DOTFILES"/herdr/mods/*/; do
      m="$(basename "$m")"; echo "herdr/mods/$m|$herdr/mods/$m"
    done
    for m in "$DOTFILES"/herdr/themes/*.json; do
      m="$(basename "$m")"; echo "herdr/themes/$m|$herdr/themes/$m"
    done
    echo "herdr/layouts/mine.json|$herdr/layouts/mine.json"
  fi
  local vsdir; vsdir="$(vscode_user_dir)"
  echo "vscode/settings.json|$vsdir/settings.json"
  echo "vscode/keybindings.json|$vsdir/keybindings.json"
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
    log "Linux：系統套件（${pm}）"
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

# Claude Code CLI：官方 native installer，裝到 ~/.local/bin，之後自己會自動更新
install_claude_code() {
  log "Claude Code（claude）"
  if have claude || [[ -x $HOME/.local/bin/claude ]]; then ok "claude 已安裝"; return; fi
  run bash -c 'curl -fsSL https://claude.ai/install.sh | bash' \
    || warn "Claude Code 安裝失敗，可手動執行：curl -fsSL https://claude.ai/install.sh | bash"
}

# Claude Code plugins：清單在 claude/plugins.txt，裝好之後 Claude Code 會自己更新
install_claude_plugins() {
  log "Claude Code plugins"
  local cli=claude; have claude || cli="$HOME/.local/bin/claude"
  [[ -x $(command -v "$cli") ]] || { warn "找不到 claude，略過 plugins"; return; }
  local installed p
  installed="$("$cli" plugin list 2>/dev/null || true)"
  while IFS= read -r p; do
    [[ -z $p || $p == \#* ]] && continue
    if grep -qF "$p" <<<"$installed"; then ok "${p}（已安裝）"
    else run "$cli" plugin install "$p" >/dev/null && ok "${p}（新安裝）" || warn "$p 安裝失敗"; fi
  done < "$DOTFILES/claude/plugins.txt"
}

# Herdr app 一律裝最新版；自訂的 mod / layout 是從某一版複製來的，
# 版本不同時檢查還能不能正常載入，避免更新後設定默默壞掉
check_herdr() {
  [[ $OS == Darwin ]] && have herdr-app || return 0
  log "Herdr 自訂設定檢查"
  local app_ver f m from
  app_ver="$(herdr-app --version 2>/dev/null | awk '{print $NF}')"
  for f in "$DOTFILES"/herdr/mods/*/mod.json "$DOTFILES"/herdr/layouts/*.json; do
    from="$(python3 -c 'import json,sys; c=json.load(open(sys.argv[1])).get("cloned_from") or {}; print(c.get("name",""), c.get("version",""))' "$f" 2>/dev/null || true)"
    [[ -n ${from// } ]] || continue
    if [[ ${from##* } != "$app_ver" ]]; then
      warn "$(basename "$(dirname "$f")")/$(basename "$f")：複製自 Herdr ${from##* } 的 ${from% *}，現在是 ${app_ver}；新版內建的若有新功能，需要手動合併"
    fi
  done
  for m in "$DOTFILES"/herdr/mods/*/; do
    m="$HOME/.config/herdr-app/mods/$(basename "$m")"
    [[ -d $m ]] || continue
    if (( DRY_RUN )); then printf '  + herdr-app check %s\n' "$m"
    elif herdr-app check "$m" >/dev/null 2>&1; then ok "$(basename "$m") 可正常載入（Herdr ${app_ver}）"
    else warn "$(basename "$m") 在 Herdr ${app_ver} 載入失敗，執行 herdr-app check $m 看原因"; fi
  done
}

install_zsh_plugins() {
  log "zsh 插件（取代 Oh My Zsh）"
  local repo name
  for repo in zsh-users/zsh-autosuggestions zsh-users/zsh-syntax-highlighting zsh-users/zsh-completions; do
    name="${repo#*/}"
    if [[ -d $ZPLUGINS/$name/.git ]]; then
      run git -C "$ZPLUGINS/$name" pull -q --ff-only && ok "${name}（已更新）"
    else
      run mkdir -p "$ZPLUGINS"
      run git clone -q --depth 1 "https://github.com/$repo.git" "$ZPLUGINS/$name" && ok "$name"
    fi
  done
}

# 在 ~/.claude/settings.json 加上 statusLine（已經有自訂的就不動）
enable_claude_statusline() {
  local f="$HOME/.claude/settings.json"
  have python3 || { warn "沒有 python3，略過 Claude status line"; return; }
  if [[ -f $f ]] && grep -q '"statusLine"' "$f"; then ok "Claude statusLine 已設定（不覆蓋）"; return; fi
  run mkdir -p "$HOME/.claude"
  [[ -f $f ]] && run cp "$f" "$f.bak.$STAMP"
  run python3 -c 'import json,os,sys
p=sys.argv[1]; s=json.load(open(p)) if os.path.exists(p) else {}
s["statusLine"]={"type":"command","command":"~/.claude/statusline.py"}
open(p,"w").write(json.dumps(s,indent=2,ensure_ascii=False)+"\n")' "$f"
  ok "Claude statusLine -> ~/.claude/statusline.py"
}

install_configs() {
  log "複製設定檔（已有的不覆蓋$( (( FORCE )) && echo '；--force：不同的會覆蓋')）"
  local src dst
  while IFS='|' read -r src dst; do
    place "$DOTFILES/$src" "$dst"
  done < <(config_pairs)
  # Claude Code status line：顯示用量，也把官方 rate_limits 存給 Herdr 狀態列
  enable_claude_statusline
}

# ---------------------------------------------------------------- 比較（--diff）
diff_configs() {
  log "這台和 repo 的設定差異（- 這台   + repo）"
  local src dst n_same=0 n_diff=0
  while IFS='|' read -r src dst; do
    [[ -e $DOTFILES/$src ]] || continue
    if linked "$dst"; then
      warn "$dst 連結到 repo（舊做法；重跑 bootstrap 會改成複製）"
    elif [[ ! -e $dst ]]; then
      warn "$dst 這台沒有（重跑 bootstrap 會補上）"; n_diff=$((n_diff + 1))
    elif same "$DOTFILES/$src" "$dst"; then
      n_same=$((n_same + 1))
    else
      n_diff=$((n_diff + 1))
      printf '\n\033[1;33m≠ %s\033[0m  ↔  repo/%s\n' "$dst" "$src"
      diff -ru -x '*.d.ts' -x jsconfig.json -x .DS_Store "$dst" "$DOTFILES/$src" | sed 's/^/    /' || true
    fi
  done < <(config_pairs)
  echo
  ok "$n_same 個和 repo 相同，$n_diff 個不同"
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
    else run "$code" --install-extension "$ext" --force >/dev/null && ok "${ext}（新安裝）"; fi
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
    # 合併而不是覆蓋：這台沒裝的插件不會從清單消失
    local list="$DOTFILES/vscode/extensions.txt" current
    current="$("$code" --list-extensions 2>/dev/null || true)"
    if [[ -n $current ]]; then
      if (( DRY_RUN )); then printf '  + merge %s\n' "$list"
      else { cat "$list" 2>/dev/null; printf '%s\n' "$current"; } | grep -v '^\s*$' | sort -fu -o "$list"; fi
      ok "vscode/extensions.txt（已合併）"
    else
      warn "這台 VS Code 沒有裝插件，extensions.txt 保持不變"
    fi
  fi
  local vsdir; vsdir="$(vscode_user_dir)"
  for f in settings.json keybindings.json; do
    [[ -f $vsdir/$f ]] || continue
    # 只有空的 {} / [] 就不要匯出，免得新電腦的設定被清空
    if [[ -z "$(tr -d ' \t\n{}[]' < "$vsdir/$f")" ]]; then warn "$f 是空的，略過"; continue; fi
    run cp "$vsdir/$f" "$DOTFILES/vscode/$f" && ok "vscode/$f"
  done
  # 其他設定檔：這台和 repo 不同的才存回去
  local src dst
  while IFS='|' read -r src dst; do
    [[ $src == vscode/* ]] && continue            # 上面處理過
    [[ -e $dst ]] && ! linked "$dst" || continue
    if [[ -e $DOTFILES/$src ]] && same "$DOTFILES/$src" "$dst"; then continue; fi
    run rm -rf "$DOTFILES/$src"
    run mkdir -p "$(dirname "$DOTFILES/$src")"
    run cp -R "$dst" "$DOTFILES/$src" && ok "$src ← $dst"
  done < <(config_pairs)
  log "完成。先用 git diff 看一下，不想要的用 git checkout <檔案> 還原，再 commit 推上去。"
}

# ---------------------------------------------------------------- main
usage() { sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; }

DO_BACKUP=0
DO_DIFF=0
for arg in "$@"; do
  case $arg in
    --dry-run) DRY_RUN=1 ;;
    --backup)  DO_BACKUP=1 ;;
    --force)   FORCE=1 ;;
    --diff)    DO_DIFF=1 ;;
    -h|--help) usage; exit 0 ;;
    *) warn "未知參數：$arg"; usage; exit 1 ;;
  esac
done

(( DRY_RUN )) && log "DRY RUN：只顯示動作，不會改任何東西"
if (( DO_DIFF )); then diff_configs; check_herdr; exit 0; fi
if (( DO_BACKUP )); then backup; exit 0; fi

case $OS in
  Darwin) install_macos ;;
  Linux)  install_linux ;;
  *) warn "不支援的系統：$OS"; exit 1 ;;
esac
install_herdr_core
install_claude_code
install_claude_plugins
install_zsh_plugins
install_configs
check_herdr
install_vscode_extensions
set_default_shell

log "全部完成！開新的終端機視窗（或執行 exec zsh）就會套用。"
[[ $OS == Darwin ]] && echo "   Ghostty 的字型請選 JetBrainsMono Nerd Font 或 MesloLGS Nerd Font。"
