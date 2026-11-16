# AutoBSPWN zsh v3.2.0
# Standalone: no oh-my-zsh required. Plugins come from distro packages; p10k is optional.
export PATH="$HOME/.local/bin:$PATH"
export _JAVA_AWT_WM_NONREPARENTING=1
# Prefer neovim, then vim/vi/nano — do not assume nvim is installed
if [ -z "${EDITOR:-}" ]; then
  for e in nvim vim vi nano; do
    command -v "$e" >/dev/null 2>&1 && export EDITOR=$e && break
  done
fi
# Do not override TERM (kitty uses xterm-kitty; overwriting it breaks kittens)
HISTFILE=~/.zsh_history
HISTSIZE=100000
SAVEHIST=100000
setopt SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE EXTENDED_HISTORY AUTO_CD

if command -v lsd >/dev/null 2>&1; then
  alias ls='lsd --group-dirs=first'
  alias ll='lsd -lAh --group-dirs=first'
  alias tree='lsd --tree'
fi
if command -v batcat >/dev/null 2>&1; then
  alias cat='batcat --paging=never'
  alias bat='batcat'
elif command -v bat >/dev/null 2>&1; then
  alias cat='bat --paging=never'
fi
alias cl='clear'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias setfocus='setFocus'
alias clearfocus='clearFocus'

focusip() {
  local f="$HOME/.config/bspwm/focus_ip" n="$HOME/.config/bspwm/focus_name"
  [ -f "$f" ] || { echo None; return; }
  local ip name
  ip=$(cat "$f")
  [ -f "$n" ] && name=$(cat "$n")
  echo "${name:+$name }$ip"
}

# v2.1: same menus as the hotkeys, from the shell
alias theme='theme-sync'
alias vpnmenu='$HOME/.config/bspwm/scripts/vpn-menu.sh'
alias target='$HOME/.config/bspwm/scripts/target-menu.sh'
alias tools='$HOME/.config/bspwm/scripts/tools-menu.sh'
# tgt                → cd into ~/targets/<active target ip> (created if needed)
# tgt <nombre|ip>    → make a saved/recent target active (targets.tsv, then history) and cd there
tgt() {
  local ip name r bin=$HOME/.local/bin
  if [ -n "${1:-}" ]; then
    if [ -x "$bin/targetFav" ] || command -v targetFav >/dev/null 2>&1; then
      r=$("${bin}/targetFav" resolve "$1" 2>/dev/null || targetFav resolve "$1" 2>/dev/null)
    else
      r=$( { awk -F'\t' '!/^[[:space:]]*#/ && NF' "$HOME/.config/bspwm/targets.tsv" 2>/dev/null
             cat "$HOME/.config/bspwm/focus_history" 2>/dev/null; } \
           | awk -F'\t' -v k="$1" '$1==k || tolower($2)==tolower(k) {print $1 "\t" $2; exit}')
    fi
    if [ -n "$r" ]; then
      ip=${r%%$'\t'*}; name=${r#*$'\t'}
    elif [[ $1 != *[^0-9.]* ]]; then
      ip=$1; name=          # looks like an IP: setFocus validates it
    else
      echo "tgt: «$1» no está en targets.tsv ni en el historial (targetFav list)" >&2; return 1
    fi
    local sf=setFocus out
    [ -x "$bin/setFocus" ] && sf=$bin/setFocus
    out=$("$sf" "$ip" ${name:+"$name"} 2>&1) || { echo "tgt: $out" >&2; return 1; }
  fi
  ip=$(tr -d '[:space:]' <"$HOME/.config/bspwm/focus_ip" 2>/dev/null)
  [ -n "$ip" ] || { echo "Sin focus: setFocus <ip> [nombre]  ·  tgt <nombre|ip>"; return 1; }
  mkdir -p "$HOME/targets/$ip"/{nmap,loot,exploits} && cd "$HOME/targets/$ip" && pwd
}
# Tab-complete tgt with saved + recent target names/IPs
_tgt() {
  local -a c
  c=(${(f)"$( { awk -F'\t' '!/^[[:space:]]*#/ && NF {print $1; if ($2!="") print $2}' "$HOME/.config/bspwm/targets.tsv"
               awk -F'\t' 'NF {print $1; if ($2!="") print $2}' "$HOME/.config/bspwm/focus_history"; } 2>/dev/null | awk '!s[$0]++')"})
  compadd -a c
}

mkt() {
  local name="${1:?uso: mkt <nombre>}"
  mkdir -p "$HOME/Machines/$name"/{nmap,content,exploits,scripts,loot}
  cd "$HOME/Machines/$name" && pwd
}

ports() {
  [ -f "${1:-}" ] || { echo "uso: ports file.nmap"; return 1; }
  grep -oP '\d+(?=/open)' "$1" 2>/dev/null | sort -n | uniq | paste -sd, -
}

# Completions first, then widgets, then p10k; syntax-highlighting MUST be last
autoload -Uz compinit && compinit -C
(( $+functions[compdef] )) && compdef _tgt tgt

[ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ] && source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
# fzf: Debian/Kali/Parrot path first, then other common locations
for fzf_kb in \
  /usr/share/doc/fzf/examples/key-bindings.zsh \
  /usr/share/fzf/key-bindings.zsh \
  /usr/share/fzf/shell/key-bindings.zsh
do
  [ -f "$fzf_kb" ] && source "$fzf_kb" && break
done
for fzf_cmp in \
  /usr/share/doc/fzf/examples/completion.zsh \
  /usr/share/fzf/completion.zsh \
  /usr/share/fzf/shell/completion.zsh
do
  [ -f "$fzf_cmp" ] && source "$fzf_cmp" && break
done

[[ -r ~/powerlevel10k/powerlevel10k.zsh-theme ]] && source ~/powerlevel10k/powerlevel10k.zsh-theme
[[ -r ~/.p10k.zsh ]] && source ~/.p10k.zsh

# Must be sourced last
if [ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
  source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
elif [ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
  source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi
