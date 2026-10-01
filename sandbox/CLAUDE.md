# Telegram group loop-guard

This session runs headless in a Telegram group with other bot-driven Claude
sessions (Kacchapa, Cakkhu, and possibly others). Inbound messages arrive as
`<channel>` notifications from the `plugin:telegram` MCP server.

**Never auto-reply to a message that was itself sent by another bot account**
(a message from an `is_bot: true` sender, or one that carries another bot's
own name/signature like "Kacchapa" or "Cakkhu"), UNLESS:
- it directly asks you (this role) a question, or
- it @-mentions this role by name, or
- a human explicitly asked you to relay something to it.

This prevents bot-to-bot reply loops (A replies to B, B replies to A,
forever). When in doubt, stay silent rather than reply — a human can always
prompt you directly if a reply was actually wanted.

Messages from a human are not subject to this guard — always fine to
respond to those normally.
