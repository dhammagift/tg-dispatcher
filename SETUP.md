# Добавление новой роли (нового бота)

Для агента/человека, у которого на руках токен бота от @BotFather.

## 1. Придумай имя роли
Используй настоящий @username бота (без @ и без `_bot`, если хочется короче),
не придуманное человеком имя — так проще сопоставлять роль с ботом:
`kacchapa`, `cakkhu`, `ariyasacca`, `o28`.

## 2. Одна папка на роль — она же project_dir, она же state_dir
```bash
ROLE=ariyasacca
mkdir -p /root/tg-dispatcher/roles/$ROLE
chmod 700 /root/tg-dispatcher/roles/$ROLE
cat > /root/tg-dispatcher/roles/$ROLE/.env <<EOF
TELEGRAM_BOT_TOKEN=123456789:AA...   # токен из BotFather, целиком
EOF
chmod 600 /root/tg-dispatcher/roles/$ROLE/.env
```
Не разносить `.env` и `CLAUDE.md` по разным папкам (раньше так и было — `state_dir`
отдельно от `project_dir` — и это постоянно приводило к путанице: токен клали не
туда). Одна папка проще и работает точно так же — плагину всё равно, совпадает
ли `TELEGRAM_STATE_DIR` с рабочей директорией сессии или нет.

## 3. Зарегистрируй роль в roles.json
`/root/tg-dispatcher/roles.json`, добавь ключ:
```json
{
  "ariyasacca": {
    "project_dir": "/root/tg-dispatcher/roles/ariyasacca",
    "state_dir": "/root/tg-dispatcher/roles/ariyasacca"
  }
}
```

## 4. Положи CLAUDE.md с identity в ту же папку
Шаблон — см. любую из существующих ролей (`roles/kacchapa/CLAUDE.md` и т.п.):
identity ("твоё имя в этом чате — X"), loop-guard (не отвечать ботам, кроме
как по прямому вопросу/упоминанию), и блок "always reply back to Telegram"
(обязательно слать ответ через `reply` в исходный chat_id — личка или
группа, откуда пришло сообщение; иначе ответ уйдёт только в терминал, а не
собеседнику в Telegram).

## 5. Запусти
```bash
/root/tg-dispatcher/dispatcher.sh start ariyasacca
```

## 6. Спарь бота (только один раз на роль)
```bash
/root/tg-dispatcher/dispatcher.sh logs ariyasacca
```
Напиши боту в личку в Telegram — в логах появится 6-значный код пары. Затем:
```bash
/root/tg-dispatcher/dispatcher.sh attach   # tmux attach -t tg
```
`Ctrl+B w` — список окон, выбрать роль. Внутри сессии выполни
`/telegram:access pair <код>`, затем `/telegram:access policy allowlist`
(иначе любой посторонний, кто напишет боту, получит код пары). Отключись
через `Ctrl+B d` — сессия продолжит жить, отключается только твой терминал.

## 7. Добавь бота в общую группу
Дай боту права администратора группы (проще, чем `/setprivacy Disable` в
BotFather) — иначе бот не увидит сообщения других участников не-в-ответ-на-себя.
Из его же сессии: `/telegram:access group add -100XXXXXXXXXX --no-mention`.

## Замена сессии под ролью (сессия 1 → сессия 4)
```bash
/root/tg-dispatcher/dispatcher.sh assign ariyasacca <id-новой-сессии>
```
Токен, пара, allowlist — уже сохранены, второй раз их не трогаешь.

## Особенность: новый project_dir первый раз спросит доверие
Диалог "Do you trust this folder?" для НОВОЙ (ещё не открытой) папки
зависает навечно — печатать Enter некому. Перед первым `start` на новую
директорию проверь `~/.claude.json` → `projects."<path>".hasTrustDialogAccepted`,
и если её там нет — добавь:
```bash
python3 -c "
import json
p='/root/.claude.json'
d=json.load(open(p))
d['projects'].setdefault('/путь/к/роли', {})['hasTrustDialogAccepted'] = True
json.dump(d, open(p,'w'), indent=2)
"
```
Даже с этим флагом диалог иногда всё равно всплывает (не разобрались, почему
именно) — тогда добить вручную: `tmux send-keys -t tg:<роль> Down Enter`
(в списке "No, exit" стоит выше "Yes, I trust this folder").

## Почему tmux, а не screen
Раньше был screen с отдельной сессией на роль — работало, но неудобно (много
имён сессий). Свели в одну screen-сессию с окнами на роль — оказалось, screen
даёт нормальный pty только ПЕРВОМУ окну сессии; окна, добавленные позже через
`screen -X screen` в отсоединённую сессию, pty не получают, и `claude` тут же
падает с `Error: Input must be provided ... --print`, без внятной ошибки в
логе (окно просто исчезает). Такое творится каждый раз для 2-го и более
позднего окна независимо от контента. `tmux` устроен иначе (сервер + клиенты)
и всегда выдаёт полноценный pty каждому окну — проверено, 4 роли на 2
серверах, все стабильны.
