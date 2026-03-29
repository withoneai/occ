# OCC Nudge

Send desktop notifications to the human via OCC (One Command Center) — a subtle floating widget on their Mac. All communication happens through `.uni` files inside the `.uni/` folder of the project root.

## Quick Reference

```
mkdir -p .uni
cat > .uni/$(date +%s)-slug.uni << 'EOF'
---
title: Short Title
priority: medium
status: pending
next: human
created: $(date -u +%Y-%m-%dT%H:%M:%SZ)
buttons: Approve | Reject
---
Message body here.
EOF
```

## When to nudge

- A long-running task finished (build, deploy, test suite)
- A decision or approval is needed and you are blocked
- Something failed that needs human attention
- You found something important during analysis
- A PR is ready for review or has been approved

Do NOT nudge for routine progress updates or minor status changes.

## File Format

Write files to `.uni/{unix-timestamp}-{short-slug}.uni`:

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
All checks passed. v2.1.0 is staged for production. 3 new features, 2 bug fixes.
```

### Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `title` | yes | Under 60 chars |
| `priority` | yes | `low`, `medium`, `high` |
| `status` | yes | See Status Lifecycle below |
| `next` | yes | `human` or `ai` — whose turn it is |
| `created` | yes | ISO 8601 timestamp |
| `url` | no | Link — shows as a button on the card |
| `action` | no | URL button label (default: "Open") |
| `buttons` | no | Custom action buttons: `Primary \| Secondary` (default: `Approve \| Reject`) |
| `from` | no | `human` if initiated by the user |
| `updated` | auto | Set by OCC when the human responds |

### Custom Buttons

The `buttons` field lets you control the two action buttons. Format: `Primary | Secondary` — one or two words max per button. The human always has Reply available in addition to these.

Examples:
- `buttons: Approve | Reject` (default)
- `buttons: Ship | Hold`
- `buttons: Yes | No`
- `buttons: Merge | Close`
- `buttons: Confirm | Cancel`
- `buttons: Accept | Decline`
- `buttons: Run | Skip`

If omitted, defaults to `Approve | Reject`.

### Priority Guide

- **low** — FYI, no action needed (task completed, info found)
- **medium** — Worth knowing soon (PR ready, test results)
- **high** — Needs attention now (build failed, blocker, approval needed)

## Status Lifecycle

```
[AI creates file]
  status: pending, next: human     → Nudge appears on human's screen

[Human clicks primary button]
  status: approved, next: ai       → AI reads response

[Human clicks secondary button]
  status: rejected, next: ai       → AI reads response

[Human types a reply]
  status: replied, next: ai        → AI reads the reply message

[Human sends a request TO the AI]
  status: requested, next: ai      → Yellow dot on OCC (waiting for pickup)

[AI picks up a request]
  status: working, next: ai        → Yellow dot starts blinking (AI is working)

[AI finishes and responds]
  status: pending, next: human     → Nudge appears again
```

## Conversation Protocol

Everything lives in ONE file. Replies are appended as blocks:

```
---reply [human] 2026-03-27T19:35:00Z---
The human's response here.

---reply [ai] 2026-03-27T19:36:00Z---
Your follow-up response here.
```

### Reading Human Responses

1. Scan `.uni/*.uni` files for `next: ai`
2. Check `status`:
   - `approved` — human clicked the primary button. Act on it, then **archive the file** by moving it to `.uni/archive/`. The human expects you to follow through.
   - `rejected` — human clicked the secondary button. OCC already archived this file for you. No action needed.
   - `replied` — human typed a free-text reply. Read the last `---reply [human]` block. Continue the conversation or act on it.
   - `requested` — human initiated a new request. Read the body and work on it.
3. The last `---reply [human]` block contains their message.

### Responding Back

To continue the conversation, update the SAME file:

1. Set `status: pending` and `next: human`
2. Set `updated` to current timestamp
3. Optionally update `buttons` if you want different options this time
4. Append: `---reply [ai] {timestamp}---\nYour message`

### Picking Up Human Requests

When you find `status: requested, next: ai`:

1. Change `status: working` (this makes the yellow dot blink, so the human knows you're on it)
2. Do the work
3. Change `status: pending`, `next: human`, and append your `---reply [ai]` block

## Full Example

AI creates `.uni/1711561200-deploy.uni`:
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
All checks passed. v2.1.0 is staged. 3 new features, 2 bug fixes.
```

Human clicks "Ship" → OCC updates the file:
```
---
title: Deploy v2.1.0?
priority: high
status: approved
next: ai
created: 2026-03-27T19:30:00Z
updated: 2026-03-27T19:35:00Z
url: https://github.com/acme/app/releases/v2.1.0
action: View Release
buttons: Ship | Hold
---
All checks passed. v2.1.0 is staged. 3 new features, 2 bug fixes.

---reply [human] 2026-03-27T19:35:00Z---
Ship
```

AI deploys, then updates the same file:
```
---
title: Deploy v2.1.0?
priority: low
status: pending
next: human
created: 2026-03-27T19:30:00Z
updated: 2026-03-27T19:40:00Z
url: https://grafana.internal/d/deploy
action: View Dashboard
buttons: OK | Rollback
---
All checks passed. v2.1.0 is staged. 3 new features, 2 bug fixes.

---reply [human] 2026-03-27T19:35:00Z---
Ship

---reply [ai] 2026-03-27T19:40:00Z---
Deployed to production. All health checks green. Monitoring for 30 min.
```

## Rules

- One file per conversation thread
- Never write more than 3 nudge files without human interaction
- Title: under 60 chars. Body: under 280 chars.
- Buttons: 1-2 words each, always exactly 2 options
- Always `mkdir -p .uni` before writing
- Always set `status: pending` and `next: human` when creating or replying
- Set `status: working` when you pick up a request (so the human sees you're on it)
- **Archiving**: when you're done acting on an `approved` file, move it to `.uni/archive/` (`mv .uni/filename.uni .uni/archive/`). Rejected files are archived automatically by OCC. Replied/ongoing conversations stay in `.uni/` until resolved.
- Never delete `.uni` files — always archive them so there's a history
