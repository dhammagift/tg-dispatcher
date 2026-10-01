# Adding a new role (a new bot)

For an agent or a person who has a bot token from @BotFather.

## 1. Pick the role name
Use the bot's real @username (without the @, and without `_bot` if you want it shorter),
not a name a person made up — that makes it easy to match a role to its bot:
`kacchapa`, `cakkhu`, `ariyasacca`, `o28`.

## 2. One folder per role — it is both project_dir and state_dir
```bash
ROLE=ariyasacca
mkdir -p /root/tg-dispatcher/roles/$ROLE
chmod 700 /root/tg-dispatcher/roles/$ROLE
cat > /root/tg-dispatcher/roles/$ROLE/.env <<EOF
TELEGRAM_BOT_TOKEN=123456789:AA...   # the whole token from BotFather
GROQ_TOKEN=gsk_...                   # optional: voice message transcription
EOF
chmod 600 /root/tg-dispatcher/roles/$ROLE/.env
```
Don't split `.env` and `CLAUDE.md` into different folders (it used to be like that — `state_dir`
separate from `project_dir` — and it kept causing confusion: the token ended up in the wrong
place). One folder is simpler and works exactly the same — the plugin doesn't care whether
`TELEGRAM_STATE_DIR` matches the session's working directory.

## 3. Register the role in roles.json
`/root/tg-dispatcher/roles.json`, add a key:
```json
{
  "ariyasacca": {
    "project_dir": "/root/tg-dispatcher/roles/ariyasacca",
    "state_dir": "/root/tg-dispatcher/roles/ariyasacca"
  }
}
```

## 4. Put a CLAUDE.md with the identity into the same folder
Template — `roles/example/CLAUDE.md`: identity ("your name in this chat is X"), the loop-guard
(don't answer bots except on a direct question or mention), and the "always reply back to
Telegram" block (the answer must go out through `reply` to the originating chat_id — the private
chat or the group the message came from; otherwise it only lands in the terminal, not with the
person in Telegram).

## 5. Start it
```bash
/root/tg-dispatcher/dispatcher.sh start ariyasacca
```

## 6. Pair the bot (once per role)
```bash
/root/tg-dispatcher/dispatcher.sh logs ariyasacca
```
Send the bot a private message in Telegram — a 6-character pairing code shows up in the log. Then:
```bash
/root/tg-dispatcher/dispatcher.sh attach   # tmux attach -t tg
```
`Ctrl+B w` — window list, pick the role. Inside the session run
`/telegram:access pair <code>`, then `/telegram:access policy allowlist`
(otherwise any stranger who messages the bot gets a pairing code). Detach with
`Ctrl+B d` — the session keeps running, only your terminal disconnects.

## 7. Add the bot to the shared group
Make the bot a group admin (simpler than `/setprivacy Disable` at BotFather) — otherwise the bot
doesn't see other members' messages that aren't replies to it.
From its own session: `/telegram:access group add -100XXXXXXXXXX --no-mention`.

## Replacing the session behind a role (session 1 → session 4)
```bash
/root/tg-dispatcher/dispatcher.sh assign ariyasacca <new-session-id>
```
Token, pairing, allowlist are already saved — you don't touch them a second time.

## Gotcha: a new project_dir asks for trust the first time
The "Do you trust this folder?" dialog for a NEW (never opened) folder hangs forever — there is
nobody to press Enter. Before the first `start` on a new directory check `~/.claude.json` →
`projects."<path>".hasTrustDialogAccepted`, and if it isn't there, add it:
```bash
python3 -c "
import json
p='/root/.claude.json'
d=json.load(open(p))
d['projects'].setdefault('/path/to/role', {})['hasTrustDialogAccepted'] = True
json.dump(d, open(p,'w'), indent=2)
"
```
Even with this flag the dialog sometimes still pops up (not yet understood why) — then finish it
by hand: `tmux send-keys -t tg:<role> Down Enter` ("No, exit" is listed above
"Yes, I trust this folder").

## Why tmux and not screen
It used to be screen with a separate session per role — it worked, but was inconvenient (many
session names). Merging them into one screen session with a window per role turned out to break:
screen gives a proper pty only to the FIRST window of a session; windows added later via
`screen -X screen` to a detached session get no pty, and `claude` immediately dies with
`Error: Input must be provided ... --print`, with no clear error in the log (the window just
disappears). This happens every time for the 2nd and later windows regardless of content. `tmux`
works differently (server + clients) and always gives every window a full pty — tested with
4 roles on 2 servers, all stable.
