#!/usr/bin/env bash
# Manages one `tmux` WINDOW per Telegram bot "role" (see README.md), all
# inside a single shared tmux SESSION named "tg". One attach point
# (`tmux attach -t tg`), switch roles with Ctrl-B w (window list) or Ctrl-B <n>.
#
# tmux, not screen: screen only gives a real pty to the FIRST window of a
# detached session — any window added later via `screen -X screen` gets no
# pty, and claude's stdin-detection then thinks it's non-interactive and
# dies with "Input must be provided ... --print". tmux's server always
# allocates a pty per window regardless of creation order, so this doesn't
# happen. Swapping which Claude session holds a role is just restarting
# that window; server.ts's own SIGTERM handoff logic (see
# ~/.claude/plugins/cache/claude-plugins-official/telegram/*/server.ts)
# handles the actual Telegram getUpdates handoff — this script just manages
# the process.
set -euo pipefail

ROLES_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/roles.json"
SESSION="tg"
CMD="${1:-}"
ROLE="${2:-}"

usage() {
  echo "Usage:"
  echo "  $0 start <role>               # fresh Claude session under this role (new window)"
  echo "  $0 assign <role> <session-id> # resume an existing session under this role"
  echo "  $0 stop <role>                # kill this role's window"
  echo "  $0 status [role]              # list windows, or check one"
  echo "  $0 logs <role>                # tail this role's log file"
  echo "  $0 attach                     # tmux attach -t tg (Ctrl+B w for window list, Ctrl+B d to detach)"
  exit 1
}

role_cfg() {
  jq -e ".\"$1\"" "$ROLES_FILE" >/dev/null 2>&1 || { echo "Unknown role '$1' — add it to $ROLES_FILE first" >&2; exit 1; }
  jq -r ".\"$1\".$2" "$ROLES_FILE"
}

session_exists() { tmux has-session -t "=$SESSION" 2>/dev/null; }
window_exists() { tmux list-windows -t "$SESSION" -F '#{window_name}' 2>/dev/null | grep -qxF "$1"; }

[ -n "$CMD" ] || usage

case "$CMD" in
  start|assign)
    [ -n "$ROLE" ] || usage
    PROJECT_DIR=$(role_cfg "$ROLE" project_dir)
    STATE_DIR=$(role_cfg "$ROLE" state_dir)
    mkdir -p "$STATE_DIR"
    [ -f "$STATE_DIR/.env" ] || { echo "Missing $STATE_DIR/.env (TELEGRAM_BOT_TOKEN=...) — see SETUP.md" >&2; exit 1; }
    LOG_FILE="$STATE_DIR/session.log"
    if [ "$CMD" = assign ]; then
      SESSION_ID="${3:?assign needs a session id: dispatcher.sh assign <role> <session-id>}"
      RESUME_STR=" --resume $SESSION_ID"
    else
      RESUME_STR=""
    fi
    # --permission-mode auto: nobody is watching a headless bot to answer a
    # permission prompt, so without this any non-trivial tool call (even a
    # benign one, like the telegram skill's own bash lookups) hangs forever
    # waiting for a confirmation that never comes. "auto" runs the same
    # risk classifier interactive sessions use (it already blocked a
    # production pm2 restart attempt elsewhere) instead of skipping checks
    # outright like --dangerously-skip-permissions would.
    RUN_CMD="cd '$PROJECT_DIR'; export PATH=\"\$HOME/.local/bin:\$HOME/.bun/bin:\$PATH\"; export TELEGRAM_STATE_DIR='$STATE_DIR'; exec claude --permission-mode auto --channels plugin:telegram@claude-plugins-official$RESUME_STR"

    if session_exists && window_exists "$ROLE"; then
      tmux kill-window -t "$SESSION:$ROLE"
      sleep 0.3
    fi
    if session_exists; then
      tmux new-window -t "$SESSION" -n "$ROLE" "bash -c \"$RUN_CMD\""
    else
      tmux new-session -d -s "$SESSION" -n "$ROLE" "bash -c \"$RUN_CMD\""
    fi
    sleep 0.5
    tmux pipe-pane -t "$SESSION:$ROLE" -o "cat >> '$LOG_FILE'"
    echo "Window '$ROLE' up in session '$SESSION'. '$0 attach' to type into it (Ctrl+B w to switch windows)."
    ;;
  stop)
    [ -n "$ROLE" ] || usage
    tmux kill-window -t "$SESSION:$ROLE"
    ;;
  status)
    if [ -n "$ROLE" ]; then
      window_exists "$ROLE" && echo "$ROLE: running" || echo "$ROLE: not running"
    else
      session_exists && tmux list-windows -t "$SESSION" || echo "session '$SESSION' not running"
    fi
    ;;
  logs)
    [ -n "$ROLE" ] || usage
    STATE_DIR=$(role_cfg "$ROLE" state_dir)
    tail -f "$STATE_DIR/session.log"
    ;;
  attach)
    exec tmux attach -t "$SESSION"
    ;;
  *)
    usage
    ;;
esac
