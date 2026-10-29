#!/bin/sh
# Claude Notification hook: put a bell in this pane's title so tmux can show which pane wants attention.
# Hooks run without a controlling tty and with stdout captured, so find claude's pty by walking up.

# tty device of pid $1, or nothing. Falls back to /proc for busybox ps, which has no `-o tty=`.
tty_of() {
  t=$(ps -o tty= -p "$1" 2>/dev/null | tr -d ' ')
  case $t in
    ''|'?'|'??') ;;
    *) echo "/dev/$t"; return 0 ;;
  esac
  l=$(readlink "/proc/$1/fd/0" 2>/dev/null)
  case $l in
    /dev/pts/*|/dev/tty*) echo "$l"; return 0 ;;
  esac
  return 1
}

# parent pid of pid $1, with the same /proc fallback
ppid_of() {
  pp=$(ps -o ppid= -p "$1" 2>/dev/null | tr -d ' ')
  [ -n "$pp" ] || pp=$(sed -n 's/^PPid:[[:space:]]*//p' "/proc/$1/status" 2>/dev/null)
  echo "$pp"
}

p=$PPID
while [ "${p:-0}" -gt 1 ]; do
  if dev=$(tty_of "$p"); then
    printf '\033]2;🔔 claude\033\\' > "$dev" 2>/dev/null
    exit 0
  fi
  p=$(ppid_of "$p")
done
