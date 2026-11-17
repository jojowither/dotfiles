# ~/.zshrc — 跨平台（macOS / Linux / server）共用
# 不用 Oh My Zsh：直接載入幾個核心插件，啟動更快、server 上也好裝。
# 機器專屬的設定請放在 ~/.zshrc.local

have() { command -v "$1" >/dev/null 2>&1; }

# ---------- PATH / Homebrew ----------
export PATH="$HOME/.local/bin:$PATH"
for b in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
  [[ -x $b ]] && { eval "$($b shellenv)"; break; }
done

# ---------- 歷史紀錄 ----------
HISTFILE=~/.zsh_history
HISTSIZE=100000
SAVEHIST=100000
setopt share_history hist_ignore_all_dups hist_ignore_space hist_reduce_blanks
setopt auto_cd interactive_comments no_beep

# ---------- 補全 ----------
ZPLUGINS="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins"
[[ -d $ZPLUGINS/zsh-completions/src ]] && fpath=("$ZPLUGINS/zsh-completions/src" $fpath)
autoload -Uz compinit && compinit -d "${XDG_CACHE_HOME:-$HOME/.cache}/zcompdump"
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'   # 不分大小寫

# ---------- 按鍵：上下鍵依目前輸入搜尋歷史 ----------
bindkey -e
autoload -U up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search; zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search;  bindkey '^[OA' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search; bindkey '^[OB' down-line-or-beginning-search

# ---------- 插件 ----------
[[ -f $ZPLUGINS/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
  source "$ZPLUGINS/zsh-autosuggestions/zsh-autosuggestions.zsh"

# ---------- 工具整合 ----------
if have fzf; then
  if fzf --zsh >/dev/null 2>&1; then
    source <(fzf --zsh)                     # fzf >= 0.48
  else                                      # 舊版（例如 Ubuntu 22.04 apt）
    for f in /usr/share/doc/fzf/examples/key-bindings.zsh /usr/share/fzf/key-bindings.zsh; do
      [[ -f $f ]] && source "$f" && break
    done
  fi
fi
have zoxide && eval "$(zoxide init zsh)"

# Debian/Ubuntu 的套件名稱不同
have batcat && ! have bat && alias bat=batcat
have fdfind && ! have fd  && alias fd=fdfind

# ---------- Aliases ----------
if have eza; then
  alias ls='eza --group-directories-first --icons=auto'
  alias ll='eza -l --git --group-directories-first --icons=auto'
  alias la='eza -la --git --group-directories-first --icons=auto'
  alias lt='eza --tree --level=2 --icons=auto'
else
  alias ll='ls -lh'; alias la='ls -lah'
fi
alias l='la' lsa='la'          # Oh My Zsh 的 l / lsa（ls -lah）
# 沿用 Oh My Zsh 最常用的 git alias
alias g='git' gst='git status' ga='git add' gaa='git add --all' gc='git commit -v' \
      gcm='git commit -m' gco='git checkout' gsw='git switch' gb='git branch' \
      gd='git diff' gl='git pull' gp='git push' glog='git log --oneline --graph --decorate'
have lazygit && alias lg='lazygit'
alias ..='cd ..' ...='cd ../..' ....='cd ../../..'
# 其他 Oh My Zsh 內建的目錄 alias
alias -- -='cd -'
alias md='mkdir -p' rd='rmdir'

# ---------- Prompt ----------
ZLE_RPROMPT_INDENT=0   # 右側 prompt 貼齊視窗邊緣，外框才對得齊（同 p10k）
have starship && eval "$(starship init zsh)"

# ---------- 本機設定 ----------
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

# syntax-highlighting 必須最後載入
[[ -f $ZPLUGINS/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
  source "$ZPLUGINS/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
