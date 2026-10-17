# Agent Commander settings

This folder holds `config.json`, the list of agents, projects and routines
shown in the Agent Commander menu. Open it from the menu with **Edit
routines…**. Changes show up the next time you open the menu (or choose
**Reload**).

If the file has a mistake, the menu shows "Problem in config.json" with
details. To start over, delete `config.json` and Agent Commander writes a
fresh example next time it starts.

## Agents

```json
"agents": [
  { "name": "Claude Code", "command": "claude" },
  { "name": "Codex", "command": "codex" }
],
"defaultAgent": "Claude Code"
```

- `name`: what the menu shows.
- `command`: how to start the agent in Terminal. A plain name like `claude`
  is looked up the same way your Terminal finds it. If it isn't found, use
  the full path, for example `"$HOME/.local/bin/claude"`.
- The command can include options, like `"claude --model opus"`.
- The routine's prompt is added to the end of the command. If your agent
  needs it somewhere else, put `{prompt}` where it goes, for example
  `"aider --message {prompt}"`.
- `defaultAgent` (optional): which agent is ticked at first. Otherwise it's
  the first one.

With more than one agent, the menu has an **Agent** section. Tick the one
you want and every routine uses it until you pick another.

## Projects

```json
"projects": [
  {
    "name": "My app",
    "folder": "~/Projects/my-app",
    "routines": [
      { "title": "Review my changes", "prompt": "Review my uncommitted changes." },
      { "title": "Something else…", "prompt": null }
    ]
  }
]
```

- `name`: what the menu shows. With one project, its routines sit right in
  the menu under its name. With several, each project gets a submenu.
- `folder`: where Terminal starts for this project's routines. `~` means
  your home folder.
- `routines`: the project's routines.

## Routines

- `title`: what the menu shows.
- `prompt`: what the agent is asked to do. Use `null` to type it each time.
- `question` (optional): the wording of that question when `prompt` is
  `null`. `{agent}` and `{project}` are filled in, as in
  `"What should {agent} do on {project}?"`.
- `confirm` (optional): a question to ask before starting, with **Start**
  and **Cancel** buttons. Handy for routines that need something ready
  first, as in `"confirm": "Is the draft saved?"`.
- `folder` (optional): use a different folder for just this routine.
- `agent` (optional): always use this agent for this routine, whatever is
  ticked in the menu. The menu shows the agent's name after the title.

A top-level `"routines"` list (outside any project) also works. Those
routines appear in the main menu and need their own `folder` (it defaults
to `~`).

## Stopping a routine

While a routine is running, the menu bar "A" shows a dot in place of its
spark (and a number when more than one is running). The top of the menu
lists each one with its agent and how long it has been going. Choose it,
then **Stop** to end the agent the way Ctrl-C would. **Stop all** appears
when more than one is running. The Terminal window then says "Stopped."
and closes when you press a key.

Agent Commander only stops agents it started itself.

## Menu layout

Inside any routines list you can also use:

- `"-"`: a separator line.
- `{ "header": "Publishing" }`: a small gray label.
- `{ "submenu": "More", "routines": [ ... ] }`: a submenu with its own routines.

## Other settings

- `menuBarIcon` (optional, top level): the name of an SF Symbol to use in
  the menu bar instead of the "A", for example `"sparkles"`.

JSON has no comments, so notes go in keys that start with `_`, like
`"_comment": "..."`. Agent Commander ignores them.
