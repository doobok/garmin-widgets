# CLAUDE.md — Monorepo Root

## Widgets

| Widget | Path | Devices |
|---|---|---|
| ShiftSun | [`shiftsun/`](shiftsun/) | Instinct 2 / 2S / 2X / Solar |

Full widget docs (architecture, APIs, gotchas) are in each widget's own `CLAUDE.md`.

---

## SDK

```bash
SDK=/home/yura/.Garmin/ConnectIQ/Sdks/connectiq-sdk-lin-9.1.0-2026-03-09-6a872a80b
```

## Build (from repo root)

```bash
# ShiftSun
$SDK/bin/monkeyc -d instinct2 -f shiftsun/monkey.jungle -o shiftsun/bin/ShiftSun.prg -y developer_key.der
```

## Simulator (from repo root)

```bash
# Start simulator (exit code 255 if already running — normal)
$SDK/bin/connectiq &
sleep 3

# Load widget
$SDK/bin/monkeydo shiftsun/bin/ShiftSun.prg instinct2

# After load: press Enter (SET button) to open full view
```

## VS Code

Open repo root as workspace. **F5** builds and runs ShiftSun in simulator (`launch.json` already configured).

## Developer keys

`developer_key.der` / `developer_key.pem` — gitignored, shared across all widgets, stay at repo root.
Do NOT regenerate — same key required for sideloaded `.prg` continuity.
