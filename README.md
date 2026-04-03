# OneCC — One's Command Center

A subtle macOS menu bar app that lets AI agents nudge you. They write a tiny file, you get a floating notification, you respond, they read your response. That's it.

## How It Works

```
AI agent                          OCC (your Mac)                    You
   |                                    |                            |
   |-- writes .occ file ------------>   |                            |
   |   (status: pending, next: human)   |-- pill notification -----> |
   |                                    |                            |
   |                                    |   <-- tap Approve/Reply -- |
   |   <-- reads updated file ------    |                            |
   |   (status: approved, next: ai)     |                            |
```

Everything happens through `.occ` files in your project's `.occ/` directory. No server, no API, no accounts.

## Install

### Download

Grab the latest release from [GitHub Releases](https://github.com/withoneai/occ/releases/latest). Unzip, drag to Applications, and run.

> macOS may show a security warning since the app isn't signed. Right-click the app → **Open** to bypass.

### From source

```bash
git clone https://github.com/withoneai/occ.git
cd occ
swift build -c release
```

Run it:

```bash
.build/release/OneCC
```

### Build a shareable .app

```bash
bash scripts/build-release.sh
```

This creates `dist/OneCC.app` — drag it to Applications or send it to a friend.

## Quick Start

### 1. Launch OneCC

Run the binary or open the `.app`. A small icon appears in your menu bar. OneCC runs as a menu bar app with no dock icon.

### 2. Add a watched folder

Click the menu bar icon and click **+ Add Folder**. Pick your project directory. OneCC will watch `<your-project>/.occ/` for nudge files.

### 3. Give your AI agent the nudge skill

Copy the skill file so your AI agent knows how to send nudges:

```bash
mkdir -p ~/.claude/skills/occ-nudge
cp skills/occ-nudge.md ~/.claude/skills/occ-nudge/SKILL.md
```

The skill teaches the agent:
- When to nudge (task finished, approval needed, something failed)
- The `.occ` file format
- How to read your responses
- The conversation protocol (one file, appended replies)

### 4. Set up your agent to check for responses

Your AI agent needs to periodically scan for your responses. Add a cron hook or scheduled task that:

1. Scans `.occ/*.occ` files for `next: ai`
2. Reads the `status` field to know what you decided
3. Acts on it

**With Claude Code**, add a hook in your project's `.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "for f in .occ/*.occ; do [ -f \"$f\" ] && grep -l 'next: ai' \"$f\" 2>/dev/null; done",
            "timeout": 5000
          }
        ]
      }
    ]
  }
}
```

Or use **Claude Code's scheduled triggers**:

```bash
claude schedule create \
  --name "check-nudges" \
  --interval "*/2 * * * *" \
  --prompt "Check .occ/*.occ files for any with 'next: ai'. For each: read the status (approved/rejected/replied/requested), act on it, then archive the file to .occ/archive/"
```

### 5. Test it

Click the menu bar icon and hit **Test Nudge**. A floating pill appears at the bottom of your screen. Tap it to expand the notification card.

## The .occ File Format

Files live in `<project>/.occ/` and are named `{timestamp}-{slug}.occ`:

```
---
title: Deploy v2.1.0?
priority: high
status: pending
next: human
created: 2026-03-27T19:30:00Z
url: https://github.com/acme/app/releases/v2.1.0
action: View Release
buttons: Ship | Hold
---
All checks passed. 3 new features, 2 bug fixes.
```

### Frontmatter fields

| Field | Required | Values |
|-------|----------|--------|
| `title` | yes | Under 60 chars |
| `priority` | yes | `low`, `medium`, `high` |
| `status` | yes | `pending`, `requested`, `working`, `approved`, `rejected`, `replied`, `dismissed` |
| `next` | yes | `human` or `ai` |
| `created` | yes | ISO 8601 timestamp |
| `buttons` | no | `Primary \| Secondary` (default: `Approve \| Reject`) |
| `url` | no | Link shown as a button |
| `action` | no | Label for the URL button |
| `from` | no | `human` if user-initiated |

### Status lifecycle

```
AI creates nudge         → status: pending,   next: human   (notification appears)
Human approves           → status: approved,  next: ai      (AI acts on it)
Human rejects            → status: rejected,  next: ai      (archived automatically)
Human replies            → status: replied,   next: ai      (conversation continues)
Human sends request      → status: requested, next: ai      (AI picks it up)
AI starts working        → status: working,   next: ai      (yellow dot blinks)
AI finishes              → status: pending,   next: human   (notification appears again)
```

### Conversations

Everything stays in one file. Replies are appended:

```
---reply [human] 2026-03-27T19:35:00Z---
Ship it.

---reply [ai] 2026-03-27T19:40:00Z---
Deployed. All health checks green.
```

## Flows

If you use [One CLI](https://withone.ai) flows (`.one/flows/*.flow.json`), OCC shows them in a panel. Right-click the pill icon to see your flows, tap one to run it.

## The Pill

The floating pill at the bottom of your screen is the notification widget:

- **Single click** — expand to see notification cards, or type a message to the AI
- **Right-click** — view and run your flows
- **Hover** — the icon scales up with a fluid animation
- **Yellow tint** — the pill turns yellow when the flows panel is open

### Pill states

| State | What it means |
|-------|---------------|
| Dim icon | Idle, no notifications |
| Bright icon + glow | Active notification (auto-hides after 8s) |
| Card stack | Expanded — swipe to browse multiple notifications |
| Red badge | Multiple notifications queued |
| Yellow dot | AI is working on your request |
| Blinking yellow dot | AI is actively processing |

## Buddies

Pick a buddy to live in your pill. Each one is a pixel-art chibi drawn entirely in SwiftUI — no image assets.

```
  ∧,,,∧       ∧___∧      (\_/)       ∧ ∧        /\  /\       ◉ ◉       (·▽·)
 ( ·ω· )     ( ◕ᴥ◕ )    ( ◕ᴗ◕ )    ( °▽° )    ( ◕ω◕ )    (◕  ◕)    /|    |\
  Cat          Dog        Bunny       Owl         Fox        Panda     Penguin

  ~~~          ∩           □□        (↑)         ☆         (~)(~)      ∧  
 ( · · )      ( · )     [ ◕  ◕ ]   ( ‿ )     (✧ω✧)     (◕  ◕)    / · \
  Slime       Ghost       Robot      Sprout      Star       Octo     Shroom

  ◎            ◉           ∧          △
 (◉  ◉)     (◕‿◕)      (  · ·)    ( ◕ω◕ )
  Alien       Tanuki      Dragon     ...more?
```

They react to notifications — bouncing when a nudge arrives, blinking while the AI works, and celebrating when a task completes.

## Menu Bar Settings

Click the menu bar icon to access:

- **Position** — move the pill to bottom-left, center, or right
- **Display** — choose which monitor (only shows with multiple screens)
- **Watched Folders** — add/remove project folders to monitor
- **Recent** — history of past nudges with status indicators
- **Test Nudge** — send yourself a test notification

## Architecture

```
OCC/
├── App/          Entry point, AppDelegate
├── Core/         Models, state machine, file parser
├── Bridge/       File watcher, CLI socket, request/reply writers
├── UI/           SwiftUI views (popover, pill, cards, flows)
└── Resources/    Icons, connector images
```

The state machine lives in `NotificationRouter.swift`. File I/O is in `Bridge/`. The pill UI is in `PillView.swift` and `PillPanel.swift`.

## Requirements

- macOS 13 (Ventura) or later
- Swift 5.9+

## License

MIT
