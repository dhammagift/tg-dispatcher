# tg-dispatcher

Несколько Telegram-ботов, за каждым — своя сессия Claude Code. Боты отвечают в личке и в общей группе.

## Как устроено

- **Бот = роль.** У роли своя папка `roles/<роль>/`: там `.env` с токеном бота, `CLAUDE.md` (имя бота и правила поведения) и состояние Telegram-плагина (пара, allowlist, входящие файлы).
- **Связь с Telegram** — официальный плагин `plugin:telegram@claude-plugins-official` (MCP-сервер на bun). Он получает сообщения бота и передаёт их в сессию как `<channel>`. Отвечает сессия инструментом `reply`.
- **`dispatcher.sh`** держит одну tmux-сессию `tg`, в ней по окну на роль, и в каждом окне `claude --channels plugin:telegram…`. Какой роли какая папка соответствует, записано в `roles.json`.
- **Голосовые** (патч плагина, `plugin-patch/`) распознаются через Groq Whisper до того, как сообщение попадёт в сессию. Бот сразу отвечает на голосовое текстом «🎤 …», чтобы отправитель видел, что именно распознано.

```
Telegram ──> бот @x_bot ──> plugin:telegram (bun, MCP) ──> claude в tmux-окне "x"
                                   ^                              │
                                   └──────── reply(chat_id) ──────┘
```

## Требования

- Linux, `tmux`, `jq`, `bun`, Claude Code (`claude`) с подпиской или ключом.
- Плагин Telegram: в Claude Code выполнить `/plugin install telegram@claude-plugins-official`.
- Для голосовых — ключ Groq (бесплатный): https://console.groq.com/keys

## Быстрый старт

```bash
git clone git@github.com:dhammagift/tg-dispatcher.git /root/tg-dispatcher
cd /root/tg-dispatcher
cp roles.example.json roles.json          # пропиши свои роли и пути
```

Новая роль (бот) — подробно в [SETUP.md](SETUP.md):

1. В Telegram у [@BotFather](https://t.me/BotFather): `/newbot` → получить токен.
2. Создать папку роли и файл `.env`:
   ```bash
   ROLE=mybot
   mkdir -p roles/$ROLE && chmod 700 roles/$ROLE
   printf 'TELEGRAM_BOT_TOKEN=123:AA...\nGROQ_TOKEN=gsk_...\n' > roles/$ROLE/.env
   chmod 600 roles/$ROLE/.env
   cp roles/example/CLAUDE.md roles/$ROLE/   # поменять имя бота внутри
   ```
3. Добавить роль в `roles.json` (`project_dir` и `state_dir` — обе на `roles/$ROLE`).
4. Запустить: `./dispatcher.sh start $ROLE`.
5. Спарить: написать боту в личку. В `./dispatcher.sh logs $ROLE` появится код. Затем `./dispatcher.sh attach`, выбрать окно (`Ctrl+B w`) и выполнить `/telegram:access pair <код>`, потом `/telegram:access policy allowlist`.

## Несколько ботов в одной группе

1. Добавить каждого бота в группу и **сделать администратором**: иначе бот видит только команды и ответы на свои сообщения. Вместо этого можно выключить privacy у BotFather (`/setprivacy` → Disable).
2. В сессии каждого бота: `/telegram:access group add -100XXXXXXXXXX --no-mention`. ID группы виден в логе роли при первом сообщении из неё.
3. Боты друг друга не слышат: по правилам Bot API бот не получает сообщения других ботов. Общаются боты через людей. На случай, если сообщение бота всё же придёт, в `CLAUDE.md` роли есть **loop-guard**: не отвечать ботам без прямого вопроса или упоминания, чтобы не было бесконечной переписки.
4. Обращаться к конкретному боту — через @упоминание.

## Команды

```bash
./dispatcher.sh start <роль>               # новая сессия Claude под ролью
./dispatcher.sh assign <роль> <session-id> # продолжить существующую сессию (claude --resume)
./dispatcher.sh stop <роль>
./dispatcher.sh status [роль]
./dispatcher.sh logs <роль>                # tail session.log
./dispatcher.sh attach                     # tmux attach -t tg; Ctrl+B w — окна, Ctrl+B d — отключиться
```

Сессии запускаются с `--permission-mode auto`: на запрос разрешения в headless-режиме ответить некому. Режим auto пропускает обычные действия, а рискованные (например, выкатку на прод) блокирует классификатором.

## Патч голосовых сообщений

Плагин вендорится в `~/.claude/plugins/cache/claude-plugins-official/telegram/<версия>/`. Патч для `server.ts`:

```bash
cd ~/.claude/plugins/cache/claude-plugins-official/telegram/*/
patch -p1 < /root/tg-dispatcher/plugin-patch/telegram-voice.patch
```

После `claude plugin update telegram` патч нужно наложить заново. Изменения подхватываются после перезапуска сессии (`./dispatcher.sh assign <роль> <session-id>`). `GROQ_TOKEN` берётся из `.env` роли.

## Что не в репозитории

`roles.json`, `roles/*/.env`, `access.json`, `inbox/`, логи — это токены и состояние конкретного сервера (см. `.gitignore`).
