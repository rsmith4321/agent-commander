# Agent Commander

A small Mac menu bar app for starting AI coding agents on the jobs you do
over and over.

Pick an agent (Claude Code, Codex, or any other command-line agent), then
pick one of your saved routines. Terminal opens in the right folder with the
agent already working on that routine's instructions. You watch it work and
answer its questions, just as if you'd typed the command yourself.

![The Agent Commander menu: pick an agent, then a routine](docs/menu.png)

It only runs when you click. There are no schedules, nothing runs in the
background, and it doesn't collect or send anything anywhere.

## Why

If you use an agent for regular chores ("publish my blog post", "review my
changes", "update the docs"), you end up opening Terminal, changing to the
right folder, starting the agent and pasting the same request every time.
Agent Commander turns each of those into one menu click.

## Install

### From the release (easiest)

1. Download `Agent-Commander-1.0.0.zip` from the
   [latest release](https://github.com/rsmith4321/agent-commander/releases/latest).
2. Double-click the zip and drag **Agent Commander** into your Applications
   folder.
3. The app isn't signed by Apple, so the first launch needs one extra step:
   right-click (or Control-click) the app, choose **Open**, then **Open**
   again. On newer macOS versions, if that doesn't offer an Open button, try
   to open it once, then go to **System Settings → Privacy & Security** and
   click **Open Anyway**.

A terminal icon appears in your menu bar. After that it opens normally.

You need macOS 13 or later and at least one agent installed, for example
[Claude Code](https://docs.anthropic.com/en/docs/claude-code) or
[Codex](https://github.com/openai/codex).

### From source

You need Apple's command line tools (`xcode-select --install`).

```bash
git clone https://github.com/rsmith4321/agent-commander.git
cd agent-commander
./build.sh
```

`build.sh` builds the app, copies it to `~/Applications`, and starts it.
`./build.sh --release` makes a universal (Apple silicon and Intel) zip in
`build/` instead.

## Using it

- Click the menu bar icon, choose an agent, then a routine.
- A routine set to ask (like **Something else…**) shows a box where you type
  what you want done.
- **Edit routines…** opens your settings file. Changes appear the next time
  you open the menu, or right away with **Reload**.
- **Open at login** starts Agent Commander when you log in.

If something is wrong, it tells you: a mistake in the settings file shows up
at the top of the menu with details, an agent it can't find is marked "(not
found)", and a routine whose folder is missing (say, an unplugged drive) gets
a clear message instead of a broken Terminal window.

## Settings

Everything lives in one file: `~/.config/agent-commander/config.json`. The
first time the app runs it writes an example there, along with a `README.md`
that explains every option. Here is a small example:

```json
{
  "agents": [
    { "name": "Claude Code", "command": "claude" },
    { "name": "Codex", "command": "codex" }
  ],
  "routines": [
    {
      "title": "Review my uncommitted changes",
      "folder": "~/Projects/my-app",
      "prompt": "Review the uncommitted changes in this repo. Point out bugs, but don't edit anything."
    },
    "-",
    { "title": "Something else…", "folder": "~", "prompt": null }
  ]
}
```

**Agents** need a `name` for the menu and a `command` that starts them.
Agent Commander finds commands the same way your Terminal does. If it can't,
give the full path, like `"$HOME/.local/bin/claude"`. Commands can include
options (`"claude --model opus"`). The prompt is added at the end; if your
agent wants it somewhere else, put `{prompt}` where it goes.

**Routines** have a `title`, a `folder` where Terminal starts, and a
`prompt`. Set `"prompt": null` to type the request each time.

**Extras:**

- `"-"` adds a separator line, `{ "header": "Website" }` adds a gray label,
  and `{ "submenu": "More", "routines": [...] }` makes a submenu.
- The routines list at the top level is shared by every agent. An agent can
  also have its own `"routines"` list, and `"sharedRoutines": false` hides
  the shared ones for that agent.
- `"menuBarIcon"` picks a different [SF Symbol](https://developer.apple.com/sf-symbols/)
  for the menu bar, for example `"sparkles"`.

JSON has no comments, so notes go in keys starting with `_`, such as
`"_comment": "..."`. They're ignored.

## How it works

When you pick a routine, Agent Commander writes a tiny one-time script and
opens it with Terminal. The script changes to the routine's folder and runs
the agent with your prompt, then deletes itself. Opening a script file this
way doesn't need any special macOS permissions. The prompt is quoted safely,
so quotes, dollar signs and other symbols reach the agent exactly as written.

The whole app is one Swift file, [`Sources/main.swift`](Sources/main.swift).

## Compared to Rota

[Rota](https://github.com/wiltodelta/rota) is a much bigger menu bar app
that runs agent routines **on a schedule**, in the background, and shows
each run as a chat you can read and reply to later. It's a good fit when you
want jobs to happen on their own at set times.

Agent Commander is the opposite: **on demand and interactive**. Nothing
happens until you click, and the agent runs in a normal Terminal window in
front of you, so you can watch it and answer questions as it goes. There's
no scheduler, no session history and no settings window, just a menu and a
text file.

## License

[MIT](LICENSE). Copyright (c) 2026 Ryan Smith.
