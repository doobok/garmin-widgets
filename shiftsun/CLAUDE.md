# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Garmin Connect IQ **widget** written in **Monkey C**, targeting Instinct 2 Solar.
Tracks maritime/shift-work **watch duty rotation**: absolute start date/time, alternating ON DUTY / REST blocks, arc gauge UI, countdown, overall voyage progress.

---

## Build

### VS Code (primary)
```
Ctrl+Shift+B                           — build
F5                                     — build + run in simulator
Ctrl+Shift+P → "Monkey C: Build for Device" → instinct2
Ctrl+Shift+P → "Export Project"        — produces .iq for store / sideload
```

### CLI (run from repo root)
```bash
SDK=/home/yura/.Garmin/ConnectIQ/Sdks/connectiq-sdk-lin-9.1.0-2026-03-09-6a872a80b

# Compile (instinct2 — instinct2solar не валідний device ID в SDK 9.1.0)
$SDK/bin/monkeyc -d instinct2 -f shiftsun/monkey.jungle -o shiftsun/bin/ShiftSun.prg -y developer_key.der

# Run in simulator (connectiq must already be running)
$SDK/bin/monkeydo shiftsun/bin/ShiftSun.prg instinct2

# Debug: Tools → Show Dev Console (System.println виводиться туди)
```

### Deploy to device
Copy `shiftsun/bin/ShiftSun.prg` → `GARMIN/APPS/` on USB-mounted watch.
`.prg` збудований для `instinct2` сумісний з Instinct 2 Solar (одна апаратна платформа).

---

## Device: Instinct 2 Solar

| Parameter | Value |
|---|---|
| Device ID (manifest `<iq:products>`) | `instinct2solar` |
| Device ID (monkeyc `-d`, simulator) | `instinct2` ← використовувати це |
| Screen | 176 × 176 px, semi-octagon shape |
| Display type | Monochrome transflective MIP |
| Colors | **2 only** — `COLOR_BLACK` / `COLOR_WHITE` |
| Input | Hard buttons only (no touchscreen) |
| API Level | 3.4 (simulator: 3.4.2) |
| minSdkVersion (manifest) | 3.3.4 |
| Glance support | Yes — "Build as Widget" (32 KB limit) |

The display is physically 1-bit. Any color value other than black/white is undefined behavior.

---

## Display Layout — Two Separate LCDs

The Instinct 2 has **two physically separate LCD areas** on one 176×176 canvas:

```
Main display:  octagon path — M 39.6,0 L 136.4,0 L 176,39.6 L 176,136.4
                              L 136.4,176 L 39.6,176 L 0,136.4 L 0,39.6
Secondary display: circle cx=144, cy=31, r=31   (top-right corner)
```

- Pixels drawn inside the circle go **only** to the secondary display.
- Pixels drawn outside go **only** to the main octagon display.
- They don't interfere at the hardware level, but a drawing that spans both
  areas will appear split across the two displays.
- **Main arc (CX=88, CY=90, R=65) leaks pixels into the secondary circle**
  at arc angles ~30°–70°. Always call `_drawSecondaryDisplay()` **last** in
  `onUpdate()` so it overwrites the bleed.

### How to clear + paint the secondary display
```monkey-c
dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
dc.fillCircle(144, 31, 31);          // clear full physical area
dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
dc.drawCircle(144, 31, 27);          // ring outline (4 px margin)
// ... draw arc progress + text ...
dc.drawText(144, 24, Graphics.FONT_XTINY, pct.toString() + "%", Graphics.TEXT_JUSTIFY_CENTER);
```

### Safe zone for main display text
Content at `y < 62` and `x > 113` falls into the secondary display area
and will NOT appear on the main display. Keep text in that region away
from x > 110, or position it below y=62.

The arc gap (opening at bottom) ends at y ≈ 136. State labels go at
**y=140** — sitting visually in the arc gap, clear of the secondary circle.

---

## Architecture

```
source/
  ShiftWatchApp.mc   — WatchTrackerApp: getInitialView() + getGlanceView()
  ShiftCalc.mc       — WatchSchedule module: pure business logic, zero UI imports
  ShiftFullView.mc   — MainView: arc gauge UI, 60s Timer, ON DUTY/REST/PENDING/Invalid
  ShiftGlanceView.mc — WatchTrackerDelegate (BehaviorDelegate) + WatchGlanceView
  DetailsView.mc     — DetailsView: start date, block durations, cycle length
resources/
  settings/settings.xml  — Properties schema for Garmin Connect Mobile
  properties/properties.xml — Default property values (REQUIRED — without it widget crashes)
  strings/strings.xml    — @Strings.AppName = "Watch Tracker"
  drawables/images/icon.png — 40×40 RGBA PNG launcher icon
manifest.xml             — entry="WatchTrackerApp", type="widget"
monkey.jungle            — project.manifest = manifest.xml
developer_key.der        — Required for builds; do NOT regenerate
```

**Separation rule:** `WatchSchedule` (ShiftCalc.mc) must never import `WatchUi` or `Graphics`.
Views call `WatchSchedule` functions; they never compute time themselves.

