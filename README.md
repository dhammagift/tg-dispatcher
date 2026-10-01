# tg-dispatcher

Several Telegram bots, each driven by its own Claude Code session. The bots answer in private chats and in a shared group.

## How it works

- **A bot is a role.** Each role has its own folder `roles/<role>/`: a `.env` with the bot token, a `CLAUDE.md` (the bot's name and behaviour rules) and the Telegram plugin's state (pairing, allowlist, received files).
- **Telegram link** — the official plugin `plugin:telegram@claude-plugins-official` (an MCP server running on bun). It receives the bot's messages and hands them to the session as `<channel>` notifications. The session answers with the `reply` tool.
- **`dispatcher.sh`** keeps one tmux session `tg` with one window per role, each window running `claude --channels plugin:telegram…`. `roles.json` maps each role to its folder.
- **Voice messages** (plugin patch, `plugin-patch/`) are transcribed with Groq Whisper before the message reaches the session. The bot immediately replies to the voice note with "🎤 …", so the sender sees exactly what was heard.

```
Telegram ──> bot @x_bot ──> plugin:telegram (bun, MCP) ──> claude in tmux window "x"
                                   ^                              │
                                   └──────── reply(chat_id) ──────┘
```

## Requirements

- Linux, `tmux`, `jq`, `bun`, Claude Code (`claude`) with a subscription or an API key.
- The Telegram plugin: in Claude Code run `/plugin install telegram@claude-plugins-official`.
- For voice messages — a (free) Groq key: https://console.groq.com/keys

## Quick start

```bash
git clone git@github.com:dhammagift/tg-dispatcher.git /root/tg-dispatcher
cd /root/tg-dispatcher
cp roles.example.json roles.json          # put your roles and paths here
```

New role (bot) — step by step in [SETUP.md](SETUP.md):

1. In Telegram, at [@BotFather](https://t.me/BotFather): `/newbot` → get the token.
2. Create the role folder and its `.env`:
   ```bash
   ROLE=mybot
   mkdir -p roles/$ROLE && chmod 700 roles/$ROLE
   printf 'TELEGRAM_BOT_TOKEN=123:AA...\nGROQ_TOKEN=gsk_...\n' > roles/$ROLE/.env
   chmod 600 roles/$ROLE/.env
   cp roles/example/CLAUDE.md roles/$ROLE/   # change the bot's name inside
   ```
3. Add the role to `roles.json` (`project_dir` and `state_dir` both point to `roles/$ROLE`).
4. Start it: `./dispatcher.sh start $ROLE`.
5. Pair: send the bot a private message. A code appears in `./dispatcher.sh logs $ROLE`. Then `./dispatcher.sh attach`, pick the window (`Ctrl+B w`) and run `/telegram:access pair <code>`, then `/telegram:access policy allowlist`.

## Several bots in one group

1. Add every bot to the group and **make it an admin**: otherwise a bot only sees commands and replies to its own messages. Alternatively turn privacy off at BotFather (`/setprivacy` → Disable).
2. In each bot's session: `/telegram:access group add -100XXXXXXXXXX --no-mention`. The group id shows up in the role's log on the first message from that group.
3. Bots do not hear each other: under the Bot API rules a bot does not receive messages from other bots. Bots talk through people. In case a bot's message does arrive, each role's `CLAUDE.md` has a **loop-guard**: never answer a bot unless directly asked or mentioned, so bots don't end up in an endless exchange.
4. Address a specific bot with an @mention.

## Commands

```bash
./dispatcher.sh start <role>               # fresh Claude session under this role
./dispatcher.sh assign <role> <session-id> # resume an existing session (claude --resume)
./dispatcher.sh stop <role>
./dispatcher.sh status [role]
./dispatcher.sh logs <role>                # tail session.log
./dispatcher.sh attach                     # tmux attach -t tg; Ctrl+B w — windows, Ctrl+B d — detach
```

Sessions run with `--permission-mode auto`: nobody is there to answer a permission prompt in a headless session. Auto mode lets ordinary actions through and blocks risky ones (a production deploy, for example) with a classifier.

## Voice message patch

The plugin is vendored into `~/.claude/plugins/cache/claude-plugins-official/telegram/<version>/`. The patch for `server.ts`:

```bash
cd ~/.claude/plugins/cache/claude-plugins-official/telegram/*/
patch -p1 < /root/tg-dispatcher/plugin-patch/telegram-voice.patch
```

Re-apply it after `claude plugin update telegram`. The change takes effect once the session restarts (`./dispatcher.sh assign <role> <session-id>`). `GROQ_TOKEN` is read from the role's `.env`.

## Not in the repository

`roles.json`, `roles/*/.env`, `access.json`, `inbox/`, logs — these are tokens and the state of a particular server (see `.gitignore`).
