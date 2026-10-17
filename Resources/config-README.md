# Agent Commander settings

This folder holds `config.json`, the list of agents and routines shown in the
Agent Commander menu. Open it from the menu with **Edit routines…**. Changes
show up the next time you open the menu (or choose **Reload**).

If the file has a mistake, the menu shows "Problem in config.json" with
details. If you want to start over, delete `config.json` and Agent Commander
writes a fresh example next time it starts.

## Agents

```json
"agents": [
  { "name": "Claude Code", "command": "claude" },
  { "name": "Codex", "command": "codex" }
]
```

- `name`: what the menu shows.
- `command`: how to start the agent in Terminal. A plain name like `claude`
  is looked up the same way your Terminal finds it. If it isn't found, use
  the full path, for example `"$HOME/.local/bin/claude"`.
- The command can include options, like `"claude --model opus"`.
- The routine's prompt is added to the end of the command. If your agent
  needs it somewhere else, put `{prompt}` where it goes, for example
  `"aider --message {prompt}"`.
- `routines` (optional): routines that only this agent shows. They appear
  above the shared ones.
- `sharedRoutines` (optional): set to `false` to hide the shared routines
  for this agent.

## Routines

```json
"routines": [
  { "title": "Review my changes", "folder": "~/Projects/my-app", "prompt": "Review my uncommitted changes." },
  { "title": "Something else…", "folder": "~", "prompt": null }
]
```

- `title`: what the menu shows.
- `folder`: where Terminal starts. `~` means your home folder. Defaults to `~`.
- `prompt`: what the agent is asked to do. Use `null` to type it each time.
- `question` (optional): the wording of that question when `prompt` is `null`. `{agent}` becomes the agent's name, as in
  `"What should {agent} do on the website?"`.

## Menu layout

Inside any routines list you can also use:

- `"-"`: a separator line.
- `{ "header": "Website" }`: a small gray label.
- `{ "submenu": "More", "routines": [ ... ] }`: a submenu with its own routines.

## Other settings

- `menuBarIcon` (optional, top level): the name of an SF Symbol for the menu
  bar, for example `"sparkles"`. The default is `"terminal"`.

JSON has no comments, so notes go in keys that start with `_`, like
`"_comment": "..."`. Agent Commander ignores them.