---

## Widget Lifecycle

```
Widget carousel (glance):
  WatchTrackerApp.getGlanceView() → WatchGlanceView.onUpdate(dc)

Button press → full screen:
  WatchTrackerApp.getInitialView()
    └── MainView.onShow()     — loadConfig(), start 60s Timer, _updateState()
    └── MainView.onUpdate(dc) — renders arc gauge
    └── WatchTrackerDelegate  — UP→DetailsView, SELECT→reload config
  [back] → MainView.onHide() — Timer.stop(), Timer = null
```

**Critical:** Never cache `dc`. Never call `dc.draw*()` outside `onUpdate()`.
Timer MUST be stopped in `onHide()` to avoid battery drain.

---

## WatchSchedule API (ShiftCalc.mc) — current

Architecture: **absolute epoch time** (not daily window).
Reference point = first shift start date/time. Position in infinite repeating cycle computed from `Time.now()`.

```monkey-c
// Config vars (public, read-only after loadConfig)
WatchSchedule.startYear   // first shift start year
WatchSchedule.startMonth  // first shift start month
WatchSchedule.startDay    // first shift start day
WatchSchedule.startHour   // first shift start hour (minute always 0)
WatchSchedule.onDutyMin   // onDutyHours * 60
WatchSchedule.restMin     // restHours * 60
WatchSchedule.endYear     // voyage end year
WatchSchedule.endMonth    // voyage end month
WatchSchedule.endDay      // voyage end day

// Functions
WatchSchedule.loadConfig()           // reads Properties via getApp().getProperty()
WatchSchedule.isPending()            // true if now < start datetime
WatchSchedule.isOnDuty()            // true if in ON DUTY phase of current cycle
WatchSchedule.blockProgress()       // 0–100, progress within current block
WatchSchedule.blockRemaining()      // minutes left in current block (0 if pending)
WatchSchedule.cycleProgress()       // 0–100, position in current full cycle
WatchSchedule.totalProgress()       // 0–100, (now-start)/(end-start) — voyage overall
WatchSchedule.minutesUntilStart()   // minutes until first shift (when pending)
WatchSchedule.elapsedInCycle()      // minutes into current cycle, -1 if pending
WatchSchedule.formatMinutes(min)    // "3h 12m" / "45m" / "2h"
```

---

## Properties / Settings

Configured via Garmin Connect Mobile. Defined in `resources/settings/settings.xml`.
Defaults in `resources/properties/properties.xml` (**mandatory file** — missing it causes IQ crash on launch).

| Key | Type | Default | Notes |
|---|---|---|---|
| `startYear` | Number | 2026 | First shift start |
| `startMonth` | Number | 4 | |
| `startDay` | Number | 15 | |
| `startHour` | Number | 14 | Minutes always 0 |
| `onDutyHours` | Number | 6 | |
| `restHours` | Number | 12 | |
| `endYear` | Number | 2026 | Voyage end date |
| `endMonth` | Number | 7 | |
| `endDay` | Number | 15 | |

---

## Key APIs

### Drawing — `Toybox.Graphics.Dc`
```monkey-c
dc.setColor(foreground, background)   // foreground = text/lines, background = clear()
dc.clear()                            // fills with background color
dc.drawText(x, y, font, text, Graphics.TEXT_JUSTIFY_CENTER)
dc.drawRectangle(x, y, w, h)         // outline
dc.fillRectangle(x, y, w, h)         // solid fill with foreground color
dc.drawArc(cx, cy, r, attr, degStart, degEnd)  // attr = ARC_CLOCKWISE / ARC_COUNTER_CLOCKWISE
dc.drawCircle(cx, cy, r)             // circle outline
dc.fillCircle(cx, cy, r)             // solid circle with foreground color
dc.getWidth()                         // actual canvas width
dc.getHeight()                        // actual canvas height — use this, not hardcoded 176
```

**Arc angle convention:** 0°=right, 90°=top, standard math. `ARC_CLOCKWISE` = clockwise on screen
(decreasing angle: 90°→0°→270°→180°→90°).

### Arc gauge pattern (speedometer, 270°, opens at bottom)
```monkey-c
// Background arc: thin, full 270°
dc.drawArc(CX, CY, R_OUT, Graphics.ARC_CLOCKWISE, 225, 315);

// Progress arc: thick (loop over radii), pct = 0–100
if (pct > 0) {
    var endDeg = ((225 - pct * 270 / 100) + 360) % 360;
    for (var r = R_IN; r <= R_OUT; r++) {
        dc.drawArc(CX, CY, r, Graphics.ARC_CLOCKWISE, 225, endDeg);
    }
}
// At pct=0: endDeg=225 (nothing drawn). At pct=100: endDeg=315 (full arc). At pct=50: endDeg=90 (top).
```

### Time
```monkey-c
// Absolute epoch (for shift calculation):
var ref = Gregorian.moment({:year=>y, :month=>m, :day=>d, :hour=>h, :minute=>0, :second=>0});
var elapsedSec = Time.now().value() - ref.value();

// Wall clock (for display only):
var clock = System.getClockTime();
var nowMin = clock.hour * 60 + clock.min;
```

### Properties — CRITICAL
```monkey-c
// BROKEN in SDK 9.1.0 — uncatchable VM crash "Unexpected Type Error: Failed invoking <symbol>":
var v = Application.Properties.getValue("key");   // DO NOT USE

// Working alternative (deprecated but functional, returns null for unset keys):
var v = Application.getApp().getProperty("key");
var val = (v != null) ? v : DEFAULT;
```

---

## GlanceView (widget carousel)

Instinct 2 supports GlanceView ("Build as Widget"). Implemented in `ShiftGlanceView.mc`,
registered in `getGlanceView()` in `ShiftWatchApp.mc`.

**Canvas size is smaller than the main view** — do NOT use hardcoded y coordinates.
Always use `dc.getWidth()` / `dc.getHeight()` for positioning:

```monkey-c
class WatchGlanceView extends WatchUi.GlanceView {
    function initialize() { GlanceView.initialize(); }
    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;
        // Dark background to match system widget style:
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        // Draw content relative to cx, cy ...
    }
}
```

Register in app:
```monkey-c
function getGlanceView() {
    return [new WatchGlanceView()];
}
```

---

## Launcher Icon

- File: `resources/drawables/images/icon.png`
- Required format: **40×40 RGBA PNG** (16×16 shows default IQ logo instead of custom icon)
- Generate with Python `struct` + `zlib` if ImageMagick unavailable
- Current icon: ship wheel / helm (nautical theme)

---

## Monkey C Gotchas

**Type annotations без `Lang.` — compile error:**
```monkey-c
function foo(elapsedMin as Number) { }    // ERROR
function foo(elapsedMin as Lang.Number) { }  // OK
function foo(elapsedMin) { }              // safest for module functions
```

**`using` тільки на рівні файлу** — не всередині функцій чи класів.

**Integer division truncates** — для % прогресу multiply first:
```monkey-c
var pct = elapsed * 100 / total;   // OK — multiply before divide
```

**Modulo з від'ємними числами:**
```monkey-c
var pos = val % cycle;
if (pos < 0) { pos += cycle; }   // always guard
```

**Heap limit:** max 512 handles — не алокувати об'єкти в циклі в `onUpdate()`.

**Timer:**
```monkey-c
function onHide() {
    if (_timer != null) { _timer.stop(); _timer = null; }
}
```

**Timer callback** — метод повинен бути public (без `private`):
```monkey-c
_timer.start(method(:onTimer), 60000, true);
function onTimer() as Void { ... }   // public — no private keyword
```

---

## MainView Layout (176×176 px, current)

```
Arc gauge: CX=88, CY=90, R_OUT=65, R_IN=57
           ARC_CLOCKWISE 225°→315° (270°, opens at bottom)
           Endpoints at approximately (42,136) and (134,136)

Secondary display circle: cx=144, cy=31, r=31
           Drawing radius CCR=27 (4px margin)

y= 10   not used (secondary circle zone — avoid text here near x>110)
arc     background + progress arc
y= 62   remaining time — FONT_MEDIUM, CENTER
y= 94   "remaining" — FONT_XTINY, CENTER
y=140   "ON DUTY" / "REST" / "PENDING" — FONT_SMALL, CENTER (in arc gap)

Secondary circle (drawn last, overwrites arc bleed):
  cx=144, cy=24  percentage text — FONT_XTINY
  cx=144, cy=31  ring + clockwise progress arc
```

---

## Validated Patterns

**BehaviorDelegate:**
```monkey-c
class MyDelegate extends WatchUi.BehaviorDelegate {
    function initialize() { BehaviorDelegate.initialize(); }
    function onNextPage()     { WatchUi.pushView(new DetailsView(), null, WatchUi.SLIDE_UP); return true; }
    function onPreviousPage() { return false; }
    function onSelect()       { WatchSchedule.loadConfig(); WatchUi.requestUpdate(); return true; }
}
```

**getInitialView:**
```monkey-c
function getInitialView() {
    return [new MainView(), new WatchTrackerDelegate()];
}
```

**pushView з null delegate** (BACK handled by system):
```monkey-c
WatchUi.pushView(new DetailsView(), null, WatchUi.SLIDE_UP);
```

---

## Simulator Navigation

`$SDK/bin/connectiq` — запускає симулятор (якщо вже запущений — виходить з кодом 255, це нормально).
`$SDK/bin/monkeydo shiftsun/bin/ShiftSun.prg instinct2` — завантажує .prg в симулятор (з repo root).
Після завантаження: натиснути **Enter** (= кнопка SET) щоб відкрити повний вигляд.

XTest через Python (xdotool не встановлений, але ctypes segfaultить без `restype = c_void_p`):
```python
libX11.XOpenDisplay.restype = ctypes.c_void_p
dpy = libX11.XOpenDisplay(b':0')
libXtst.XTestFakeKeyEvent(dpy, 36, 1, 0)
libXtst.XTestFakeKeyEvent(dpy, 36, 0, 0)
libX11.XFlush(dpy)
```
